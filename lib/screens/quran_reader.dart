import 'package:another_transformer_page_view/another_transformer_page_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quran/quran.dart';
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

  String surahLabel = "";
  bool showPageNumbers=false;

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
      surahLabel = getSurahNameArabic(surahNumber);
      juzNumber = getJuzNumber(surahNumber, surah['start']);
    });

  }

  IndexController controller = IndexController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: SafeArea(
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
                  AlertUtls.showModal(context, SurahSelector(onSurahSelected:(int surahNumber){
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
                        fontSize: 25,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  AlertUtls.showModal(context, JuzSelector(onJuzSelected:(int page){
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
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.all(10),
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.green, width: 5, style: BorderStyle.solid)
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.lightGreen, width: 2, style: BorderStyle.solid)
                          ),
                          child: ClipRect(
                            child: Align(
                              alignment: Alignment.center,
                              widthFactor: 0.99, // Adjust the width factor to crop the image
                              heightFactor: 0.99, // Adjust the height factor to crop the image
                              child: Image.asset('assets/pages/p${addPrecedingZeros(id)}.gif',fit: BoxFit.cover, ),
                            ),
                          ),
                        ),
                      ),

                      if(showPageNumbers)PageButton(page,(chosenPage){
                        controller.move(totalPages - chosenPage);
                        setState(() {
                          showPageNumbers = !showPageNumbers;
                        });
                      }),
                      if(!showPageNumbers)Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(onPressed: ()=> setState(() {
                            showPageNumbers = !showPageNumbers;
                          }),
                          icon: Text(getVerseEndSymbol(page),style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.green),)),
                        ],
                      )
                    ],
                  );
                }),
          ),
        ],
      ),
    ));
  }

  String addPrecedingZeros(int number) {
    if (number >= 0 && number <= 999) {
      return number.toString().padLeft(3, '0');
    } else {
      throw ArgumentError("Number must be between 0 and 999");
    }
  }
}
