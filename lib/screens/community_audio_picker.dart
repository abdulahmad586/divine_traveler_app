import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:tahfeex/model/models.dart';
import 'package:tahfeex/resources/resources.dart';
import 'package:tahfeex/service/repositories/contribution_repository.dart';
import 'package:tahfeex/widgets/widgets.dart';

class CommunityAudioPicker extends StatefulWidget {
  final int surahNumber;
  final String surahNameEnglish;
  final void Function(SurahAudio audio) onSelected;

  const CommunityAudioPicker({
    super.key,
    required this.surahNumber,
    required this.surahNameEnglish,
    required this.onSelected,
  });

  static Future<void> show(
    BuildContext context, {
    required int surahNumber,
    required String surahNameEnglish,
    required void Function(SurahAudio) onSelected,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (_, __) => CommunityAudioPicker(
          surahNumber: surahNumber,
          surahNameEnglish: surahNameEnglish,
          onSelected: onSelected,
        ),
      ),
    );
  }

  @override
  State<CommunityAudioPicker> createState() => _CommunityAudioPickerState();
}

class _CommunityAudioPickerState extends State<CommunityAudioPicker> {
  final _repo = ContributionRepository();
  final _dio = Dio();

  List<ContributionModel>? _contributions;
  String? _error;

  // While downloading:
  String? _downloadingId;
  _DownloadStage _stage = _DownloadStage.idle;
  double _audioProgress = 0; // 0.0 – 1.0

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _error = null; _contributions = null; });
    try {
      final list = await _repo.getContributionsBySurah(widget.surahNumber);
      if (mounted) setState(() => _contributions = list);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _select(ContributionModel contribution) async {
    setState(() {
      _downloadingId = contribution.id;
      _stage = _DownloadStage.downloadingTiming;
      _audioProgress = 0;
    });

    try {
      // ── 1. Timing JSON ────────────────────────────────────────────────────
      final timingResponse =
          await http.get(Uri.parse(contribution.timingUrl));
      if (timingResponse.statusCode != 200) {
        throw Exception(
            'Could not fetch timing data (HTTP ${timingResponse.statusCode}).');
      }
      final map =
          jsonDecode(timingResponse.body) as Map<String, dynamic>;
      final audio = SurahAudio.fromMap(map);

      // ── 2. Audio file → local storage ─────────────────────────────────────
      setState(() { _stage = _DownloadStage.downloadingAudio; });

      final dir = await getApplicationDocumentsDirectory();
      final fileName =
          '${contribution.surah}_${_safeName(contribution.reciterName)}.mp3';
      final localPath = '${dir.path}/$fileName';

      await _dio.download(
        contribution.audioUrl,
        localPath,
        onReceiveProgress: (received, total) {
          if (total > 0 && mounted) {
            setState(() => _audioProgress = received / total);
          }
        },
      );

      // ── 3. Wire up the SurahAudio object ──────────────────────────────────
      audio.localFileUrl = localPath;
      audio.remoteFileUrl = contribution.audioUrl;
      audio.driveFileId = contribution.audioFileId;
      audio.driveTimingFileId = contribution.timingFileId;
      audio.contributionId = contribution.id;
      audio.createdByName = contribution.createdByName;

      // ── 4. Record download on backend (fire-and-forget) ───────────────────
      _repo.recordDownload(contribution.id).ignore();

      if (mounted) {
        Navigator.pop(context);
        widget.onSelected(audio);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _downloadingId = null;
          _stage = _DownloadStage.idle;
          _audioProgress = 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  String _safeName(String name) =>
      name.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_').toLowerCase();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.people_outline,
                color: AppColors.primaryColor, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Community — ${widget.surahNameEnglish}',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ]),
          const SizedBox(height: 4),
          Text(
            'Select a recitation to download and use locally.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey[600]),
          ),
          const Divider(height: 24),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, color: Colors.grey, size: 40),
            const SizedBox(height: 12),
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            AppButton(
              label: 'RETRY',
              backgroundColor: AppColors.primaryColor,
              labelColor: Colors.white,
              onTap: _load,
            ),
          ],
        ),
      );
    }

    if (_contributions == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryColor),
      );
    }

    if (_contributions!.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox_outlined, color: Colors.grey, size: 40),
            const SizedBox(height: 12),
            Text(
              'No community recordings yet for this surah.\nBe the first to contribute!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: _contributions!.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, index) {
        final c = _contributions![index];
        final isDownloading = _downloadingId == c.id;
        return _ContributionTile(
          contribution: c,
          isDownloading: isDownloading,
          stage: isDownloading ? _stage : _DownloadStage.idle,
          audioProgress: isDownloading ? _audioProgress : 0,
          onTap: _downloadingId == null ? () => _select(c) : null,
        );
      },
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Download stage enum
// ──────────────────────────────────────────────────────────────────────────────

enum _DownloadStage { idle, downloadingTiming, downloadingAudio }

// ──────────────────────────────────────────────────────────────────────────────
// Tile
// ──────────────────────────────────────────────────────────────────────────────

class _ContributionTile extends StatelessWidget {
  final ContributionModel contribution;
  final bool isDownloading;
  final _DownloadStage stage;
  final double audioProgress;
  final VoidCallback? onTap;

  const _ContributionTile({
    required this.contribution,
    required this.isDownloading,
    required this.stage,
    required this.audioProgress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    String? stageLabel;
    if (stage == _DownloadStage.downloadingTiming) {
      stageLabel = 'Fetching timing data…';
    } else if (stage == _DownloadStage.downloadingAudio) {
      final pct = (audioProgress * 100).toStringAsFixed(0);
      stageLabel = 'Downloading audio… $pct%';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mic,
                  color: AppColors.primaryColor, size: 22),
            ),
            title: Text(
              contribution.reciterName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'by ${contribution.createdByName}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.download, size: 13, color: Colors.grey),
                    const SizedBox(width: 3),
                    Text('${contribution.downloads}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(width: 10),
                    const Icon(Icons.favorite_border, size: 13, color: Colors.grey),
                    const SizedBox(width: 3),
                    Text('${contribution.likes}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ],
            ),
            trailing: isDownloading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primaryColor),
                  )
                : const Icon(Icons.download_for_offline_outlined,
                    color: AppColors.primaryColor),
            onTap: onTap,
          ),

          // Progress bar + label shown only while downloading this tile
          if (isDownloading && stage == _DownloadStage.downloadingAudio) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: audioProgress > 0 ? audioProgress : null,
                      minHeight: 4,
                      backgroundColor: Colors.grey[200],
                      color: AppColors.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    stageLabel ?? '',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ] else if (isDownloading && stage == _DownloadStage.downloadingTiming) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
              child: Text(
                stageLabel ?? '',
                style:
                    TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
