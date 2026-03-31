import 'package:flutter/material.dart';
import 'package:quran/quran.dart';
import 'package:tahfeex/screens/screens.dart';

class AudioSurahScreen extends StatelessWidget {
  static String routeId="audio-surah-screen";

  const AudioSurahScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Qur'an Player"),
      ),
      body: Container(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            const Text("Browse the surah you wish to listen to"),
            Expanded(
                child: ListView.builder(
                    itemCount: totalSurahCount,
                    itemBuilder: (c, index){
                  return AudioSurahListItem(index+1, onTap: (){
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => AudioFilesScreen(surahNumber: index+1)));
                  },);
                })
            ),
          ],
        ),
      ),
    );
  }
}

class AudioSurahListItem extends StatelessWidget{

  final int surahNumber;
  final VoidCallback? onTap;

  const AudioSurahListItem( this.surahNumber, {super.key, this.onTap});


  @override
  Widget build(BuildContext context) {
    final surahName = getSurahName(surahNumber);
    final surahNameArabic = getSurahNameArabic(surahNumber);

    return ListTile(
      leading: Text(getVerseEndSymbol(surahNumber),style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.green),),
      title: Text(surahNameArabic),
      subtitle: Text(surahName),
      onTap: onTap,
    );
  }

}
