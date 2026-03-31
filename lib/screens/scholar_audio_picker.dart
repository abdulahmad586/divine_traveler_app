import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quran/quran.dart';
import 'package:tahfeex/model/models.dart';
import 'package:tahfeex/resources/resources.dart';
import 'package:tahfeex/service/repositories/audio_recitation_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────────────────────────────────────

class ScholarAudioPicker extends StatefulWidget {
  final int surahNumber;
  final String surahNameEnglish;
  final void Function(SurahAudio) onSelected;

  const ScholarAudioPicker._({
    required this.surahNumber,
    required this.surahNameEnglish,
    required this.onSelected,
  });

  static void show(
    BuildContext context, {
    required int surahNumber,
    required String surahNameEnglish,
    required void Function(SurahAudio) onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      // Dismissibility is managed inside the widget based on phase — we pass
      // isDismissible: false and let the Cancel button handle exit so that an
      // accidental swipe-down can't cancel an in-progress download.
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ScholarAudioPicker._(
        surahNumber: surahNumber,
        surahNameEnglish: surahNameEnglish,
        onSelected: onSelected,
      ),
    );
  }

  @override
  State<ScholarAudioPicker> createState() => _ScholarAudioPickerState();
}

// ─────────────────────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────────────────────

enum _Phase { loading, reciters, downloading, error }

class _ScholarAudioPickerState extends State<ScholarAudioPicker> {
  final _repo = AudioRepository();
  final _dio = Dio(BaseOptions(
    // Allow up to 30 s of silence between chunks before treating it as a stall.
    receiveTimeout: const Duration(seconds: 30),
    connectTimeout: const Duration(seconds: 15),
  ));
  CancelToken _cancelToken = CancelToken();

  _Phase _phase = _Phase.loading;
  List<AudioRecitation> _reciters = [];
  AudioRecitation? _selectedReciter;
  String? _error;
  double _downloadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchReciters();
  }

  @override
  void dispose() {
    _cancelToken.cancel();
    _dio.close(force: true);
    super.dispose();
  }

  // ── Fetch reciter list ──────────────────────────────────────────────────────

  Future<void> _fetchReciters() async {
    setState(() {
      _phase = _Phase.loading;
      _error = null;
    });
    try {
      final response =
          await _repo.getSurahAudio(surahNo: widget.surahNumber);
      setState(() {
        _reciters = response.recitations;
        _phase = _Phase.reciters;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _phase = _Phase.error;
      });
    }
  }

  // ── Download the full-surah file for the chosen reciter ─────────────────────

  Future<void> _startDownload(AudioRecitation reciter) async {
    setState(() {
      _selectedReciter = reciter;
      _phase = _Phase.downloading;
      _downloadProgress = 0.0;
    });

    final appDir = await getApplicationSupportDirectory();
    final outDir = Directory(
      '${appDir.path}/scholar_audio/${widget.surahNumber}_${reciter.reciterId}',
    );
    if (!outDir.existsSync()) outDir.createSync(recursive: true);

    final outputPath = '${outDir.path}/surah.mp3';

    const maxAttempts = 3;
    bool downloaded = false;

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      if (!mounted) return;
      // Fresh cancel token each attempt — the previous one may have been used.
      _cancelToken = CancelToken();

      try {
        await _dio.download(
          reciter.url,
          outputPath,
          cancelToken: _cancelToken,
          onReceiveProgress: (received, total) {
            if (total > 0 && mounted) {
              setState(() => _downloadProgress = received / total);
            }
          },
        );
        downloaded = true;
        break;
      } on DioException catch (e) {
        if (CancelToken.isCancel(e) || !mounted) return;
        // On a receive-timeout stall, retry silently up to maxAttempts.
        if (e.type == DioExceptionType.receiveTimeout && attempt < maxAttempts) {
          if (mounted) setState(() => _downloadProgress = 0.0);
          continue;
        }
        if (!mounted) return;
        setState(() {
          _error = e.message ?? 'Download failed';
          _phase = _Phase.error;
        });
        return;
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _error = e.toString();
          _phase = _Phase.error;
        });
        return;
      }
    }

    if (!downloaded || !mounted) return;

    // Measure total duration so trackDuration is populated correctly.
    int durationMs = 0;
    final player = AudioPlayer();
    try {
      await player.setFilePath(outputPath);
      durationMs = player.duration?.inMilliseconds ?? 0;
    } finally {
      await player.dispose();
    }

    final surahAudio = SurahAudio(
      audioName: '${reciter.reciter} — ${widget.surahNameEnglish}',
      surahNumber: widget.surahNumber,
      surahNameArabic: getSurahNameArabic(widget.surahNumber),
      surahNameEnglish: widget.surahNameEnglish,
      totalAyahs: getVerseCount(widget.surahNumber),
      // No ayah timings yet — user sets them in AudioTrainingScreen,
      // exactly as they would for a file picked from the device.
      ayahs: [],
      reciterName: reciter.reciter,
      fileHash: '',
      trackDuration: durationMs,
      localFileUrl: outputPath,
      verified: true,
      uploadConsent: false,
      lastUpdated: DateTime.now(),
    );

    Navigator.pop(context);
    widget.onSelected(surahAudio);
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Scholars — ${widget.surahNameEnglish}',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Select a reciter to download their full surah recitation.',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            Flexible(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_phase) {
      case _Phase.loading:
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(color: AppColors.primaryColor),
          ),
        );

      case _Phase.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off, size: 40, color: Colors.grey[400]),
                const SizedBox(height: 10),
                Text(
                  _error ?? 'Failed to load reciters',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 14),
                OutlinedButton(
                  onPressed: _fetchReciters,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );

      case _Phase.reciters:
        return ListView.separated(
          shrinkWrap: true,
          itemCount: _reciters.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final r = _reciters[i];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: AppColors.primaryColor.withOpacity(0.1),
                child:
                    const Icon(Icons.mic_none, color: AppColors.primaryColor),
              ),
              title: Text(
                r.reciter,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              trailing:
                  const Icon(Icons.download_outlined, color: Colors.grey),
              onTap: () => _startDownload(r),
            );
          },
        );

      case _Phase.downloading:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.download_rounded,
                    size: 36, color: AppColors.primaryColor),
                const SizedBox(height: 12),
                Text(
                  _selectedReciter?.reciter ?? '',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'Downloading…',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _downloadProgress > 0 ? _downloadProgress : null,
                    color: AppColors.primaryColor,
                    backgroundColor: Colors.grey[200],
                    minHeight: 6,
                  ),
                ),
                if (_downloadProgress > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${(_downloadProgress * 100).toStringAsFixed(0)}%',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () {
                    _cancelToken.cancel();
                    Navigator.pop(context);
                  },
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
          ),
        );
    }
  }
}
