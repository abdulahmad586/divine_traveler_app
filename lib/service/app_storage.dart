import 'package:hive/hive.dart';
import 'package:tahfeex/service/services.dart';

class AppStorage {

  static const boxName = "appStore";

  static final AppStorage _instance = AppStorage._internal();
  factory AppStorage() => _instance;

  AppStorage._internal();

  Box? box;
  bool initialisedHive = false;

  int get currentPage => box?.get("currentPage", defaultValue: 1) ?? 1;
  set currentPage(int page) => box?.put("currentPage", page);

  int get currentVerse => box?.get("currentVerse", defaultValue: 1) ?? 1;
  set currentVerse(int verse) => box?.put("currentVerse", verse);

  String getAudioSurahs(int surahNumber){
    return box?.get("$surahNumber-audioSurahs", defaultValue: '') ?? '';
  }

  void setAudioSurahs(int surahNumber, String audioSurahs){
    box?.put("$surahNumber-audioSurahs", audioSurahs);
  }

  Set<String> get likedContributionIds {
    final raw = box?.get('likedContributions', defaultValue: <String>[]);
    if (raw is List) return raw.cast<String>().toSet();
    return {};
  }

  void addLikedContributionId(String id) {
    final ids = likedContributionIds..add(id);
    box?.put('likedContributions', ids.toList());
  }

  String getAlarms(String journeyId) =>
      box?.get('alarms-$journeyId', defaultValue: '') ?? '';

  void setAlarms(String journeyId, String json) =>
      box?.put('alarms-$journeyId', json);

  Future<void> initHive() async {
    AppConfig config= AppConfig();
    if (config.appStoreBoxPath == null) {
      throw Exception(
          "Storage box path not set, please use AppConfig to set this value");
    }

    if (!initialisedHive) {
      await Hive.openBox(boxName);
      box = Hive.box(boxName);
      initialisedHive = true;
      print("App storage initialised");
    }
  }


}