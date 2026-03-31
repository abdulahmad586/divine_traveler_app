import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quran/quran.dart';

class JuzSelector extends StatelessWidget {
  final Function(int) onJuzSelected;
  const JuzSelector({super.key, required this.onJuzSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      height: 500,
      child: Column(
        children: [
          const SizedBox(height: 10,),
          Text("SELECT JUZ", style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.green, fontWeight: FontWeight.bold),),
          const SizedBox(height: 10,),
          Expanded(
            child: ListView.builder(
              itemCount: totalJuzCount,
              itemBuilder: (context, index) {
                Map<int, List<int>> juzData = getSurahAndVersesFromJuz(index+1);
                int firstSurah = juzData.keys.first;
                int firstAyah = juzData[firstSurah]![0];
                String verse = getVerse(firstSurah, firstAyah, verseEndSymbol: false);

                return Card(
                  child: ListTile(
                    onTap: (){
                      Navigator.pop(context);
                      onJuzSelected(getPageNumber(firstSurah, firstAyah));
                    },
                    leading: Text(getVerseEndSymbol(index+1), style: Theme.of(context).textTheme.titleMedium, textScaler: TextScaler.linear(1.2),),
                    title: Text(verse, overflow: TextOverflow.ellipsis, maxLines: 1, style: GoogleFonts.lateef(
                      textStyle: const TextStyle(
                          letterSpacing: .5,
                          fontWeight: FontWeight.bold),
                    ),),
                    subtitle: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Juz ${index+1}"),
                        Text("Surah $firstSurah | Ayah $firstAyah")
                      ],
                    ),
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
