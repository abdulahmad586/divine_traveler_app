// NOTE: Before this service works you must complete the platform setup:
//   Android: add your OAuth 2.0 client ID to android/app/google-services.json
//            and update android/app/build.gradle with the SHA-1 fingerprint.
//   iOS:     add the reversed client ID as a URL scheme in ios/Runner/Info.plist.
// See: https://pub.dev/packages/google_sign_in

import 'dart:io';

import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:tahfeex/model/models.dart';
import 'package:tahfeex/service/auth_service.dart';
import 'package:tahfeex/service/repositories/contribution_repository.dart';
import 'package:tahfeex/shared/models/models.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Progress model
// ──────────────────────────────────────────────────────────────────────────────

enum UploadStep {
  signingIn,
  preparingFolder,
  uploadingAudio,
  uploadingTiming,
  settingPermissions,
  savingMetadata,
  done,
}

class UploadProgress {
  final UploadStep step;
  final double fraction; // 0.0 → 1.0
  final String label;
  final bool isError;
  final String? errorMessage;
  /// Set when the server returned DUPLICATE_RECITER_SURAH.
  /// The files are already on Drive — caller can POST again with force=true.
  final bool needsForce;
  final DriveUploadResult? pendingResult;

  const UploadProgress({
    required this.step,
    required this.fraction,
    required this.label,
    this.isError = false,
    this.errorMessage,
    this.needsForce = false,
    this.pendingResult,
  });

  static UploadProgress error(String message) => UploadProgress(
        step: UploadStep.done,
        fraction: 0,
        label: 'Upload failed',
        isError: true,
        errorMessage: message,
      );

  static UploadProgress duplicateReciterSurah(DriveUploadResult result) =>
      UploadProgress(
        step: UploadStep.savingMetadata,
        fraction: 0.95,
        label: 'Already submitted',
        needsForce: true,
        pendingResult: result,
      );
}

// ──────────────────────────────────────────────────────────────────────────────
// Result
// ──────────────────────────────────────────────────────────────────────────────

class DriveUploadResult {
  final String audioFileId;
  final String timingFileId;
  final String audioPublicUrl;

  const DriveUploadResult({
    required this.audioFileId,
    required this.timingFileId,
    required this.audioPublicUrl,
  });
}

// ──────────────────────────────────────────────────────────────────────────────
// Service
// ──────────────────────────────────────────────────────────────────────────────

class GoogleDriveService {
  static const _folderName = 'TahfeexUploads';

  final _contributions = ContributionRepository();

