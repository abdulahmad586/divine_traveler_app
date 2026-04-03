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

  Map<String, dynamic>? getTafsirCache(String key) {
    final raw = box?.get('tafsir_$key');
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  void setTafsirCache(String key, Map<String, dynamic> data) {
    box?.put('tafsir_$key', data);
  }

  // ── Profile cache ────────────────────────────────────────────────────────

  Map<dynamic, dynamic>? getProfileCache() {
    final raw = box?.get('profile');
    if (raw is Map) return raw;
    return null;
  }

  void setProfileCache(Map<String, dynamic> data) {
    box?.put('profile', data);
  }

  // ── Companions cache ──────────────────────────────────────────────────────

  List<Map<dynamic, dynamic>>? getCompanionsCache() {
    final raw = box?.get('companions');
    if (raw is! List) return null;
    return raw.map((e) => e as Map<dynamic, dynamic>).toList();
  }

  void setCompanionsCache(List<Map<String, dynamic>> data) {
    box?.put('companions', data);
  }

  List<Map<dynamic, dynamic>>? getIncomingRequestsCache() {
    final raw = box?.get('incoming_requests');
    if (raw is! List) return null;
    return raw.map((e) => e as Map<dynamic, dynamic>).toList();
  }

  void setIncomingRequestsCache(List<Map<String, dynamic>> data) {
    box?.put('incoming_requests', data);
  }

  // ── Daily journey progress ───────────────────────────────────────────────

  /// Number of ayahs marked complete today for [journeyId].
  /// Automatically returns 0 for any day other than today.
  int getTodayJourneyCount(String journeyId) {
    final key = 'daily_${journeyId}_${_todayKey()}';
    return box?.get(key, defaultValue: 0) ?? 0;
  }

  /// Increments today's count by 1 and returns the new value.
  int incrementTodayJourneyCount(String journeyId) {
    final key = 'daily_${journeyId}_${_todayKey()}';
    final next = (box?.get(key, defaultValue: 0) ?? 0) + 1;
    box?.put(key, next);
    return next;
  }

  String _todayKey() {
    final n = DateTime.now();
    return '${n.year}${n.month.toString().padLeft(2, '0')}${n.day.toString().padLeft(2, '0')}';
  }

  // ── Journey cache ────────────────────────────────────────────────────────

  List<Map<dynamic, dynamic>>? getJourneyListCache() {
    final raw = box?.get('journey_list');
    if (raw is! List) return null;
    return raw.map((e) => e as Map<dynamic, dynamic>).toList();
  }

  void setJourneyListCache(List<Map<String, dynamic>> data) {
    box?.put('journey_list', data);
  }

  Map<dynamic, dynamic>? getJourneyCache(String id) {
    final raw = box?.get('journey_$id');
    if (raw is Map) return raw;
    return null;
  }

  void setJourneyCache(Map<String, dynamic> data) {
    box?.put('journey_${data['id']}', data);
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