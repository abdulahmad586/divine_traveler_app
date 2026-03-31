import 'dart:io';

import 'package:another_transformer_page_view/another_transformer_page_view.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quran/quran.dart';
import 'package:tahfeex/model/models.dart';
import 'package:tahfeex/resources/resources.dart';
import 'package:tahfeex/screens/screens.dart';
import 'package:tahfeex/service/services.dart';
import 'package:tahfeex/utils/utils.dart';
import 'package:tahfeex/widgets/widgets.dart';

class AudioTrainingScreen extends StatefulWidget {
  final SurahAudio surahAudio;
  final Function(SurahAudio)? onUpdate;
  const AudioTrainingScreen(this.surahAudio, {super.key, this.onUpdate});

  @override
  State<AudioTrainingScreen> createState() => _AudioTrainingScreenState();
}

class _AudioTrainingScreenState extends State<AudioTrainingScreen> {
  static const int totalPages = 604;

  int page = 1;
  int ayah = 0;
  int juzNumber = 0;
  int ayahTo = -1;

  String surahLabel = "";
  bool showPageNumbers = false;
  bool showControls = true;
  double? controlPosition;
  late MyAudioPlayer audioPlayer;
  IndexController controller = IndexController();

  BuildContext? cubitContext;

  @override
  void initState() {
    super.initState();
    audioPlayer =
        MyAudioPlayer(setState, handlePlaybackError: handlePlaybackError);
    page = getPageNumber(
        widget.surahAudio.surahNumber,
        widget.surahAudio.ayahs.isEmpty
            ? 1
            : widget.surahAudio.ayahs.last.ayahNumber + 1);
    ayah = widget.surahAudio.ayahs.isEmpty
        ? 1
        : widget.surahAudio.ayahs.last.ayahNumber + 1;
    setSurahLabel(page);
    _showInstructionsIfNeeded();
  }

