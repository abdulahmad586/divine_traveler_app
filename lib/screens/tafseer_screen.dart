import 'package:another_transformer_page_view/another_transformer_page_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quran/quran.dart';
import 'package:tahfeex/model/models.dart';
import 'package:tahfeex/service/repositories/tafsir_repository.dart';
import 'package:tahfeex/service/states/app_settings_state.dart';
import 'package:tahfeex/service/states/states.dart';
import 'package:tahfeex/utils/utils.dart';
import 'package:tahfeex/widgets/widgets.dart';

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

  String surahLabel = "";
  bool showPageNumbers = false;

  @override
  void initState() {
    super.initState();
    ayah = context.read<MainCubit>().state.currentVerse??1;
    page = context.read<MainCubit>().state.currentPage??1;
    setSurahLabel(page);
  }

  void setSurahLabel(int page) {
    var surah = getPageData(page).first;
    int surahNumber = surah['surah'];
    setState(() {
      surahLabel = getSurahName(surahNumber);
      juzNumber = getJuzNumber(surahNumber, surah['start']);
    });
  }

  IndexController controller = IndexController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: SafeArea(
      child: Container(
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
                      var surahFirstPage = getSurahPages(surahNumber).first;
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
                    // BUG-06: guard against null before any use of currentPage.
                    if (currentPage == null) return;
                    final int id = totalPages - currentPage;
                    setSurahLabel(id);
                    List pageData = getPageData(id);
                    setState(() {
                      page = id;
                      ayah = pageData.first['start'];
                    });
                    context.read<MainCubit>().updateCurrentPage(id);
                    context.read<MainCubit>().updateCurrentVerse(ayah);
                  },
                  itemBuilder: (BuildContext context, int index) {
                    int id = totalPages - index; // Reverse the order of pages
                    return PageViewer(page:id);
                  }),
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
                            showPageNumbers = !showPageNumbers;
                          }),
                      icon: Text(
                        "($page)",
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.green),
                      )),
                ],
              )
          ],
        ),
      ),
    ));
  }
}

class PageViewer extends StatelessWidget {
  final int page;

  const PageViewer({super.key, this.page = 1});

  @override
  Widget build(BuildContext context) {
    List pageData = getPageData(page);
    List<Ayah> verses = [];

    for (var surah in pageData) {
      int startAyah = surah['start'];
      int endAyah = surah['end'];
      int surahNumber = surah['surah'];

      for (int i = startAyah; i <= endAyah; i++) {
        verses.add(Ayah(
            surahNumber: surahNumber,
            surahName: getSurahName(surahNumber),
            ayahNumber: i,
            totalAyahInSurah: getVerseCount(surahNumber),
            ayahContent: getVerse(surahNumber, i)));
      }
    }
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        return ListView.builder(
            itemCount: verses.length,
            itemBuilder: (context, index) {
              return AyahViewer(verses[index],ayahFontSize: state.arabicTextSize, verseFontSize:state.englishTextSize);
            });
      }
    );
  }
}

class AyahViewer extends StatelessWidget {
  final Ayah ayah;
  final int? ayahFontSize, verseFontSize;
  const AyahViewer(this.ayah, {this.ayahFontSize, this.verseFontSize, super.key});

  @override
  Widget build(BuildContext context) {
    final surah = ayah.surahNumber ?? 1;
    final ayahNo = ayah.ayahNumber ?? 1;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Ayah number ──────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  ayahNo.toString(),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold, color: Colors.green),
                ),
              ],
            ),
            // ── Arabic text ──────────────────────────────────────────────────
            Text(
              ayah.ayahContent ?? 'Unable to load verse',
              style: GoogleFonts.lateef(
                textStyle: TextStyle(
                  color: Colors.green,
                  letterSpacing: .5,
                  fontSize: (ayahFontSize ?? 25.0).toDouble(),
                ),
              ),
            ),
            const Divider(),
            // ── Translation ──────────────────────────────────────────────────
            Text(
              getVerseTranslation(surah, ayahNo,
                  translation: Translation.enSaheeh),
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(height: 1.5, color: Colors.grey),
            ),
            const Divider(height: 20),
            // ── Commentary (lazy) ────────────────────────────────────────────
            CommentarySection(surahNumber: surah, ayahNumber: ayahNo),
          ],
        ),
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
  // Single shared repo instance — cache is static inside TafsirRepository.
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
      if (mounted) setState(() { _tafsir = result; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Could not load commentary.'; _loading = false; });
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
                Icon(Icons.menu_book_outlined,
                    size: 15, color: Colors.green[700]),
                const SizedBox(width: 6),
                Text(
                  'Commentary',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.green[700],
                  ),
                ),
                const Spacer(),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 18,
                  color: Colors.grey[500],
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
              color: Colors.green,
              backgroundColor: Colors.transparent,
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.error_outline, size: 15, color: Colors.red[400]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(fontSize: 12, color: Colors.red[400]),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() { _error = null; });
                      _load();
                    },
                    child: Text(
                      'Retry',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.green[700],
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          if (_tafsir != null)
            ...(_tafsir!.tafsirs
                .map((t) => _TafsirEntry(tafsir: t))
                .toList()),
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
        const Divider(height: 16),
        // ── Author row ───────────────────────────────────────────────────────
        InkWell(
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.tafsir.author,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      if (widget.tafsir.groupVerse != null)
                        Text(
                          'Verse range: ${widget.tafsir.groupVerse}',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[500]),
                        ),
                    ],
                  ),
                ),
                Icon(
                  _open
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 18,
                  color: Colors.grey[500],
                ),
              ],
            ),
          ),
        ),
        // ── Content ──────────────────────────────────────────────────────────
        if (_open)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: MarkdownBody(
              data: widget.tafsir.content,
              styleSheet: MarkdownStyleSheet(
                p: TextStyle(fontSize: 13, height: 1.65, color: Colors.grey[800]),
                h1: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                h2: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                h3: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                strong: const TextStyle(fontWeight: FontWeight.bold),
                em: const TextStyle(fontStyle: FontStyle.italic),
                blockquote: TextStyle(
                  fontSize: 13,
                  height: 1.65,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
                blockquoteDecoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: Colors.grey[400]!, width: 3),
                  ),
                ),
                blockquotePadding: const EdgeInsets.only(left: 12),
              ),
              shrinkWrap: true,
            ),
          ),
      ],
    );
  }
}
