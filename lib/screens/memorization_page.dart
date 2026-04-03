import 'dart:async';

import 'package:another_transformer_page_view/another_transformer_page_view.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quran/quran.dart';
import 'package:tahfeex/model/models.dart';
import 'package:tahfeex/resources/colors.dart';
import 'package:tahfeex/screens/screens.dart';
import 'package:tahfeex/service/services.dart';
import 'package:tahfeex/service/states/app_settings_state.dart';
import 'package:tahfeex/service/states/states.dart';
import 'package:tahfeex/utils/utils.dart';
import 'package:tahfeex/widgets/widgets.dart';

class MemorizationScreen extends StatefulWidget {
  const MemorizationScreen({super.key});

  @override
  State<MemorizationScreen> createState() => _MemorizationScreenState();
}

class _MemorizationScreenState extends State<MemorizationScreen> {
  static const int totalPages = 604;

  int page = 1;
  int ayah = 1;
  int juzNumber = 0;
  int ayahFrom = -1;
  int surahFrom = -1;
  int ayahTo = -1;
  int surahTo = -1;

  int repeatTimes = 3;
  int currentRepeat = 1;
  bool isRepeating = false;
  int totalVersesInSurah = 0;

  String surahLabel = '';
  bool settingAyahFrom = false;
  bool settingAyahTo = false;

  bool endingSurahPlayback = false;
  SurahAudio? surahAudio;
  int surahNumber = 1;

  // ── Focus / lock state ─────────────────────────────────────────────────────
  bool _controlsVisible = true;
  bool _locked = false;
  Timer? _autoHideTimer;