  /// Full upload flow: Drive → permissions → backend metadata.
  ///
  /// Yield sequence:
  ///   • progress events while uploading to Drive
  ///   • [UploadProgress.needsForce] == true if the backend returns
  ///     DUPLICATE_RECITER_SURAH — caller should show a dialog then call
  ///     [forcePostContribution] if the user confirms.
  ///   • [UploadProgress.step] == done on success.
  Stream<UploadProgress> upload({
    required SurahAudio surahAudio,
    required void Function(DriveUploadResult) onResult,
  }) async* {
    try {
      // 1 — Drive auth (reuses the existing Google session from AuthService) ──
      yield const UploadProgress(
          step: UploadStep.signingIn,
          fraction: 0.05,
          label: 'Connecting to Google Drive…');

      final authHeaders = await AuthService().getGoogleAuthHeaders();
      final client = _GoogleAuthClient(authHeaders);
      final api = drive.DriveApi(client);

      // 2 — Folder ───────────────────────────────────────────────────────────
      yield const UploadProgress(
          step: UploadStep.preparingFolder,
          fraction: 0.12,
          label: 'Preparing upload folder…');

      final folderId = await _getOrCreateFolder(api);

      // 3 — Audio ────────────────────────────────────────────────────────────
      yield const UploadProgress(
          step: UploadStep.uploadingAudio,
          fraction: 0.20,
          label: 'Uploading audio file…');

      final audioPath = surahAudio.localFileUrl;
      if (audioPath == null || !File(audioPath).existsSync()) {
        yield UploadProgress.error(
            'Audio file not found at its last known location.');
        return;
      }

      final audioFileName =
          '${surahAudio.surahNumber}_${_safe(surahAudio.reciterName)}.mp3';
      final audioFileId = await _uploadFile(api,
          localPath: audioPath,
          remoteName: audioFileName,
          folderId: folderId);

      yield const UploadProgress(
          step: UploadStep.uploadingAudio,
          fraction: 0.60,
          label: 'Audio uploaded ✓');

      // 4 — Timing JSON ──────────────────────────────────────────────────────
      yield const UploadProgress(
          step: UploadStep.uploadingTiming,
          fraction: 0.65,
          label: 'Uploading timing data…');

      final timingFileName =
          '${surahAudio.surahNumber}_${_safe(surahAudio.reciterName)}_timing.json';
      final tempFile =
          File('${Directory.systemTemp.path}/$timingFileName');
      await tempFile.writeAsString(surahAudio.toJson());

      final timingFileId = await _uploadFile(api,
          localPath: tempFile.path,
          remoteName: timingFileName,
          folderId: folderId);
      await tempFile.delete();

      yield const UploadProgress(
          step: UploadStep.uploadingTiming,
          fraction: 0.78,
          label: 'Timing data uploaded ✓');

      // 5 — Permissions ──────────────────────────────────────────────────────
      yield const UploadProgress(
          step: UploadStep.settingPermissions,
          fraction: 0.84,
          label: 'Setting public access…');

      await _makePublic(api, audioFileId);
      await _makePublic(api, timingFileId);

      final result = DriveUploadResult(
        audioFileId: audioFileId,
        timingFileId: timingFileId,
        audioPublicUrl:
            'https://drive.google.com/uc?id=$audioFileId&export=download',
      );

      // 6 — Backend metadata ─────────────────────────────────────────────────
      yield const UploadProgress(
          step: UploadStep.savingMetadata,
          fraction: 0.92,
          label: 'Saving to community…');

      try {
        await _contributions.postContribution(
          reciterName: surahAudio.reciterName,
          surah: surahAudio.surahNumber,
          audioFileId: audioFileId,
          timingFileId: timingFileId,
          audioHash: surahAudio.fileHash,
        );
      } on ApiException catch (e) {
        if (e.isDuplicateHash) {
          yield UploadProgress.error(
              'This exact audio has already been submitted by another user.');
          return;
        }
        if (e.isDuplicateReciterSurah) {
          // Files are on Drive — caller handles force-confirm dialog.
          yield UploadProgress.duplicateReciterSurah(result);
          return;
        }
        rethrow;
      }

      onResult(result);
      yield const UploadProgress(
          step: UploadStep.done,
          fraction: 1.0,
          label: 'Shared with the community!');
    } catch (e) {
      yield UploadProgress.error(e.toString());
    }
  }

  /// Call this after the user confirms force-submission following a
  /// DUPLICATE_RECITER_SURAH response.  The files are already on Drive;
  /// this only re-POSTs the metadata with `force: true`.
  Future<void> forcePostContribution({
    required SurahAudio surahAudio,
    required DriveUploadResult result,
  }) {
    return _contributions.postContribution(
      reciterName: surahAudio.reciterName,
      surah: surahAudio.surahNumber,
      audioFileId: result.audioFileId,
      timingFileId: result.timingFileId,
      audioHash: surahAudio.fileHash,
      force: true,
    );
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  Future<String> _getOrCreateFolder(drive.DriveApi api) async {
    final q =
        "name='$_folderName' and mimeType='application/vnd.google-apps.folder' and trashed=false";
    final list =
        await api.files.list(q: q, spaces: 'drive', $fields: 'files(id)');
    if (list.files != null && list.files!.isNotEmpty) {
      return list.files!.first.id!;
    }
    final folder = await api.files.create(
      drive.File()
        ..name = _folderName
        ..mimeType = 'application/vnd.google-apps.folder',
      $fields: 'id',
    );
    return folder.id!;
  }

  Future<String> _uploadFile(
    drive.DriveApi api, {
    required String localPath,
    required String remoteName,
    required String folderId,
  }) async {
    final file = File(localPath);
    final length = await file.length();
    final result = await api.files.create(
      drive.File()
        ..name = remoteName
        ..parents = [folderId],
      uploadMedia: drive.Media(file.openRead(), length),
      $fields: 'id',
    );
    return result.id!;
  }

  Future<void> _makePublic(drive.DriveApi api, String fileId) async {
    await api.permissions.create(
      drive.Permission()
        ..type = 'anyone'
        ..role = 'reader',
      fileId,
    );
  }

  String _safe(String name) =>
      name.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_').toLowerCase();
}

// ──────────────────────────────────────────────────────────────────────────────
// OAuth HTTP client helper
// ──────────────────────────────────────────────────────────────────────────────

class _GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _inner = http.Client();

  _GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _inner.send(request..headers.addAll(_headers));
  }
}
