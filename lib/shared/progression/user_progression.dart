import 'package:tahfeex/service/app_storage.dart';

/// Tracks local unlock state for the progressive disclosure system.
/// Backed by the existing Hive key-value box — no code generation needed.
///
/// Gates (from revamp_plan.md §4.2):
///   • [hasCompletedFirstAyah] → page-context mode in study screen
///   • [hasShownConsistency]   → companions on home, group journeys
///   • [hasCompletedJourney]   → contributions section, custom journey creation
class UserProgression {
  static const _keyFirstAyah        = 'prog_firstAyah';
  static const _keyJourneyStarted   = 'prog_journeyStarted';
  static const _keyJourneyCompleted = 'prog_journeyCompleted';
  static const _keyActivityDays     = 'prog_activityDays';

  static final UserProgression _instance = UserProgression._internal();
  factory UserProgression() => _instance;
  UserProgression._internal();

  AppStorage get _s => AppStorage();

  // ── Flags ──────────────────────────────────────────────────────────────────

  bool get hasStartedJourney =>
      _s.box?.get(_keyJourneyStarted, defaultValue: false) ?? false;

  void setJourneyStarted() => _s.box?.put(_keyJourneyStarted, true);

  bool get hasCompletedFirstAyah =>
      _s.box?.get(_keyFirstAyah, defaultValue: false) ?? false;

  void setFirstAyahCompleted() => _s.box?.put(_keyFirstAyah, true);

  bool get hasCompletedJourney =>
      _s.box?.get(_keyJourneyCompleted, defaultValue: false) ?? false;

  void setJourneyCompleted() => _s.box?.put(_keyJourneyCompleted, true);

  // ── Activity tracking ──────────────────────────────────────────────────────

  /// Returns the set of ISO-date strings (e.g. "2026-03-31") on which the
  /// user marked at least one ayah complete.
  Set<String> get activityDays {
    final raw = _s.box?.get(_keyActivityDays, defaultValue: <String>[]);
    if (raw is List) return raw.cast<String>().toSet();
    return {};
  }

  /// Call whenever the user marks an ayah complete. Records today's date and
  /// updates [hasCompletedFirstAyah].
  void recordActivity() {
    setFirstAyahCompleted();
    final today = _today;
    final days  = activityDays..add(today);
    _s.box?.put(_keyActivityDays, days.toList());
  }

  /// True once the user has had activity on 3 or more distinct calendar days.
  bool get hasShownConsistency => activityDays.length >= 3;

  // ── Helpers ────────────────────────────────────────────────────────────────

  String get _today => DateTime.now().toIso8601String().substring(0, 10);
}