  void _showInstructionsIfNeeded() {
    final settings = AppSettings();
    if (settings.hasSeenTrainInstructions) return;
    settings.hasSeenTrainInstructions = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isDismissible: false,
        enableDrag: false,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => const _TrainingInstructionsSheet(),
      );
    });
  }

  @override
  void dispose() {
    audioPlayer.dispose(); // BUG-01: dispose the underlying AudioPlayer
    super.dispose(); // BUG-01: must be last
  }

  @override
  void deactivate() {
    if (widget.onUpdate != null) widget.onUpdate!(widget.surahAudio);
    audioPlayer.stop(isMounted: () => mounted, triggerRebuild: false);
    super.deactivate();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  void handlePlaybackError(Object? error) {
    AlertUtls.toast(context,
        message: (error ?? "An error occurred").toString());
  }

  void setSurahLabel(int page) {
    var surah = getPageData(page).first;
    int surahNumber = surah['surah'];
    setState(() {
      surahLabel = getSurahName(surahNumber);
      juzNumber = getJuzNumber(surahNumber, surah['start']);
      if (ayahTo == -1) {
        ayahTo = surah['end'];
      }
    });
  }

  void addAyah() {
    if (audioPlayer.playing) {
      print("Mark added at ${audioPlayer.position}");
      var ayahAudio = AyahAudio(
          ayahNumber: ayah,
          startFrom: widget.surahAudio.ayahs.isEmpty
              ? 0
              : widget.surahAudio.ayahs.last.endAt,
          endAt: audioPlayer.position);
      widget.surahAudio.ayahs.add(ayahAudio);
      setState(() {
        ayah = ayah + 1;
      });
      checkPageBasedOnAyah();

      // All verses synced — stop playback and show the completion sheet.
      if (widget.surahAudio.ayahs.length == widget.surahAudio.totalAyahs) {
        audioPlayer.stop(isMounted: () => mounted);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showSyncCompleteSheet();
        });
      }
    }
  }

  void _showSyncCompleteSheet() {
    showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SyncCompleteSheet(
        surahAudio: widget.surahAudio,
        onUpload: () {
          Navigator.pop(context); // close this sheet
          UploadProgressSheet.show(
            context,
            surahAudio: widget.surahAudio,
            onSuccess: (result) {
              widget.surahAudio.driveFileId = result.audioFileId;
              widget.surahAudio.driveTimingFileId = result.timingFileId;
              widget.surahAudio.remoteFileUrl = result.audioPublicUrl;
              widget.onUpdate?.call(widget.surahAudio);
            },
          );
        },
        onDone: () => Navigator.pop(context),
      ),
    );
  }

  void removeLastAyah() {
    bool wasPlaying = audioPlayer.playing;
    if (!audioPlayer.initialisedPlayback) {
      AlertUtls.toast(context, message: "Please start playing first");
      return;
    }
    if (widget.surahAudio.ayahs.isNotEmpty) {
      audioPlayer.pause();
      var audioAyah = widget.surahAudio.ayahs.removeLast();
      audioPlayer.seekTo(audioAyah.startFrom);
      setState(() {
        ayah = ayah - 1;
      });
      if (wasPlaying) {
        audioPlayer.resume();
      }
      checkPageBasedOnAyah();
    }
  }

  void checkPageBasedOnAyah() {
    int pageNumber = getPageNumber(widget.surahAudio.surahNumber, ayah);
    if (pageNumber != page) {
      controller.move(totalPages - pageNumber);
    }
  }

  @override
  Widget build(BuildContext context) {
    // BUG-15: WillPopScope was removed in Flutter 3.16; use PopScope instead.
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) Navigator.of(context).pop(widget.surahAudio);
      },
      child: Scaffold(
          body: SafeArea(
        child: Stack(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios),
                      ),
                      TextButton(
                        onPressed: () {
                          AlertUtls.showModal(context,
                              SurahSelector(onSurahSelected: (int surahNumber) {
                            var surahFirstPage =
                                getSurahPages(surahNumber).first;
                            controller.move(totalPages - surahFirstPage);
                          }));
                        },
                        child: Text(
                          surahLabel,
                          style: GoogleFonts.lateef(
                            textStyle: const TextStyle(
                                color: Colors.green,
                                letterSpacing: .5,
                                fontSize: 20,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          AlertUtls.showModal(context,
                              JuzSelector(onJuzSelected: (int page) {
                            controller.move(totalPages - page);
                          }));
                        },
                        child: Text(
                          'Juz $juzNumber',
                          style: GoogleFonts.lateef(
                            textStyle: const TextStyle(
                                color: Colors.green,
                                letterSpacing: .5,
                                fontSize: 20,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: TransformerPageView(
                        loop: false,
                        index: totalPages - page,
                        controller: controller,
                        itemCount: totalPages,
                        onPageChanged: (int? currentPage) {
                          int id = totalPages - (currentPage ?? totalPages);
                          setSurahLabel(id);

                          List pageData = getPageData(currentPage!);

                          setState(() {
                            page = totalPages - currentPage;
                            if (ayahTo == -1) {
                              ayahTo = pageData.last['end'];
                            }
                          });
                        },
                        itemBuilder: (BuildContext context, int index) {
                          int id =
                              totalPages - index; // Reverse the order of pages
                          double screenHeight =
                              MediaQuery.of(context).size.height;
                          return Column(
                            children: [
                              SingleChildScrollView(
                                child: Container(
                                  margin: const EdgeInsets.all(5),
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                      color: Colors.white,
                                      border: Border.all(
                                          color: Colors.green,
                                          width: 5,
                                          style: BorderStyle.solid)),
                                  child: Container(
                                    height: screenHeight > 600
                                        ? screenHeight * .7
                                        : 600,
                                    decoration: BoxDecoration(
                                        color: Colors.white,
                                        border: Border.all(
                                            color: Colors.lightGreen,
                                            width: 2,
                                            style: BorderStyle.solid)),
                                    child: ClipRect(
                                      child: Align(
                                        alignment: Alignment.center,
                                        widthFactor:
                                            0.99, // Adjust the width factor to crop the image
                                        heightFactor:
                                            0.99, // Adjust the height factor to crop the image
                                        child: ArabicPageViewer(
                                          page: id,
                                          ayah: ayah,
                                          surah: widget.surahAudio.surahNumber,
                                          onAyahClicked: (int a, int surah) {},
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (showPageNumbers)
                                PageButton(page, (chosenPage) {
                                  controller.move(totalPages - chosenPage);
                                  setState(() {
                                    showPageNumbers = !showPageNumbers;
                                  });
                                }),
                              if (!showPageNumbers)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton(
                                        onPressed: () => setState(() {
                                              showPageNumbers =
                                                  !showPageNumbers;
                                            }),
                                        icon: Text(
                                          getVerseEndSymbol(page),
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge
                                              ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.green),
                                        )),
                                  ],
                                )
                            ],
                          );
                        }),
                  ),
                ],
              ),
            ),
            Positioned(
                bottom: controlPosition ?? 60,
                width: MediaQuery.of(context).size.width - 10,
                child: _buildControls()),
          ],
        ),
      )),
    );
  }

  Widget _buildControls() {
    var screenHeight = MediaQuery.of(context).size.height;
    return Align(
      alignment: Alignment.bottomCenter,
      child: GestureDetector(
        onVerticalDragUpdate: (details) {
          setState(() {
            // BUG-17: clamp so controls cannot be dragged off-screen.
            final newPos = screenHeight - details.globalPosition.dy;
            controlPosition = newPos.clamp(0.0, screenHeight - 80);
          });
        },
        child: Container(
          // width: MediaQuery.of(context).size.width * .8,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AppIconButton(
                    icon: Icons.undo,
                    iconSize: 17,
                    onPressed: () {
                      removeLastAyah();
                    },
                  ),
                  if (showControls)
                    Container(
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              const BorderRadius.all(Radius.circular(30)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey[300]!,
                              spreadRadius: 1,
                              blurRadius: 10,
                            )
                          ]),
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          IconButton(
                              onPressed: () {},
                              icon: Text(
                                getVerseEndSymbol(widget
                                        .surahAudio.ayahs.isEmpty
                                    ? 1
                                    : widget.surahAudio.ayahs.last.ayahNumber),
                                textScaler: TextScaler.linear(1.5),
                              )),
                          // "Mark verse" — tap when a new verse begins in the audio.
                          ElevatedButton.icon(
                            onPressed: audioPlayer.playing ? addAyah : null,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text("Mark verse"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: audioPlayer.playing
                                  ? Colors.green[700]
                                  : Colors.grey[300],
                              foregroundColor: audioPlayer.playing
                                  ? Colors.white
                                  : Colors.grey,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                            ),
                          ),
                          IconButton(
                            onPressed: () {},
                            icon: Text(
                              getVerseEndSymbol(ayah),
                              textScaler: TextScaler.linear(1.5),
                              style: const TextStyle(color: Colors.green),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (showControls)
                    AppIconButton(
                      icon:
                          audioPlayer.playing ? Icons.pause : Icons.play_arrow,
                      iconSize: 17,
                      onPressed: () {
                        if (audioPlayer.playing) {
                          audioPlayer.pause();
                        } else {
                          if (audioPlayer.initialisedPlayback) {
                            audioPlayer.resume();
                          } else {
                            String filePath = widget.surahAudio.localFileUrl ??
                                widget.surahAudio.remoteFileUrl ??
                                '';
                            void play(filePath) {
                              audioPlayer.play(filePath,
                                  startFrom: widget.surahAudio.ayahs.isEmpty
                                      ? null
                                      : widget.surahAudio.ayahs.last.endAt);
                            }

                            if (filePath.isEmpty ||
                                (widget.surahAudio.remoteFileUrl == null &&
                                    !File(filePath).existsSync())) {
                              // AlertUtls.toast(context, message:"Could not play: Audio file not found");
                              NavUtils.navTo(
                                context,
                                ErrorPage(
                                  title: "Oops! Missing File",
                                  message:
                                      "Your local audio file seems to be missing from it's last known location, please select the file again to proceed",
                                  onButtonPress: (context) async {
                                    Navigator.pop(context);
                                    Future.delayed(
                                        const Duration(milliseconds: 500),
                                        () async {
                                      FilePickerResult? result =
                                          await FilePicker.platform.pickFiles();
                                      if (result != null) {
                                        filePath = result.files.first.path!;
                                        widget.surahAudio.localFileUrl =
                                            filePath;
                                        widget.onUpdate
                                            ?.call(widget.surahAudio);
                                        play(filePath);
                                      }
                                    });
                                  },
                                  buttonLabel: "SELECT FILE",
                                ),
                              );
                            } else {
                              play(filePath);
                            }
                          }
                        }
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrainingInstructionsSheet extends StatelessWidget {
  const _TrainingInstructionsSheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "How verse sync works",
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          _InstructionStep(
            icon: Icons.play_arrow,
            color: Colors.green,
            text: "Tap play to start the audio.",
          ),
          _InstructionStep(
            icon: Icons.add_circle_outline,
            color: Colors.green,
            text: "Each time you hear a new verse begin, tap \"Mark verse\".",
          ),
          _InstructionStep(
            icon: Icons.undo,
            color: Colors.orange,
            text: "Made a mistake? Tap ↩ to remove the last mark.",
          ),
          const SizedBox(height: 8),
          Text(
            "The app records exactly when each verse starts so it can follow along during memorization.",
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              label: "Let's go",
              backgroundColor: AppColors.primaryColor,
              labelColor: Colors.white,
              onTap: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _InstructionStep extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _InstructionStep(
      {required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
              child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Sync-complete sheet
// ──────────────────────────────────────────────────────────────────────────────

class _SyncCompleteSheet extends StatelessWidget {
  final SurahAudio surahAudio;
  final VoidCallback onUpload;
  final VoidCallback onDone;

  const _SyncCompleteSheet({
    required this.surahAudio,
    required this.onUpload,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 28),
              const SizedBox(width: 10),
              Text(
                'All ${surahAudio.totalAyahs} verses synced!',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Your timing data for ${surahAudio.surahNameEnglish} is ready.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          if (surahAudio.uploadConsent) ...[
            Text(
              'You chose to share this recitation with other users.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: 'UPLOAD TO COMMUNITY',
                backgroundColor: AppColors.primaryColor,
                labelColor: Colors.white,
                onTap: onUpload,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: 'NOT NOW',
                backgroundColor: Colors.grey[200]!,
                labelColor: Colors.black87,
                onTap: onDone,
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: 'DONE',
                backgroundColor: AppColors.primaryColor,
                labelColor: Colors.white,
                onTap: onDone,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
