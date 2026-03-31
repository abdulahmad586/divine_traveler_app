import 'package:hive/hive.dart';
import 'package:tahfeex/service/services.dart';

class AppSettings {

  static const boxName = "appSettings";

  static final AppSettings _instance = AppSettings._internal();
  factory AppSettings() => _instance;

  AppSettings._internal();

  Box? box;
  bool initialisedHive = false;

  // BUG-10: added ?? 14 fallback so the getter always returns a non-null int
  // even when box is not yet initialised.
  int get arabicTextSize => box?.get("arabicTextSize", defaultValue: 14) ?? 14;
  set arabicTextSize(int arabicTextSize) => box?.put("arabicTextSize", arabicTextSize);

  int get englishTextSize => box?.get("englishTextSize", defaultValue: 14) ?? 14;
  // BUG-10: parameter was misnamed arabicTextSize — fixed to englishTextSize.
  set englishTextSize(int englishTextSize) => box?.put("englishTextSize", englishTextSize);

  bool get hasSeenTrainInstructions =>
      box?.get("hasSeenTrainInstructions", defaultValue: false) ?? false;
  set hasSeenTrainInstructions(bool val) =>
      box?.put("hasSeenTrainInstructions", val);

  Future<void> initHive() async {
    AppConfig config = AppConfig();
    if (config.appStoreBoxPath == null) {
      throw Exception(
          "Storage box path not set, please use AppConfig to set this value");
    }

    if (!initialisedHive) {
      // BUG-11: Hive.init() is now called once in AppConfig.configure() before
      // this method runs. Calling it again here would race with AppStorage.initHive()
      // when both are awaited concurrently via Future.wait.
      await Hive.openBox(boxName);
      box = Hive.box(boxName);
      initialisedHive = true;
      print("App settings initialised");
    }
  }

}
