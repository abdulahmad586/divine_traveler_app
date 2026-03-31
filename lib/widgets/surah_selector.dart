import 'package:flutter/material.dart';
import 'package:quran/quran.dart';

class SurahSelector extends StatelessWidget {
  final Function(int) onSurahSelected;
  const SurahSelector({super.key, required this.onSurahSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      height: 500,
      child: Column(
        children: [
          const SizedBox(height: 10,),
          Text("SELECT SURAH", style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.green, fontWeight: FontWeight.bold),),
          const SizedBox(height: 10,),
          Expanded(
            child: ListView.builder(
              itemCount: totalSurahCount,
              itemBuilder: (context, index) {
                return Card(
                  child: ListTile(
                    onTap: (){
                      Navigator.pop(context);
                      onSurahSelected(index+1);
                    },
                    leading: Text(getVerseEndSymbol(index+1), style: Theme.of(context).textTheme.titleMedium, textScaler: TextScaler.linear(1.2),),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                      Text(getSurahName(index+1)),
                      Text(getSurahNameArabic(index+1))
                    ],),
                    subtitle: Text("${getVerseCount(index+1)} verses"),
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
