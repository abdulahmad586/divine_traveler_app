import 'dart:async';

import 'package:another_transformer_page_view/another_transformer_page_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quran/quran.dart';
import 'package:tahfeex/model/models.dart';
import 'package:tahfeex/resources/resources.dart';
import 'package:tahfeex/service/repositories/tafsir_repository.dart';
import 'package:tahfeex/service/states/app_settings_state.dart';
import 'package:tahfeex/service/states/states.dart';
import 'package:tahfeex/utils/utils.dart';
import 'package:tahfeex/widgets/widgets.dart';

// ── Reading palette ───────────────────────────────────────────────────────────
const _kBg = Color(0xFFFAF8F2); // warm parchment
const _kInk = Color(0xFF1C1510); // deep ink — Arabic, headings
const _kSepia = Color(0xFF3B2F25); // translation body
const _kMuted = Color(0xFF8C7B6B); // metadata, labels
const _kBorder = Color(0xFFE4D9CA); // dividers, borders

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class TafseerScreen extends StatefulWidget {
  const TafseerScreen({super.key});

  @override
  State<TafseerScreen> createState() => _TafseerScreenState();
}

class _TafseerScreenState extends State<TafseerScreen> {
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
    _autoHideTimer = Timer(const Duration(seconds: 5), () {
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
    ayah = context.read<MainCubit>().state.currentVerse ?? 1;
    page = context.read<MainCubit>().state.currentPage ?? 1;
    final data = getPageData(page);
    final sNum = data.first['surah'] as int;
    surahNumber = sNum;
    surahLabel = getSurahName(sNum);
    juzNumber = getJuzNumber(sNum, data.first['start']);
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
      page = id;
      ayah = data.first['start'];
      surahNumber = sNum;
      surahLabel = getSurahName(sNum);
      juzNumber = getJuzNumber(sNum, data.first['start']);
    });
    context.read<MainCubit>().updateCurrentPage(id);
    context.read<MainCubit>().updateCurrentVerse(ayah);
    _revealControls();
  }

  void _openSurahSelector() {
    _revealControls();
    AlertUtls.showModal(context, SurahSelector(onSurahSelected: (int sNum) {
      final p = getSurahPages(sNum).first;
      controller.move(totalPages - p);
    }));
  }

  void _openJuzSelector() {
    _revealControls();
    AlertUtls.showModal(context, JuzSelector(onJuzSelected: (int p) {
      controller.move(totalPages - p);
    }));
  }

  Future<void> _showGoToPageDialog() async {
    _revealControls();
    final ctrl = TextEditingController(text: '$page');
    await showDialog<void>(
      context: context,
      builder: (_) => AppDialog(
        title: 'Go to Page',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: '1 – 604',
                border: OutlineInputBorder(),
                helperText: 'Enter a page number between 1 and 604',
              ),
              textInputAction: TextInputAction.go,
              onSubmitted: (_) {
                _jumpToPage(ctrl.text);
                Navigator.pop(context);
              },
            ),
          ],
        ),
        actions: [
          AppDialogAction(
              label: 'Cancel', onPressed: () => Navigator.pop(context)),
          AppDialogAction(
            label: 'Go',
            isPrimary: true,
            onPressed: () {
              _jumpToPage(ctrl.text);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
    ctrl.dispose();
  }

  void _jumpToPage(String input) {
    final n = int.tryParse(input.trim());
    if (n == null || n < 1 || n > totalPages) return;
    controller.move(totalPages - n);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          // ── Full-screen reading area ──────────────────────────────────────
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
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
                  return BlocBuilder<SettingsCubit, SettingsState>(
                    builder: (context, settings) => PageViewer(
                      page: id,
                      ayahFontSize: settings.arabicTextSize,
                      verseFontSize: settings.englishTextSize,
                    ),
                  );
                },
              ),
            ),
          ),

          // ── Top bar overlay ───────────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedSlide(
              offset: _controlsVisible ? Offset.zero : const Offset(0, -1),
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
            bottom: 0,
            left: 0,
            right: 0,
            child: AnimatedSlide(
              offset: _controlsVisible ? Offset.zero : const Offset(0, 1),
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

          // ── Lock hint ─────────────────────────────────────────────────────
          if (_locked)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 20,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: _toggleLock,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
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
              // ── Surah name ─────────────────────────────────────────────
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _openSurahSelector,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        surahLabel,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                      Text(
                        'Tafsir · Page $page',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white60,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
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
    final progress = page / totalPages;
    return Material(
      color: _kBg,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress strip
            LinearProgressIndicator(
              value: progress,
              minHeight: 2,
              backgroundColor: _kBorder,
              valueColor: const AlwaysStoppedAnimation(AppColors.gold),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  // Page indicator — tappable to jump
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
                                  color: _kInk,
                                ),
                              ),
                              Text(
                                'of $totalPages',
                                style: const TextStyle(
                                    fontSize: 11, color: _kMuted),
                              ),
                            ],
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.edit_outlined,
                              size: 13, color: _kMuted),
                        ],
                      ),
                    ),
                  ),
                  // Jump buttons
                  OutlinedButton.icon(
                    onPressed: _openSurahSelector,
                    icon: const Icon(Icons.menu_book_outlined, size: 15),
                    label: const Text('Surah'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
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
                    icon: const Icon(Icons.format_list_numbered, size: 15),
                    label: Text('Juz $juzNumber'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Page viewer — renders one Quran page as a scrollable reading column
// ─────────────────────────────────────────────────────────────────────────────

class PageViewer extends StatelessWidget {
  final int page;
  final int? ayahFontSize;
  final int? verseFontSize;

  const PageViewer({
    super.key,
    this.page = 1,
    this.ayahFontSize,
    this.verseFontSize,
  });

  @override
  Widget build(BuildContext context) {
    final pageData = getPageData(page);

    // Build a flat list: surah headers + ayah viewers interleaved
    final List<Widget> items = [];
    for (final surahEntry in pageData) {
      final surahNo = surahEntry['surah'] as int;
      final startAyah = surahEntry['start'] as int;
      final endAyah = surahEntry['end'] as int;
      items.add(_SurahDivider(
        surahNo: surahNo,
        startAyah: startAyah,
        isNewSurah: startAyah == 1,
      ));
      for (int i = startAyah; i <= endAyah; i++) {
        items.add(AyahViewer(
          Ayah(
            surahNumber: surahNo,
            surahName: getSurahName(surahNo),
            ayahNumber: i,
            totalAyahInSurah: getVerseCount(surahNo),
            ayahContent: getVerse(surahNo, i),
          ),
          ayahFontSize: ayahFontSize,
          verseFontSize: verseFontSize,
        ));
      }
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 72, 0, 100),
      itemCount: items.length,
      itemBuilder: (_, i) => items[i],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Surah divider — full chapter heading when surah starts, slim label otherwise
// ─────────────────────────────────────────────────────────────────────────────

class _SurahDivider extends StatelessWidget {
  final int surahNo;
  final int startAyah;
  final bool isNewSurah;

  const _SurahDivider({
    required this.surahNo,
    required this.startAyah,
    required this.isNewSurah,
  });

  @override
  Widget build(BuildContext context) {
    if (isNewSurah) {
      // Full chapter heading
      return Container(
        margin: const EdgeInsets.fromLTRB(28, 12, 28, 28),
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.gold.withValues(alpha: 0.04),
          border: Border.all(
              color: AppColors.gold.withValues(alpha: 0.22), width: 0.8),
        ),
        child: Column(
          children: [
            Text(
              getSurahNameArabic(surahNo),
              textAlign: TextAlign.center,
              style: GoogleFonts.lateef(
                textStyle: const TextStyle(
                  fontSize: 30,
                  color: _kInk,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              getSurahName(surahNo).toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.gold,
                letterSpacing: 2.8,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${getVerseCount(surahNo)} verses',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: _kMuted),
            ),
          ],
        ),
      );
    }

    // Continuation — slim surah label with starting ayah context
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 12),
      child: Row(
        children: [
          Expanded(
            child: Container(height: 0.5, color: _kBorder),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '${getSurahName(surahNo)}  ·  from verse $startAyah',
              style: const TextStyle(
                fontSize: 11,
                color: _kMuted,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),
          ),
          Expanded(
            child: Container(height: 0.5, color: _kBorder),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ayah viewer — typography-first, no card chrome
// ─────────────────────────────────────────────────────────────────────────────

class AyahViewer extends StatelessWidget {
  final Ayah ayah;
  final int? ayahFontSize;
  final int? verseFontSize;

  const AyahViewer(
    this.ayah, {
    this.ayahFontSize,
    this.verseFontSize,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final surah = ayah.surahNumber ?? 1;
    final ayahNo = ayah.ayahNumber ?? 1;
    final arabicSize = (ayahFontSize ?? 34).toDouble();
    final verseSize = (verseFontSize ?? 15).toDouble();

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Verse number badge ───────────────────────────────────────────
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.gold.withValues(alpha: 0.08),
                border:
                    Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
              ),
              child: Center(
                child: Text(
                  '$ayahNo',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.gold,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),

          // ── Arabic text ──────────────────────────────────────────────────
          Text(
            ayah.ayahContent ?? 'Unable to load verse',
            textAlign: TextAlign.right,
            style: GoogleFonts.lateef(
              textStyle: TextStyle(
                fontSize: arabicSize,
                color: _kInk,
                height: 2.05,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(height: 22),

          // ── Thin ornamental rule ─────────────────────────────────────────
          Row(
            children: [
              const Expanded(child: Divider(color: _kBorder, height: 1)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.gold,
                  ),
                ),
              ),
              const Expanded(child: Divider(color: _kBorder, height: 1)),
            ],
          ),
          const SizedBox(height: 18),

          // ── Translation ──────────────────────────────────────────────────
          Text(
            getVerseTranslation(surah, ayahNo,
                translation: Translation.enSaheeh),
            textAlign: TextAlign.justify,
            style: TextStyle(
              fontSize: verseSize,
              height: 1.9,
              color: _kSepia,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 24),

          // ── Commentary ───────────────────────────────────────────────────
          CommentarySection(surahNumber: surah, ayahNumber: ayahNo),

          // ── Verse end spacer ─────────────────────────────────────────────
          const SizedBox(height: 32),
          const Divider(color: _kBorder, height: 1),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Commentary section — fetches only when first expanded, cached globally
// ─────────────────────────────────────────────────────────────────────────────

/// Public so it can be reused in the Quran journey screen.
class CommentarySection extends StatefulWidget {
  final int surahNumber;
  final int ayahNumber;

  const CommentarySection({
    super.key,
    required this.surahNumber,
    required this.ayahNumber,
  });

  @override
  State<CommentarySection> createState() => _CommentarySectionState();
}

class _CommentarySectionState extends State<CommentarySection> {
  static final _repo = TafsirRepository();

  bool _expanded = false;
  bool _loading = false;
  TafsirResponse? _tafsir;
  String? _error;

  Future<void> _load() async {
    if (_tafsir != null || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _repo.getTafsir(
        surahNo: widget.surahNumber,
        ayahNo: widget.ayahNumber,
      );
      if (mounted)
        setState(() {
          _tafsir = result;
          _loading = false;
        });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not load commentary.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header row ───────────────────────────────────────────────────────
        InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () {
            final nowExpanded = !_expanded;
            setState(() => _expanded = nowExpanded);
            if (nowExpanded) _load();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.menu_book_outlined,
                    size: 15, color: AppColors.primary),
                const SizedBox(width: 6),
                const Text(
                  'Commentary',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const Spacer(),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 18,
                  color: _kMuted,
                ),
              ],
            ),
          ),
        ),

        // ── Expanded body ────────────────────────────────────────────────────
        if (_expanded) ...[
          const SizedBox(height: 8),
          if (_loading)
            const LinearProgressIndicator(
              minHeight: 2,
              color: AppColors.primary,
              backgroundColor: Colors.transparent,
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, size: 15, color: Colors.red),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(_error!,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.red)),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() => _error = null);
                      _load();
                    },
                    child: const Text(
                      'Retry',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (_tafsir != null)
            ...(_tafsir!.tafsirs.map((t) => _TafsirEntry(tafsir: t)).toList()),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single tafsir entry — collapsible by author
// ─────────────────────────────────────────────────────────────────────────────

class _TafsirEntry extends StatefulWidget {
  final Tafsir tafsir;
  const _TafsirEntry({required this.tafsir});

  @override
  State<_TafsirEntry> createState() => _TafsirEntryState();
}

class _TafsirEntryState extends State<_TafsirEntry> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 20, color: _kBorder),

        // ── Author row ───────────────────────────────────────────────────────
        InkWell(
          onTap: () => setState(() => _open = !_open),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Scholar initial badge
                Container(
                  width: 30,
                  height: 30,
                  margin: const EdgeInsets.only(right: 10, top: 1),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.15)),
                  ),
                  child: Center(
                    child: Text(
                      widget.tafsir.author.isNotEmpty
                          ? widget.tafsir.author[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.tafsir.author,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _kInk,
                        ),
                      ),
                      if (widget.tafsir.groupVerse != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'Verse range: ${widget.tafsir.groupVerse}',
                            style:
                                const TextStyle(fontSize: 11, color: _kMuted),
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  _open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 18,
                  color: _kMuted,
                ),
              ],
            ),
          ),
        ),

        // ── Commentary text ──────────────────────────────────────────────────
        if (_open)
          Padding(
            padding: const EdgeInsets.only(bottom: 12, top: 4),
            child: MarkdownBody(
              data: widget.tafsir.content,
              styleSheet: MarkdownStyleSheet(
                textAlign: WrapAlignment.spaceBetween,
                p: const TextStyle(fontSize: 14, height: 1.85, color: _kSepia),
                h1: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold, color: _kInk),
                h2: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold, color: _kInk),
                h3: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.bold, color: _kInk),
                strong:
                    const TextStyle(fontWeight: FontWeight.bold, color: _kInk),
                em: const TextStyle(fontStyle: FontStyle.italic),
                blockquote: const TextStyle(
                  fontSize: 14,
                  height: 1.85,
                  color: _kMuted,
                  fontStyle: FontStyle.italic,
                ),
                blockquoteDecoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                        color: AppColors.gold.withValues(alpha: 0.5), width: 3),
                  ),
                ),
                blockquotePadding: const EdgeInsets.only(left: 14),
              ),
              shrinkWrap: true,
            ),
          ),
      ],
    );
  }
}