  void _scheduleAutoHide() {
    _autoHideTimer?.cancel();
    _autoHideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && !_locked) setState(() => _controlsVisible = false);
    });
  }

  void _revealControls() {
    if (_locked) return;
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    _scheduleAutoHide();
  }

  void _onContentTap() {
    if (_locked) return;
    if (_controlsVisible) {
      _autoHideTimer?.cancel();
      setState(() => _controlsVisible = false);
    } else {
      _revealControls();
    }
  }

  void _toggleLock() {
    setState(() {
      if (_locked) {
        _locked = false;
        _controlsVisible = true;
        _scheduleAutoHide();
      } else {
        _locked = true;
        _autoHideTimer?.cancel();
        _controlsVisible = false;
      }
    });
  }

  late MyAudioPlayer audioPlayer;

  @override
  void initState() {
    super.initState();
    audioPlayer = MyAudioPlayer(setState, durationUpdate: onDurationUpdated);
    page = context.read<MainCubit>().state.currentPage ?? 1;
    setPageLabels(page);
    loadSurahAudio(surahNumber);
    _scheduleAutoHide();
  }

  @override
  void dispose() {
    _autoHideTimer?.cancel();
    audioPlayer.dispose(); // BUG-01
    super.dispose(); // BUG-01: must be last
  }

  @override
  void deactivate() {
    audioPlayer.stop(isMounted: () => mounted, triggerRebuild: false);
    context.read<MainCubit>().updateCurrentPage(page);
    context.read<MainCubit>().updateCurrentVerse(ayah);
    super.deactivate();
  }

  Timer? canceller;
  void debouncer(Duration delay, Function fn) {
    if (canceller?.isActive ?? false) canceller?.cancel();
    canceller = Timer(delay, () {
      fn();
    });
  }

  void onDurationUpdated(Duration position) {
    if (isRepeating) return;
    if (surahAudio != null) {
      if (ayah <= surahAudio!.totalAyahs &&
          surahAudio!.ayahs.isNotEmpty &&
          ayah <= surahAudio!.ayahs.length) {
        final currentAyahEnding = surahAudio!.ayahs[ayah - 1].endAt;
        // print("${position.inSeconds} | $currentAyahEnding");
        if (position.inSeconds >= currentAyahEnding) {
          if (isRepeating || endingSurahPlayback) return;

          setState(() {
            ayah++;
          });
          print("NEW AYAH $ayah");

          if (surahNumber == surahTo && ayah - 1 == ayahTo) {
            repeatCycle();
          } else if (surahTo != surahNumber && ayah - 1 == totalVersesInSurah) {
            print("Reached end of surah, should move to next");
            endingSurahPlayback = true;
            Future.delayed(const Duration(seconds: 1), () {
              ayah = 1;
              changeSurah(surahNumber + 1);
              endingSurahPlayback = false;
              startPlayback();
            });
          }

          if (ayah <= surahAudio!.totalAyahs) {
            checkPageBasedOnAyah();
          }
        }
      } else {
        print("Unable to figure out next ayah in playback");
      }
    }
  }

  void checkPageBasedOnAyah() {
    int pageNumber = getPageNumber(surahNumber, ayah);
    if (pageNumber != page) {
      controller.move(totalPages - pageNumber);
    }
  }

  void repeatCycle() {
    print("Repeating");
    if (currentRepeat == repeatTimes) {
      audioPlayer.pause();
      currentRepeat = 1;
      print("Playback ended due to finished repeats");
      return;
    }
    isRepeating = true;
    currentRepeat++;
    audioPlayer.pause();
    var pageNumber = getPageNumber(surahFrom, ayahFrom);
    if (pageNumber != page) {
      controller.move(totalPages - pageNumber);
    }
    changeSurah(surahFrom);
  }

  void setPageLabels(int page) {
    var surah = getPageData(page).first;
    // BUG-08: was a local variable — never written to this.surahNumber.
    int newSurahNumber = surah['surah'];
    bool surahChanged = newSurahNumber != surahNumber;
    setState(() {
      surahLabel = getSurahName(newSurahNumber);
      juzNumber = getJuzNumber(newSurahNumber, surah['start']);
      surahNumber = newSurahNumber; // BUG-08 fix

      if (ayahFrom == -1) {
        ayahFrom = surah['start'];
      }
      // BUG-09: removed dead `if (ayah == -1)` — ayah starts at 1 and is never -1.
      if (ayahTo == -1) {
        ayahTo = getVerseCount(newSurahNumber);
      }
      if (surahFrom == -1) {
        surahFrom = newSurahNumber;
      }
      if (surahTo == -1) {
        surahTo = newSurahNumber;
      }
    });
    // BUG-08: load audio for the newly visible surah when not already playing.
    if (surahChanged && !audioPlayer.playing) {
      loadSurahAudio(newSurahNumber);
    }
  }

  changeSurah(int newSurah, {bool setPlaybackPoints = false}) {
    if (audioPlayer.playing) audioPlayer.stop(isMounted: () => mounted);
    setState(() {
      totalVersesInSurah = getVerseCount(newSurah);
      surahNumber = newSurah;
      if (setPlaybackPoints) {
        ayahFrom = 1;
        ayah = ayahFrom;
        ayahTo = totalVersesInSurah;
        surahFrom = surahNumber;
        surahTo = surahNumber;
      }
    });
    loadSurahAudio(surahNumber);
  }

  void loadSurahAudio(int surahNumber) {
    print("loading new surah audio $surahNumber");
    // if(audioPlayer.playing){
    audioPlayer.stop(isMounted: () => mounted);
    // }
    AppStorage storage = AppStorage();
    String surahsString = storage.getAudioSurahs(surahNumber);
    List<SurahAudio> files = SurahAudio.fromJsonArray(surahsString);
    if (files.isNotEmpty) {
      surahAudio = files.first;
    } else {
      surahAudio = null;
    }
    if (mounted) {
      setState(() {});
    }
    if (isRepeating && surahAudio != null) {
      startPlayback();
    }
  }

  void startPlayback({bool load = true}) {
    if (isRepeating) {
      setState(() {
        ayah = ayahFrom;
      });
      print("Ayah is now $ayah");
    }
    if (load) {
      audioPlayer.play(
          surahAudio!.localFileUrl ?? surahAudio!.remoteFileUrl ?? '',
          startFrom:
              surahAudio!.ayahs.isNotEmpty && ayah <= surahAudio!.ayahs.length
                  ? surahAudio!.ayahs[ayah - 1].startFrom
                  : 0);
      // print("here");
    } else {
      audioPlayer.seekTo(
          surahAudio!.ayahs.isNotEmpty && ayah <= surahAudio!.ayahs.length
              ? surahAudio!.ayahs[ayah - 1].startFrom
              : 0);
      audioPlayer.resume();
    }
    debouncer(const Duration(milliseconds: 500), () => isRepeating = false);
  }

  void addNewFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      if (context.mounted) {
        Navigator.push(
            context,
            AppRoute(
                builder: (ct) => NewAudio(
                      surahNumber,
                      result.files.single,
                      launchTrainingOnSave: true,
                      onSurahAdd: (newAudio) {
                        if (!context.mounted) return;
                        final storage = AppStorage();
                        final existing = SurahAudio.fromJsonArray(
                            storage.getAudioSurahs(surahNumber));
                        existing.add(newAudio);
                        storage.setAudioSurahs(
                            surahNumber, SurahAudio.toJsonArray(existing));
                        loadSurahAudio(surahNumber);
                      },
                      onTrainingUpdate: (updatedAudio) {
                        if (!context.mounted) return;
                        final storage = AppStorage();
                        final existing = SurahAudio.fromJsonArray(
                            storage.getAudioSurahs(surahNumber));
                        final idx = existing.indexWhere(
                            (s) => s.fileHash == updatedAudio.fileHash);
                        if (idx >= 0) existing[idx] = updatedAudio;
                        storage.setAudioSurahs(
                            surahNumber, SurahAudio.toJsonArray(existing));
                        loadSurahAudio(surahNumber);
                      },
                    )));
      }
    }
  }

  IndexController controller = IndexController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2EFE8),
      body: Stack(
        children: [
          // ── Full-screen page viewer ─────────────────────────────────────
          Positioned.fill(
            child: TransformerPageView(
              loop: false,
              index: totalPages - page,
              controller: controller,
              itemCount: totalPages,
              onPageChanged: (int? currentPage) {
                debouncer(const Duration(milliseconds: 500), () {
                  if (currentPage == null) return;
                  final int id = totalPages - currentPage;
                  setState(() => page = id);
                  setPageLabels(id);
                  _revealControls();
                });
              },
              itemBuilder: (BuildContext context, int index) {
                final int id = totalPages - index;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(10, 68, 10, 160),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.10),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        width: 3,
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColors.primaryMuted
                              .withValues(alpha: 0.5),
                        ),
                      ),
                      child: ClipRect(
                        child: Align(
                          alignment: Alignment.center,
                          widthFactor: 0.99,
                          heightFactor: 0.99,
                          child: ArabicPageViewer(
                            page: id,
                            ayah: ayah,
                            surah: surahNumber,
                            ayahColor:
                                (int ayahNumber, int surahNumber) {
                              if (ayahNumber == ayahFrom &&
                                  surahNumber == surahFrom) {
                                return Colors.orange;
                              } else if (ayahNumber == ayahTo &&
                                  surahNumber == surahTo) {
                                return Colors.red;
                              } else {
                                return null;
                              }
                            },
                            onBackgroundClick: () {
                              if (settingAyahFrom || settingAyahTo) {
                                setState(() {
                                  settingAyahFrom = false;
                                  settingAyahTo = false;
                                });
                              } else {
                                _onContentTap();
                              }
                            },
                            onAyahClicked: (int a, int surah) {
                              audioPlayer.pause();
                              setState(() {
                                if (settingAyahFrom) {
                                  ayahFrom = a;
                                  ayah = ayahFrom;
                                  surahFrom = surah;
                                  settingAyahFrom = false;
                                  currentRepeat = 1;
                                  if (surah == surahNumber) {
                                    print("seek to ayah");
                                    if (surahAudio != null) {
                                      audioPlayer.seekTo(surahAudio!
                                          .ayahs[ayahFrom - 1]
                                          .startFrom);
                                    }
                                  } else {
                                    if (surahFrom < surahTo) {
                                      print("Lets reload an audio");
                                    } else if (surahFrom > surahTo) {
                                      ayahTo = getVerseCount(surahFrom);
                                      surahTo = surahFrom;
                                    } else {
                                      if (ayahFrom < ayahTo) {
                                        ayahTo = ayahFrom;
                                      }
                                    }
                                    changeSurah(surah);
                                  }
                                } else if (settingAyahTo) {
                                  if (surah == surahNumber &&
                                      a < ayahFrom) {
                                    ayahTo = ayahFrom;
                                    surahTo = surahFrom;
                                    AlertUtls.toast(context,
                                        message:
                                            "Ending verse shouldn't be before starting verse");
                                  } else if (surah < surahNumber) {
                                    ayahTo = ayahFrom;
                                    surahTo = surahFrom;
                                    AlertUtls.toast(context,
                                        message:
                                            "Ending verse shouldn't be before starting verse");
                                  } else {
                                    ayahTo = a;
                                    surahTo = surah;
                                    settingAyahTo = false;
                                  }
                                } else {
                                  settingAyahFrom = false;
                                }
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // ── Top bar overlay ─────────────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: AnimatedSlide(
              offset: _controlsVisible
                  ? Offset.zero
                  : const Offset(0, -1),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: AnimatedOpacity(
                opacity: _controlsVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 220),
                child: IgnorePointer(
                  ignoring: !_controlsVisible,
                  child: _buildTopBar(),
                ),
              ),
            ),
          ),

          // ── Bottom bar overlay ──────────────────────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: AnimatedSlide(
              offset: _controlsVisible
                  ? Offset.zero
                  : const Offset(0, 1),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: AnimatedOpacity(
                opacity: _controlsVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 220),
                child: IgnorePointer(
                  ignoring: !_controlsVisible,
                  child: _buildBottomBar(),
                ),
              ),
            ),
          ),

          // ── Lock hint (always visible while locked) ───────────────────
          if (_locked)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 20,
              left: 0, right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: _toggleLock,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 9),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_outline,
                            size: 13, color: Colors.white70),
                        SizedBox(width: 7),
                        Text(
                          'Tap to unlock',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Material(
      color: AppColors.primary,
      elevation: 0,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              BackButton(
                color: Colors.white,
                onPressed: () => Navigator.maybePop(context),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _openSurahSelector,
                  child: Center(
                    child: Text(
                      surahLabel,
                      style: GoogleFonts.lateef(
                        textStyle: const TextStyle(
                          fontSize: 24,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              TextButton(
                onPressed: _openJuzSelector,
                child: Text(
                  'Juz $juzNumber',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  _locked ? Icons.lock : Icons.lock_open_outlined,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: _toggleLock,
                tooltip: _locked ? 'Unlock' : 'Lock screen',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Material(
      color: AppColors.cardSurface,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            border: Border(
                top: BorderSide(color: AppColors.border, width: 0.5)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Audio setup (when no audio loaded) ────────────────────
              if (surahAudio == null) _buildAudioSetupCard(),

              // ── Playback controls (when audio loaded) ─────────────────
              if (surahAudio != null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // From-ayah marker
                    IconButton(
                      onPressed: () => setState(() {
                        settingAyahFrom = !settingAyahFrom;
                        settingAyahTo = false;
                      }),
                      icon: Text(
                        settingAyahFrom ? '—' : getVerseEndSymbol(ayahFrom),
                        textScaler: TextScaler.linear(1.5),
                        style: TextStyle(
                          color: settingAyahFrom
                              ? AppColors.primary
                              : AppColors.textPrimary,
                        ),
                      ),
                      tooltip: 'Set start verse',
                    ),

                    // Play / Pause with repeat counter
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        AppIconButton(
                          onPressed: () {
                            if (audioPlayer.playing) {
                              audioPlayer.pause();
                            } else if (audioPlayer.initialisedPlayback) {
                              audioPlayer.resume();
                            } else {
                              startPlayback();
                            }
                          },
                          icon: audioPlayer.playing
                              ? Icons.pause
                              : Icons.play_arrow,
                          iconColor: AppColors.primary,
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.1),
                        ),
                        Positioned(
                          left: 20,
                          top: 10,
                          child: CircleAvatar(
                            backgroundColor: AppColors.primary,
                            radius: audioPlayer.playing ? 7 : 0.1,
                            child: Text(
                              (repeatTimes - currentRepeat).toString(),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // To-ayah marker
                    IconButton(
                      onPressed: () => setState(() {
                        settingAyahTo = !settingAyahTo;
                        settingAyahFrom = false;
                      }),
                      icon: Text(
                        settingAyahTo ? '—' : getVerseEndSymbol(ayahTo),
                        textScaler: TextScaler.linear(1.5),
                        style: TextStyle(
                          color: settingAyahTo
                              ? AppColors.primary
                              : AppColors.textPrimary,
                        ),
                      ),
                      tooltip: 'Set end verse',
                    ),

                    // More options
                    Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        AppIconButton(
                          icon: Icons.more_horiz,
                          iconSize: 17,
                          onPressed: () =>
                              AlertUtls.showModal(context, buildOptions()),
                        ),
                        if (surahAudio!.ayahs.length !=
                            surahAudio!.totalAyahs)
                          const Positioned(
                            right: 2,
                            top: 6,
                            child: CircleAvatar(
                              backgroundColor: Colors.orange,
                              radius: 5,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _openSurahSelector() {
    _revealControls();
    AlertUtls.showModal(
      context,
      SurahSelector(onSurahSelected: (int sNum) {
        changeSurah(sNum, setPlaybackPoints: true);
        final p = getSurahPages(sNum).first;
        controller.move(totalPages - p);
      }),
    );
  }

  void _openJuzSelector() {
    _revealControls();
    AlertUtls.showModal(
      context,
      JuzSelector(onJuzSelected: (int p) {
        controller.move(totalPages - p);
      }),
    );
  }

  void _showCommunityPicker() {
    CommunityAudioPicker.show(
      context,
      surahNumber: surahNumber,
      surahNameEnglish: surahLabel,
      onSelected: (audio) {
        final storage = AppStorage();
        final existing =
            SurahAudio.fromJsonArray(storage.getAudioSurahs(surahNumber));
        existing.add(audio);
        storage.setAudioSurahs(surahNumber, SurahAudio.toJsonArray(existing));
        loadSurahAudio(surahNumber);
      },
    );
  }

  void _showScholarPicker() {
    ScholarAudioPicker.show(
      context,
      surahNumber: surahNumber,
      surahNameEnglish: surahLabel,
      onSelected: (audio) {
        final storage = AppStorage();
        final existing =
            SurahAudio.fromJsonArray(storage.getAudioSurahs(surahNumber));
        existing.add(audio);
        storage.setAudioSurahs(surahNumber, SurahAudio.toJsonArray(existing));
        loadSurahAudio(surahNumber);
      },
    );
  }

  Widget _buildAudioSetupCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey[200]!,
            spreadRadius: 1,
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.headphones, color: Colors.green, size: 20),
            const SizedBox(width: 8),
            Text(
              "Audio-assisted memorization",
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ]),
          const SizedBox(height: 6),
          Text(
            "Sync a recitation and each verse will highlight as it plays.",
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: "My device",
                  backgroundColor: AppColors.primaryColor,
                  labelColor: Colors.white,
                  onTap: addNewFile,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton(
                  label: "Scholars",
                  backgroundColor: AppColors.primaryColor.withOpacity(0.12),
                  labelColor: AppColors.primaryColor,
                  onTap: _showScholarPicker,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton(
                  label: "Community",
                  backgroundColor: AppColors.primaryColor.withOpacity(0.12),
                  labelColor: AppColors.primaryColor,
                  onTap: _showCommunityPicker,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildOptions() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── drag handle ──────────────────────────────────────────────────
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
            const SizedBox(height: 14),
            Text(
              "Options",
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // ── NOW PLAYING ──────────────────────────────────────────────────
            if (surahAudio != null) ...[
              _sectionLabel("Now playing"),
              _NowPlayingCard(surahAudio: surahAudio!),
              // Incomplete-verses warning
              if (surahAudio!.ayahs.length != surahAudio!.totalAyahs) ...[
                const SizedBox(height: 8),
                Card(
                  color: Colors.orange[50],
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: Colors.orange[200]!),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_outlined,
                            color: Colors.orange, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Not all verses are synced yet",
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                        color: Colors.orange[800],
                                        fontWeight: FontWeight.w600),
                              ),
                              Text(
                                "${((surahAudio!.ayahs.length / surahAudio!.totalAyahs) * 100).toInt()}% done — finish syncing so every verse highlights correctly.",
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: Colors.orange[700]),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            NavUtils.navTo(
                              context,
                              AudioTrainingScreen(surahAudio!),
                              onReturn: (updated) {
                                if (updated != null) {
                                  setState(() => surahAudio = updated);
                                }
                              },
                            );
                          },
                          child: const Text("Resume"),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
            ],

            // ── PLAYBACK ─────────────────────────────────────────────────────
            _sectionLabel("Playback"),
            SettingsItem(
              label: "Repeat verses",
              description:
                  "How many times each selected range plays before moving on",
              leading: const SizedBox(
                  width: 30, child: AppIconButton(icon: Icons.repeat)),
              trailing: TextPopup(
                active: repeatTimesSelector
                    .indexWhere((e) => e == repeatTimes.toString()),
                width: 60,
                list: repeatTimesSelector,
                onSelected: (selected) {
                  setState(() {
                    repeatTimes = int.parse(repeatTimesSelector[selected]);
                  });
                  Navigator.pop(context);
                },
              ),
            ),
            const SizedBox(height: 20),

            // ── DISPLAY ──────────────────────────────────────────────────────
            _sectionLabel("Display"),
            SettingsItem(
              label: "Arabic text size",
              description: "Make the Quran text bigger or smaller",
              leading: const SizedBox(
                  width: 30, child: AppIconButton(icon: Icons.format_size)),
              trailing: BlocBuilder<SettingsCubit, SettingsState>(
                builder: (context, settingsState) {
                  return InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      AlertUtls.showModal(
                          context, const ArabicTextSizeSettings());
                    },
                    child: Chip(
                      label: Text(settingsState.arabicTextSize!.toString()),
                      backgroundColor: AppColors.primaryColor.withOpacity(0.12),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // ── RECITATIONS ──────────────────────────────────────────────────
            _sectionLabel("Recitations"),
            SettingsItem(
              label: "My recitations",
              description:
                  "Switch between saved recitations or find new ones from the community",
              leading: const SizedBox(
                  width: 30, child: AppIconButton(icon: Icons.library_music)),
              trailing: TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    AppRoute(
                      builder: (_) =>
                          AudioFilesScreen(surahNumber: surahNumber),
                    ),
                  ).then((_) => loadSurahAudio(surahNumber));
                },
                child: const Text("View"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.grey[500],
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  static const List<String> repeatTimesSelector = [
    '3',
    '5',
    '10',
    '15',
    '20',
    '50'
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// Now-playing card shown inside the playback options sheet
// ─────────────────────────────────────────────────────────────────────────────

class _NowPlayingCard extends StatefulWidget {
  final SurahAudio surahAudio;
  const _NowPlayingCard({required this.surahAudio});

  @override
  State<_NowPlayingCard> createState() => _NowPlayingCardState();
}

class _NowPlayingCardState extends State<_NowPlayingCard> {
  bool _isLiking = false;

  bool get _isCommunity => widget.surahAudio.contributionId != null;
  bool get _alreadyLiked =>
      _isCommunity &&
      AppStorage()
          .likedContributionIds
          .contains(widget.surahAudio.contributionId);

  Future<void> _like() async {
    if (_alreadyLiked || _isLiking) return;
    setState(() => _isLiking = true);
    try {
      await ContributionRepository()
          .likeContribution(widget.surahAudio.contributionId!);
      AppStorage().addLikedContributionId(widget.surahAudio.contributionId!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isLiking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final audio = widget.surahAudio;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primaryColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.headphones,
                  color: AppColors.primaryColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    audio.reciterName,
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_isCommunity)
                    Text(
                      audio.createdByName != null
                          ? 'Community · by ${audio.createdByName}'
                          : 'Community recording',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  else
                    Text(
                      'Local recording',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey[500]),
                    ),
                ],
              ),
            ),
            if (_isCommunity)
              _isLiking
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.primaryColor),
                    )
                  : IconButton(
                      onPressed: _alreadyLiked ? null : _like,
                      icon: Icon(
                        _alreadyLiked ? Icons.favorite : Icons.favorite_border,
                        color: _alreadyLiked ? Colors.red : Colors.grey,
                      ),
                      tooltip: _alreadyLiked ? 'Liked' : 'Like this recitation',
                    ),
          ],
        ),
      ),
    );
  }
}

class SettingsItem extends StatelessWidget {
  final Widget? leading, trailing;
  final String label;
  final String? description;

  const SettingsItem(
      {super.key,
      required this.label,
      this.leading,
      this.trailing,
      this.description});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            if (leading != null) leading!,
            if (leading != null) const SizedBox(width: 10),
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.black, fontWeight: FontWeight.bold)),
                if (description != null)
                  const SizedBox(
                    height: 7,
                  ),
                if (description != null)
                  Text(
                    description!,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey),
                  )
              ],
            )),
            if (trailing != null) trailing!
          ],
        ),
      ),
    );
  }
}
