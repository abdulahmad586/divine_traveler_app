import 'dart:async';

import 'package:another_transformer_page_view/another_transformer_page_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quran/quran.dart';
import 'package:tahfeex/resources/resources.dart';
import 'package:tahfeex/service/states/states.dart';
import 'package:tahfeex/utils/utils.dart';
import 'package:tahfeex/widgets/widgets.dart';

class QuranReader extends StatefulWidget {
  final ValueNotifier<int>? pageChangeNotifier;

  const QuranReader({super.key, this.pageChangeNotifier});

  @override
  State<QuranReader> createState() => _QuranReaderState();
}

class _QuranReaderState extends State<QuranReader> {
  static const int totalPages = 604;

  int page = 1;
  int ayah = 0;
  int juzNumber = 0;
  int surahNumber = 1;
  String surahLabel = '';

  IndexController controller = IndexController();

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

  @override
  void initState() {
    super.initState();
    ayah  = context.read<MainCubit>().state.currentVerse ?? 1;
    page  = context.read<MainCubit>().state.currentPage  ?? 1;
    // Set initial surah/juz without setState (pre-first-build).
    final data = getPageData(page);
    final sNum = data.first['surah'] as int;
    surahNumber = sNum;
    surahLabel  = getSurahNameArabic(sNum);
    juzNumber   = getJuzNumber(sNum, data.first['start']);
    _scheduleAutoHide();
  }

  @override
  void dispose() {
    _autoHideTimer?.cancel();
    super.dispose();
  }

  void _updatePage(int id) {
    final data = getPageData(id);
    final sNum = data.first['surah'] as int;
    setState(() {
      page        = id;
      ayah        = data.first['start'];
      surahNumber = sNum;
      surahLabel  = getSurahNameArabic(sNum);
      juzNumber   = getJuzNumber(sNum, data.first['start']);
    });
    context.read<MainCubit>().updateCurrentPage(id);
    context.read<MainCubit>().updateCurrentVerse(ayah);
    _revealControls();
  }

  Future<void> _showGoToPageDialog() async {
    _revealControls();
    final controller = TextEditingController(text: '$page');
    await showDialog<void>(
      context: context,
      builder: (_) => AppDialog(
        title: 'Go to Page',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: '1 – 604',
                border: OutlineInputBorder(),
                helperText: 'Enter a page number between 1 and 604',
              ),
              textInputAction: TextInputAction.go,
              onSubmitted: (_) {
                _jumpToPage(controller.text);
                Navigator.pop(context);
              },
            ),
          ],
        ),
        actions: [
          AppDialogAction(
            label: 'Cancel',
            onPressed: () => Navigator.pop(context),
          ),
          AppDialogAction(
            label: 'Go',
            isPrimary: true,
            onPressed: () {
              _jumpToPage(controller.text);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
    controller.dispose();
  }

  void _jumpToPage(String input) {
    final n = int.tryParse(input.trim());
    if (n == null || n < 1 || n > totalPages) return;
    this.controller.move(totalPages - n);
  }

  void _openSurahSelector() {
    _revealControls();
    AlertUtls.showModal(
      context,
      SurahSelector(onSurahSelected: (int sNum) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2EFE8),
      body: Stack(
        children: [
          // ── Full-screen page viewer ───────────────────────────────────────
          Positioned.fill(
            child: GestureDetector(
              onTap: _onContentTap,
              child: TransformerPageView(
                loop: false,
                index: totalPages - page,
                controller: controller,
                itemCount: totalPages,
                onPageChanged: (int? currentPage) {
                  if (currentPage == null) return;
                  _updatePage(totalPages - currentPage);
                },
                itemBuilder: (BuildContext context, int index) {
                  final int id = totalPages - index;
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(10, 72, 10, 64),
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
                            color:
                                AppColors.primaryMuted.withValues(alpha: 0.5),
                          ),
                        ),
                        child: ClipRect(
                          child: Align(
                            alignment: Alignment.center,
                            widthFactor: 0.99,
                            heightFactor: 0.99,
                            child: Image.asset(
                              'assets/pages/p${_padded(id)}.gif',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // ── Top bar overlay ───────────────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: AnimatedSlide(
              offset:
                  _controlsVisible ? Offset.zero : const Offset(0, -1),
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

          // ── Bottom bar overlay ────────────────────────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: AnimatedSlide(
              offset:
                  _controlsVisible ? Offset.zero : const Offset(0, 1),
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

          // ── Lock hint (always visible while locked) ───────────────────────
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
              // ── Surah name (tappable → surah selector) ──────────────────
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
              // ── Juz button ───────────────────────────────────────────────
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
              // ── Lock toggle ──────────────────────────────────────────────
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
    final progress = page / totalPages;
    return Material(
      color: AppColors.cardSurface,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Slim progress strip
            LinearProgressIndicator(
              value: progress,
              minHeight: 2,
              backgroundColor: AppColors.border,
              valueColor:
                  const AlwaysStoppedAnimation(AppColors.primary),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  // Page info — tap to jump to a specific page
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _showGoToPageDialog,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Page $page',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                'of $totalPages',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.edit_outlined,
                              size: 13, color: AppColors.textSecondary),
                        ],
                      ),
                    ),
                  ),
                  // Quick-jump buttons
                  OutlinedButton.icon(
                    onPressed: _openSurahSelector,
                    icon: const Icon(Icons.menu_book_outlined, size: 15),
                    label: const Text('Surah'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side:
                          const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      textStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _openJuzSelector,
                    icon: const Icon(Icons.format_list_numbered,
                        size: 15),
                    label: Text('Juz $juzNumber'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side:
                          const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      textStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _padded(int number) => number.toString().padLeft(3, '0');
}
