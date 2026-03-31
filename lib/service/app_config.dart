import 'package:hive/hive.dart';
import 'package:tahfeex/service/services.dart';

class AppConfig {

  static final AppConfig _instance = AppConfig._internal();
  factory AppConfig() => _instance;

  AppConfig._internal();

  String? appStoreBoxPath;

  static Future<void> configure(String appStoreBoxPath, {bool initialiseHive = true}) async {
    AppConfig config = AppConfig();
    config.appStoreBoxPath = appStoreBoxPath;
    if (initialiseHive) {
      // Single Hive.init call before opening individual boxes (BUG-11).
      Hive.init(appStoreBoxPath);
      AppStorage storage = AppStorage();
      AppSettings settings = AppSettings();
      await Future.wait([storage.initHive(), settings.initHive()]);
    }
  }

}