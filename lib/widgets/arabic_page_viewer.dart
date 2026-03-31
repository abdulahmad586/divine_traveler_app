import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quran/quran.dart';
import 'package:tahfeex/model/models.dart';
import 'package:tahfeex/service/states/app_settings_state.dart';

// BUG-12: converted from StatelessWidget to StatefulWidget so that
// TapAndPanGestureRecognizers can be stored and disposed, preventing the
// per-rebuild leak that occurs when recognizers are created inside build().
class ArabicPageViewer extends StatefulWidget {
  final int page;
  final int ayah;
  final int surah;
  final Function(int, int)? onAyahClicked;
  final Function()? onBackgroundClick;
  final Color? Function(int, int)? ayahColor;

  const ArabicPageViewer(
      {super.key,
      this.page = 1,
      this.ayah = 1,
      required this.surah,
      this.onAyahClicked,
      this.ayahColor,
      this.onBackgroundClick});

  @override
  State<ArabicPageViewer> createState() => _ArabicPageViewerState();
}

class _ArabicPageViewerState extends State<ArabicPageViewer> {
  // All recognizers created during build are stored here and disposed on the
  // next build or when the widget is removed from the tree.
  final List<TapAndPanGestureRecognizer> _recognizers = [];

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Dispose previous recognizers before creating new ones for this build.
    _disposeRecognizers();

    List pageData = getPageData(widget.page);
    Map<int, List<Ayah>> surahs = {};

    for (var surah in pageData) {
      int startAyah = surah['start'];
      int endAyah = surah['end'];
      int surahNumber = surah['surah'];

      for (int i = startAyah; i <= endAyah; i++) {
        var ayah = Ayah(
            surahNumber: surahNumber,
            surahName: getSurahName(surahNumber),
            ayahNumber: i,
            totalAyahInSurah: getVerseCount(surahNumber),
            ayahContent: getVerse(surahNumber, i, verseEndSymbol: false));
        surahs[surahNumber] = surahs[surahNumber] ?? [];
        surahs[surahNumber]?.add(ayah);
      }
    }

    List<int> surahNumbers = surahs.keys.toList();
    return GestureDetector(
      onTap: widget.onBackgroundClick,
      child: Container(
          padding: const EdgeInsets.all(15),
          child: ListView.builder(
              itemCount: surahNumbers.length,
              itemBuilder: (context, index) {
                return _buildSurahText(context, surahs[surahNumbers[index]]!);
              })),
    );
  }

  Widget _buildSurahText(BuildContext context, List<Ayah> verses) {
    return BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, settingsState) {
      return Column(
        children: [
          if (verses[0].ayahNumber == 1 && verses[0].surahNumber != 1)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Text(getVerse(1, 1),
                    style: ArabicAyahViewer.ayahTextStyle.copyWith(
                        color: Colors.yellow[700],
                        fontSize: settingsState.arabicTextSize?.toDouble()))),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                    children: List.generate(
                  verses.length,
                  (index) {
                    final recognizer = TapAndPanGestureRecognizer();
                    _recognizers.add(recognizer); // track for disposal
                    if (widget.onAyahClicked != null) {
                      recognizer.onTapUp = (details) => widget.onAyahClicked!(
                          verses[index].ayahNumber!,
                          verses[index].surahNumber!);
                    }

                    return TextSpan(recognizer: null, children: [
                      TextSpan(
                          recognizer: recognizer,
                          text: " ${verses[index].ayahContent} ",
                          style: ArabicAyahViewer.ayahTextStyle.copyWith(
                              color: verses[index].ayahNumber == widget.ayah &&
                                      verses[index].surahNumber == widget.surah
                                  ? Colors.black
                                  : Colors.grey,
                              fontSize:
                                  settingsState.arabicTextSize?.toDouble())),
                      TextSpan(
                          recognizer: recognizer,
                          text: getVerseEndSymbol(verses[index].ayahNumber!),
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                  color: widget.ayahColor == null
                                      ? Colors.green
                                      : widget.ayahColor?.call(
                                              verses[index].ayahNumber!,
                                              verses[index].surahNumber!) ??
                                          Colors.green,
                                  fontWeight: FontWeight.bold))
                    ]);
                  },
                ))),
          ),
        ],
      );
    });
  }
}

class ArabicAyahViewer extends TextSpan {
  final Ayah ayah;
  const ArabicAyahViewer(this.ayah);

  static TextStyle ayahTextStyle = GoogleFonts.lateef(
    textStyle: const TextStyle(
      color: Colors.green,
      fontSize: 20,
    ),
  );

  @override
  Widget build(ParagraphBuilder,
      {List<PlaceholderDimensions>? dimensions, TextScaler? textScaler}) {
    return Text(ayah.ayahContent ?? "Unable to load verse",
        style: ayahTextStyle);
  }
}
