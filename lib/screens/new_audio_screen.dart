import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:quran/quran.dart';
import 'package:tahfeex/model/models.dart';
import 'package:tahfeex/resources/resources.dart';
import 'package:tahfeex/screens/screens.dart';
import 'package:tahfeex/utils/utils.dart';
import 'package:tahfeex/widgets/widgets.dart';

class NewAudio extends StatefulWidget {
  final int surahNumber;
  final PlatformFile file;
  final Function(SurahAudio)? onSurahAdd;
  // When true: skip the SuccessPage and go straight to AudioTrainingScreen.
  final bool launchTrainingOnSave;
  // Called when AudioTrainingScreen (launched in training mode) pops.
  final Function(SurahAudio)? onTrainingUpdate;

  const NewAudio(
    this.surahNumber,
    this.file, {
    super.key,
    this.onSurahAdd,
    this.launchTrainingOnSave = false,
    this.onTrainingUpdate,
  });

  @override
  State<NewAudio> createState() => _NewAudioState();
}

class _NewAudioState extends State<NewAudio> {
  late TextEditingController recitationTitle,
      recitersName,
      trackDuration,
      fileHash,
      fileSize;
  bool uploadFile = true;
  bool loading = false;
  bool _extracting = true;
  String? _extractError;
  int trackDurationMS = 0;

