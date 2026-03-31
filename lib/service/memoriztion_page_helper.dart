// import 'dart:async';
//
// import 'package:another_transformer_page_view/another_transformer_page_view.dart';
// import 'package:file_picker/file_picker.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:quran/quran.dart';
// import 'package:tahfeex/model/models.dart';
// import 'package:tahfeex/screens/screens.dart';
// import 'package:tahfeex/service/services.dart';
// import 'package:tahfeex/service/states/states.dart';
// import 'package:tahfeex/utils/my_audio_player.dart';
// import 'package:tahfeex/utils/utils.dart';
// import 'package:tahfeex/widgets/widgets.dart';
//
// class MemorizationScreen extends StatefulWidget {
//   const MemorizationScreen({super.key});
//
//   @override
//   State<MemorizationScreen> createState() => _MemorizationScreenState();
// }
//
// class _MemorizationScreenState extends State<MemorizationScreen> {
//   static const int totalPages = 604;
//
//   int page = 1;
//   int ayah = 1;
//   int juzNumber = 0;
//   int ayahFrom = -1;
//   int surahFrom = -1;
//   int ayahTo = -1;
//   int surahTo = -1;
//
//   int repeatTimes = 2;
//   int currentRepeat=1;
//   bool isRepeating=false;
//   int totalVersesInSurah=0;
//
//   String surahLabel = "";
//   bool showPageNumbers = false;
//   bool showControls = true;
//   bool settingAyahFrom = false;
//   bool settingAyahTo = false;
//   double? controlPosition;
//   SurahAudio? surahAudio;
//   int surahNumber = 1;
//
//   late MyAudioPlayer audioPlayer;
//
//   Function()? setSurahNumber;
//
//   @override
//   void initState() {
//     super.initState();
//     audioPlayer = MyAudioPlayer(setState, durationUpdate:onDurationUpdated);
//
//     setSurahLabel(page);
//     loadSurahAudio(surahNumber);
//   }
//
//   @override
//   void dispose() {
//     super.dispose();
//   }
//
//   @override
//   void deactivate() {
//     audioPlayer.stop(isMounted: () => mounted);
//     super.deactivate();
//   }
//
//   Timer? canceller;
//   void debouncer(Duration delay,Function fn) {
//     if (canceller?.isActive ?? false) canceller?.cancel();
//     canceller = Timer(delay, () {
//       fn();
//     });
//   }
//
//   void onDurationUpdated(Duration position){
//     if(isRepeating) return;
//     if(surahAudio!=null ){
//
//       if(ayah <= surahAudio!.totalAyahs && surahAudio!.ayahs.isNotEmpty && ayah <= surahAudio!.ayahs.length){
//         final currentAyahEnding = surahAudio!.ayahs[ayah-1].endAt;
//         // print("${position.inSeconds} | $currentAyahEnding");
//         if(position.inSeconds >= currentAyahEnding){
//           if(isRepeating) return;
//
//           setState(() {
//             ayah++;
//           });
//           print("NEW AYAH $ayah");
//
//
//           if(surahNumber == surahTo && ayah-1==ayahTo){
//             repeatCycle();
//           }else if(surahTo != surahNumber && ayah-1 == totalVersesInSurah){
//             print("Reached end of surah, should move to next");
//             changeSurah(surahNumber+1);
//
//           }
//
//           if(ayah <=surahAudio!.totalAyahs) {
//             checkPageBasedOnAyah();
//           }
//         }
//       }else{
//         print("Unable to figure out next ayah in playback");
//
//       }
//
//     }
//   }
//
//   void checkPageBasedOnAyah(){
//     int pageNumber = getPageNumber(surahNumber, ayah);
//     if(pageNumber != page){
//       controller.move(totalPages-pageNumber);
//     }
//   }
//
//   void repeatCycle(){
//     print("Repeating");
//     if(currentRepeat == repeatTimes){
//       audioPlayer.pause();
//       currentRepeat = 1;
//       print("Playback ended due to finished repeats");
//       return;
//     }
//     isRepeating =true;
//     currentRepeat++;
//     audioPlayer.pause();
//     var pageNumber = getPageNumber(surahFrom, ayahFrom);
//     if(pageNumber != page){
//       controller.move(totalPages - pageNumber);
//     }
//     startPlayback();
//
//   }
//
//   void setSurahLabel(int page) {
//     var surah = getPageData(page).first;
//     surahNumber = surah['surah'];
//     if(setSurahNumber !=null){
//       setSurahNumber?.call();
//       setSurahNumber=null;
//     }
//     setState(() {
//       surahLabel = getSurahName(surahNumber);
//       juzNumber = getJuzNumber(surahNumber, surah['start']);
//       if (ayahFrom == -1) {
//         ayahFrom = surah['start'];
//       }
//       if (ayahTo == -1) {
//         ayahTo = getVerseCount(surahNumber);
//       }
//       if(surahFrom == -1){
//         surahFrom = surahNumber;
//       }
//       if(surahTo == -1){
//         surahTo = surahNumber;
//       }
//       // totalVersesInSurah=surah['end'];
//     });
//     if (surahAudio == null || surahAudio?.surahNumber != surahNumber) {
//       changeSurah(surahNumber, setPlaybackPoints: true);
//
//     }else{
//       // if(isRepeating){
//       //   startPlayback(load:false);
//       // }
//     }
//   }
//
//   changeSurah(int newSurah, {bool setPlaybackPoints=false}){
//     if(audioPlayer.playing)audioPlayer.stop(isMounted: ()=>mounted);
//     setState(() {
//       totalVersesInSurah=getVerseCount(newSurah);
//       surahNumber = newSurah;
//       if(setPlaybackPoints){
//         ayahFrom = 1;
//         ayah = ayahFrom;
//         ayahTo = totalVersesInSurah;
//         surahFrom = surahNumber;
//         surahTo = surahNumber;
//       }
//
//     });
//     loadSurahAudio(surahNumber);
//   }
//
//   void loadSurahAudio(int surahNumber) {
//     print("loading new surah audio $surahNumber");
//     // if(audioPlayer.playing){
//     audioPlayer.stop(isMounted: ()=>mounted);
//     // }
//     AppStorage storage = AppStorage();
//     String surahsString = storage.getAudioSurahs(surahNumber);
//     List<SurahAudio> files = SurahAudio.fromJsonArray(surahsString);
//     if (files.isNotEmpty) {
//       surahAudio = files.first;
//     } else {
//       surahAudio = null;
//     }
//     if (mounted) {
//       setState(() {});
//     }
//     if(isRepeating && surahAudio!=null){
//       startPlayback();
//     }
//   }
//
//   void startPlayback({bool load=true}){
//     if(isRepeating){
//       setState(() {
//         ayah = ayahFrom;
//       });
//       print("Ayah is now $ayah");
//     }
//     if(load){
//       audioPlayer.play(
//           surahAudio!.localFileUrl ??
//               surahAudio!.remoteFileUrl ??
//               '',
//           startFrom: surahAudio!
//               .ayahs.isNotEmpty &&
//               ayah <=
//                   surahAudio!.ayahs.length
//               ? surahAudio!
//               .ayahs[ayah-1].startFrom
//               : 0);
//       // print("here");
//     }else{
//       audioPlayer.seekTo(surahAudio!
//           .ayahs.isNotEmpty &&
//           ayah <=
//               surahAudio!.ayahs.length
//           ? surahAudio!
//           .ayahs[ayah-1].startFrom
//           : 0);
//       audioPlayer.resume();
//     }
//     debouncer(const Duration(milliseconds: 500), ()=>isRepeating=false);
//   }
//
//   void addNewFile() async {
//     FilePickerResult? result = await FilePicker.platform.pickFiles();
//     if (result != null && result.files.single.path != null) {
//       if (context.mounted) {
//         Navigator.push(
//             context,
//             MaterialPageRoute(
//                 builder: (ct) => NewAudio(surahNumber, result.files.single,
//                     onSurahAdd: (surahAudio) {
//                       if (context.mounted) {
//                         AppStorage storage = AppStorage();
//                         storage.setAudioSurahs(
//                             surahNumber, SurahAudio.toJsonArray([surahAudio]));
//                       }
//                       // print("Case 3");
//                       loadSurahAudio(surahNumber);
//                     })));
//       }
//     }
//   }
//
//   IndexController controller = IndexController();
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//         body: SafeArea(
//           child: Stack(
//             children: [
//               Container(
//                 padding: const EdgeInsets.all(10),
//                 child: Column(
//                   children: [
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         IconButton(
//                           onPressed: () => Navigator.pop(context),
//                           icon: const Icon(Icons.arrow_back_ios),
//                         ),
//                         TextButton(
//                           onPressed: () {
//                             AlertUtls.showModal(context,
//                                 SurahSelector(onSurahSelected: (int surahNumber) {
//                                   setSurahNumber = (){
//                                     setState((){
//                                       this.surahNumber = surahNumber;
//                                       ayahFrom = 1;
//                                       ayah = ayahFrom;
//                                       ayahTo = getVerseCount(surahNumber);
//                                     });
//                                   };
//                                   var surahFirstPage = getSurahPages(surahNumber).first;
//                                   controller.move(totalPages - surahFirstPage);
//                                 }));
//                           },
//                           child: Text(
//                             surahLabel,
//                             style: GoogleFonts.lateef(
//                               textStyle: const TextStyle(
//                                   color: Colors.green,
//                                   letterSpacing: .5,
//                                   fontSize: 20,
//                                   fontWeight: FontWeight.bold),
//                             ),
//                           ),
//                         ),
//                         TextButton(
//                           onPressed: () {
//                             AlertUtls.showModal(context,
//                                 JuzSelector(onJuzSelected: (int page) {
//                                   controller.move(totalPages - page);
//                                 }));
//                           },
//                           child: Text(
//                             'Juz $juzNumber',
//                             style: GoogleFonts.lateef(
//                               textStyle: const TextStyle(
//                                   color: Colors.green,
//                                   letterSpacing: .5,
//                                   fontSize: 20,
//                                   fontWeight: FontWeight.bold),
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                     Expanded(
//                       child: TransformerPageView(
//                           loop: false,
//                           index: totalPages - page,
//                           controller: controller,
//                           itemCount: totalPages,
//                           onPageChanged: (int? currentPage) {
//                             debouncer(const Duration(milliseconds: 500), (){
//                               if(currentPage == null)return;
//                               int id = totalPages - currentPage ;
//                               setState(() {
//                                 page = id;
//                               });
//                               setSurahLabel(id);
//                             });
//
//                           },
//                           itemBuilder: (BuildContext context, int index) {
//                             int id =
//                                 totalPages - index; // Reverse the order of pages
//                             return SingleChildScrollView(
//                               child: ArabicPageViewer(
//                                 page: id,
//                                 ayah: ayah,
//                                 surah:surahNumber,
//                                 ayahColor:(int ayahNumber, int surahNumber){
//                                   if(ayahNumber == ayahFrom && surahNumber==surahFrom){
//                                     return Colors.orange;
//                                   }else if(ayahNumber==ayahTo && surahNumber == surahTo){
//                                     return Colors.red;
//                                   }else{
//                                     return null;
//                                   }
//                                 },
//                                 onBackgroundClick:(){
//                                   setState(() {
//                                     settingAyahFrom = false;
//                                     settingAyahTo = false;
//                                   });
//                                 },
//                                 onAyahClicked: (int a, int surah) {
//                                   audioPlayer.pause();
//                                   setState(() {
//                                     if (settingAyahFrom) {
//                                       ayahFrom = a;
//                                       ayah = ayahFrom;
//                                       surahFrom =surah;
//                                       settingAyahFrom = false;
//
//                                       if(surah ==surahNumber ){
//                                         // ayah = ayahFrom;
//                                         print("seek to ayah");
//                                         if(surahAudio!=null){
//                                           audioPlayer.seekTo(surahAudio!.ayahs[ayahFrom-1].startFrom);
//                                         }
//                                       }else{
//                                         if(surahFrom < surahTo){
//                                           //fine
//                                           print("Lets reload an audio");
//                                         }else if(surahFrom > surahTo){
//                                           ayahTo = getVerseCount(surahFrom);
//                                           surahTo = surahFrom;
//                                         }else{
//                                           if(ayahFrom < ayahTo){
//                                             ayahTo=ayahFrom;
//                                           }
//                                         }
//                                         changeSurah(surah);
//                                       }
//
//
//
//                                     } else if (settingAyahTo) {
//                                       if (surah == surahNumber && a < ayahFrom) {
//                                         ayahTo = ayahFrom;
//                                         surahTo = surahFrom;
//                                         AlertUtls.toast(context,
//                                             message:
//                                             "Ending verse shouldn't be before starting verse");
//                                       } else if (surah < surahNumber) {
//                                         ayahTo = ayahFrom;
//                                         surahTo = surahFrom;
//                                         AlertUtls.toast(context,
//                                             message:
//                                             "Ending verse shouldn't be before starting verse");
//                                       } else {
//                                         ayahTo = a;
//                                         surahTo = surah;
//                                         settingAyahTo = false;
//                                       }
//                                     } else {
//                                       settingAyahFrom = false;
//                                     }
//                                   });
//                                 },
//                               ),
//                             );
//                           }),
//                     ),
//                     if (showPageNumbers)
//                       PageButton(page, (chosenPage) {
//                         controller.move(totalPages - chosenPage);
//                         setState(() {
//                           showPageNumbers = !showPageNumbers;
//                         });
//                       }),
//                     if (!showPageNumbers)
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           IconButton(
//                               onPressed: () => setState(() {
//                                 showPageNumbers = !showPageNumbers;
//                               }),
//                               icon: Text(
//                                 getVerseEndSymbol(page),
//                                 style: Theme.of(context)
//                                     .textTheme
//                                     .titleLarge
//                                     ?.copyWith(
//                                     fontWeight: FontWeight.bold,
//                                     color: Colors.green),
//                               )),
//                         ],
//                       )
//                   ],
//                 ),
//               ),
//               Positioned(
//                   bottom: controlPosition ?? 60,
//                   width: MediaQuery.of(context).size.width - 10,
//                   child: _buildControls()),
//             ],
//           ),
//         ));
//   }
//
//   Widget _buildControls() {
//     var screenHeight = MediaQuery.of(context).size.height;
//     return Align(
//       alignment: Alignment.bottomCenter,
//       child: GestureDetector(
//         onVerticalDragUpdate: (details) {
//           setState(() {
//             controlPosition = screenHeight - details.globalPosition.dy;
//           });
//         },
//         child: Container(
//           // width: MediaQuery.of(context).size.width * .8,
//           child: Column(
//             children: [
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   AppIconButton(
//                     icon:
//                     showControls ? Icons.visibility : Icons.visibility_off,
//                     iconSize: 17,
//                     onPressed: () {
//                       setState(() {
//                         showControls = !showControls;
//                       });
//                     },
//                   ),
//                   if (showControls)
//                     Container(
//                       decoration: BoxDecoration(
//                           color: Colors.white,
//                           borderRadius:
//                           const BorderRadius.all(Radius.circular(30)),
//                           boxShadow: [
//                             BoxShadow(
//                               color: Colors.grey[300]!,
//                               spreadRadius: 1,
//                               blurRadius: 10,
//                             )
//                           ]),
//                       child: Row(
//                         mainAxisSize: MainAxisSize.max,
//                         children: [
//                           IconButton(
//                               onPressed: () {
//                                 setState(() {
//                                   settingAyahFrom = true;
//                                   settingAyahTo = false;
//                                 });
//                               },
//                               icon: Text(
//                                 settingAyahFrom
//                                     ? "_"
//                                     : getVerseEndSymbol(ayahFrom),
//                                 textScaleFactor: 1.5,
//                                 style: TextStyle(
//                                     color: settingAyahFrom
//                                         ? Colors.green
//                                         : Colors.black),
//                               )),
//                           Stack(
//                             alignment: Alignment.center,
//                             children: [
//                               AppIconButton(
//                                 onPressed: () {
//                                   if (surahAudio == null) {
//                                     addNewFile();
//                                   } else if (audioPlayer.playing) {
//                                     audioPlayer.pause();
//                                   } else {
//                                     if (audioPlayer.initialisedPlayback) {
//                                       audioPlayer.resume();
//                                     } else {
//                                       startPlayback();
//                                     }
//                                   }
//                                 },
//                                 icon: surahAudio == null
//                                     ? Icons.music_note_outlined
//                                     : (audioPlayer.playing
//                                     ? Icons.pause
//                                     : Icons.play_arrow),
//                                 iconColor: surahAudio == null
//                                     ? Colors.orange
//                                     : Colors.green[900],
//                                 backgroundColor: surahAudio == null
//                                     ? Colors.white
//                                     : Colors.green[100],
//                               ),
//                               if (surahAudio != null &&
//                                   surahAudio?.ayahs.length !=
//                                       surahAudio?.totalAyahs)
//                                 const Positioned(
//                                     left: 20,
//                                     top: 10,
//                                     child: CircleAvatar(
//                                       backgroundColor: Colors.orange,
//                                       radius: 5,
//                                     ))
//                             ],
//                           ),
//                           IconButton(
//                               onPressed: () {
//                                 setState(() {
//                                   settingAyahFrom = false;
//                                   settingAyahTo = true;
//                                 });
//                               },
//                               icon: Text(
//                                 settingAyahTo ? "_" : getVerseEndSymbol(ayahTo),
//                                 textScaleFactor: 1.5,
//                                 style: TextStyle(
//                                     color: settingAyahTo
//                                         ? Colors.green
//                                         : Colors.black),
//                               )),
//                         ],
//                       ),
//                     ),
//                   if (showControls)Text(surahAudio?.surahNameEnglish??'N/A')
//                   // AppIconButton(
//                   //   icon: Icons.more_horiz,
//                   //   iconSize: 17,
//                   //   onPressed: () {},
//                   // ),
//                 ],
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
//
// class ArabicPageViewer extends StatelessWidget {
//   final int page;
//   final int ayah;
//   final int surah;
//   final Function(int, int)? onAyahClicked;
//   final Function()? onBackgroundClick;
//   final Color? Function(int,int)? ayahColor;
//   const ArabicPageViewer(
//       {super.key, this.page = 1, this.ayah = 1, required this.surah,this.onAyahClicked, this.ayahColor, this.onBackgroundClick});
//
//   @override
//   Widget build(BuildContext context) {
//     List pageData = getPageData(page);
//     Map<int, List<Ayah>> surahs = {};
//
//     for (var surah in pageData) {
//       int startAyah = surah['start'];
//       int endAyah = surah['end'];
//       int surahNumber = surah['surah'];
//
//       for (int i = startAyah; i <= endAyah; i++) {
//         var ayah = Ayah(
//             surahNumber: surahNumber,
//             surahName: getSurahName(surahNumber),
//             ayahNumber: i,
//             totalAyahInSurah: getVerseCount(surahNumber),
//             ayahContent: getVerse(surahNumber, i, verseEndSymbol: false));
//         surahs[surahNumber] = surahs[surahNumber] ?? [];
//         surahs[surahNumber]?.add(ayah);
//       }
//     }
//
//     List<int> surahNumbers= surahs.keys.toList();
//     return GestureDetector(
//       onTap: onBackgroundClick,
//       child: Container(
//           height: MediaQuery.of(context).size.height-100,
//           padding: const EdgeInsets.all(15),
//           child: ListView.builder(
//               itemCount: surahNumbers.length,
//               itemBuilder: (context, index){
//                 return buildSurahText(context, surahs[surahNumbers[index]]!);
//               })),
//     );
//   }
//
//   Widget buildSurahText(BuildContext context, List<Ayah> verses){
//     return Column(
//       children: [
//         if(verses[0].ayahNumber==1 && verses[0].surahNumber !=1)Padding(padding: const EdgeInsets.symmetric(vertical:5),
//             child: Text(
//                 getVerse(1, 1),
//                 style: ArabicAyahViewer.ayahTextStyle.copyWith(color:Colors.yellow[700], fontSize: 20))
//         ),
//         Padding(
//           padding: const EdgeInsets.symmetric(vertical: 5),
//           child: RichText(
//               textAlign: TextAlign.justify,
//               text: TextSpan(
//                   children: List.generate(
//                     verses.length,
//                         (index) {
//                       TapAndPanGestureRecognizer recognizer =
//                       TapAndPanGestureRecognizer();
//                       if (onAyahClicked != null) {
//                         recognizer.onTapUp = (details) => onAyahClicked!(
//                             verses[index].ayahNumber!, verses[index].surahNumber!);
//                       }
//
//                       return TextSpan(recognizer: null, children: [
//                         TextSpan(
//                             recognizer: recognizer,
//                             text: " ${verses[index].ayahContent} ",
//                             style: ArabicAyahViewer.ayahTextStyle.copyWith(
//                                 color: verses[index].ayahNumber == ayah && verses[index].surahNumber== surah
//                                     ? Colors.black
//                                     : Colors.grey,
//                                 fontSize: 20)),
//                         TextSpan(
//                             recognizer: recognizer,
//                             text: getVerseEndSymbol(verses[index].ayahNumber!),
//                             style: Theme.of(context).textTheme.titleMedium?.copyWith(
//                                 color: ayahColor ==null ? Colors.green : ayahColor?.call(verses[index].ayahNumber!, verses[index].surahNumber!) ?? Colors.green, fontWeight: FontWeight.bold))
//                       ]);
//                     },
//                   ))),
//         ),
//       ],
//     );
//   }
//
// }
//
// class ArabicAyahViewer extends TextSpan {
//   final Ayah ayah;
//   const ArabicAyahViewer(this.ayah);
//
//   static TextStyle ayahTextStyle = GoogleFonts.lateef(
//     textStyle: const TextStyle(
//       color: Colors.green,
//       fontSize: 20,
//     ),
//   );
//
//   @override
//   Widget build(ParagraphBuilder,
//       {List<PlaceholderDimensions>? dimensions, double? textScaleFactor}) {
//     return Text(ayah.ayahContent ?? "Unable to load verse",
//         style: ayahTextStyle);
//   }
// }