  GlobalKey<FormState> formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    recitationTitle = TextEditingController.fromValue(
        TextEditingValue(text: widget.file.name));
    recitersName = TextEditingController();
    trackDuration = TextEditingController();
    fileHash = TextEditingController();
    fileSize = TextEditingController();
    extractAudioData();
  }

  @override
  void dispose() {
    recitationTitle.dispose();
    recitersName.dispose();
    trackDuration.dispose();
    fileHash.dispose();
    fileSize.dispose();
    super.dispose();
  }

  static String _computeHash(String filePath) {
    final bytes = File(filePath).readAsBytesSync();
    return crypto.sha256.convert(bytes).toString();
  }

  Future<String> calculateSHA256OfFile(String filePath) =>
      compute(_computeHash, filePath);

  Future<void> extractAudioData() async {
    try {
      final player = AudioPlayer();
      await player.setFilePath(widget.file.path!);

      final metadata = player.audioSource?.sequence.first.tag;
      String? trackName = metadata?.title;
      String? artistName = metadata?.artist;

      final duration = player.duration;
      trackDurationMS = duration?.inMilliseconds ?? 0;

      recitationTitle.text = trackName ?? widget.file.name;
      recitersName.text = artistName ?? "";
      trackDuration.text = duration?.toString() ?? "00:00";

      fileHash.text = await calculateSHA256OfFile(widget.file.path ?? '');
      fileSize.text =
          "${(widget.file.size / (1024 * 1024)).toStringAsFixed(1)} mb";

      await player.dispose();
      if (mounted) setState(() => _extracting = false);
    } catch (e) {
      debugPrint("Error extracting metadata: $e");
      _extractBasicFileInfo();
      if (mounted) setState(() { _extracting = false; _extractError = 'Could not read audio metadata — please review the fields below.'; });
    }
  }

  void _extractBasicFileInfo() {
    trackDurationMS = 0;
    recitationTitle.text = widget.file.name;
    recitersName.text = "";
    trackDuration.text = "Unknown";
    fileSize.text =
        "${(widget.file.size / (1024 * 1024)).toStringAsFixed(1)} mb";
  }

  void _onContinue() {
    if (!formKey.currentState!.validate()) return;

    final newAudio = SurahAudio(
      audioName: recitationTitle.text,
      surahNumber: widget.surahNumber,
      surahNameArabic: getSurahNameArabic(widget.surahNumber),
      surahNameEnglish: getSurahName(widget.surahNumber),
      totalAyahs: getVerseCount(widget.surahNumber),
      ayahs: [],
      reciterName: recitersName.text,
      fileHash: fileHash.text,
      trackDuration: trackDurationMS,
      localFileUrl: widget.file.path,
      uploadConsent: uploadFile,
      lastUpdated: DateTime.now(),
    );

    if (widget.launchTrainingOnSave) {
      // Save immediately and go straight to verse sync — no fake delay needed.
      widget.onSurahAdd?.call(newAudio);
      if (!context.mounted) return;
      Navigator.pushReplacement(
        context,
        AppRoute(
          builder: (_) => AudioTrainingScreen(
            newAudio,
            onUpdate: widget.onTrainingUpdate,
          ),
        ),
      );
    } else {
      // Original flow: show loading then SuccessPage.
      setState(() => loading = true);
      Future.delayed(const Duration(seconds: 3), () {
        if (!mounted) return;
        setState(() => loading = false);
        widget.onSurahAdd?.call(newAudio);
        if (!context.mounted) return;
        NavUtils.navTo(
            context,
            SuccessPage(
                message: "Recitation was successfully added to your list!",
                onProceed: (context) {
                  Navigator.pop(context);
                  Navigator.pop(context);
                }));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.launchTrainingOnSave
            ? "Set up audio"
            : "New Recitation"),
      ),
      body: _extracting
          ? _buildLoadingState()
          : Container(
              height: MediaQuery.of(context).size.height - 70,
              padding: const EdgeInsets.all(10),
              child: Form(
                key: formKey,
                child: Column(
                  children: [
                    Text(
                      getSurahNameArabic(widget.surahNumber),
                      style: ArabicAyahViewer.ayahTextStyle
                          .copyWith(fontWeight: FontWeight.bold),
                      textScaler: TextScaler.linear(3.0),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "${widget.surahNumber} - ${getSurahName(widget.surahNumber)}",
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 20),
                    if (_extractError != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_outlined,
                                size: 16, color: Colors.amber.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _extractError!,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.amber.shade800),
                              ),
                            ),
                          ],
                        ),
                      ),
                    AppTextField(
                      labelText: "Reciter's Name",
                      validator: (str) => str == null || str.isEmpty
                          ? "Please enter reciter's name"
                          : null,
                      controller: recitersName,
                    ),
                    const SizedBox(height: 10),
                    AppTextField(
                      labelText: "Recitation title",
                      validator: (str) => str == null || str.isEmpty
                          ? "Please enter a title"
                          : null,
                      controller: recitationTitle,
                    ),
                    const SizedBox(height: 20),
                    AppTextField(
                      labelText: "Playback Time",
                      controller: trackDuration,
                      enabled: false,
                    ),
                    const SizedBox(height: 10),
                    AppTextField(
                      labelText: "File Size",
                      controller: fileSize,
                      enabled: false,
                    ),
                    const SizedBox(height: 10),
                    AppTextField(
                      labelText: "Integrity Hash",
                      controller: fileHash,
                      enabled: false,
                      suffixIcon: fileHash.text.isEmpty
                          ? null
                          : const Icon(Icons.verified, color: Colors.green),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Expanded(
                            child: Text(
                          "Help your fellow travellers by uploading this recitation",
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        )),
                        Checkbox(
                            value: uploadFile,
                            onChanged: (enabled) =>
                                setState(() => uploadFile = enabled!))
                      ],
                    ),
                    if (widget.launchTrainingOnSave) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.info_outline,
                              size: 16, color: Colors.green),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              "Next you'll sync verses — tap a button each time a new verse begins.",
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: Colors.grey[600]),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 30),
                    const Spacer(),
                    AppButton(
                      label: widget.launchTrainingOnSave
                          ? "CONTINUE TO VERSE SYNC"
                          : "CONTINUE",
                      backgroundColor: AppColors.primaryColor,
                      labelColor: Colors.white,
                      loading: loading,
                      onTap: _onContinue,
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.primaryColor),
          const SizedBox(height: 20),
          Text(
            'Reading audio file…',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.file.name,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }
}
