import 'dart:convert';

class JourneyAlarm {
  final String id;
  final String journeyId;
  final String journeyTitle;
  final int hour;
  final int minute;
  // DateTime weekday values: 1=Monday … 7=Sunday. Empty list = every day.
  final List<int> days;
  final bool enabled;

  const JourneyAlarm({
    required this.id,
    required this.journeyId,
    required this.journeyTitle,
    required this.hour,
    required this.minute,
    required this.days,
    this.enabled = true,
  });

  JourneyAlarm copyWith({bool? enabled, List<int>? days}) => JourneyAlarm(
        id: id,
        journeyId: journeyId,
        journeyTitle: journeyTitle,
        hour: hour,
        minute: minute,
        days: days ?? this.days,
        enabled: enabled ?? this.enabled,
      );

  /// "08:30"
  String get timeLabel {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// "Mon, Wed, Fri" / "Weekdays" / "Every day" / …
  String get daysLabel {
    if (days.isEmpty || days.length == 7) return 'Every day';
    final set = days.toSet();
    if (set.containsAll({1, 2, 3, 4, 5}) && days.length == 5) return 'Weekdays';
    if (set.containsAll({6, 7}) && days.length == 2) return 'Weekends';
    const names = {
      1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu',
      5: 'Fri', 6: 'Sat', 7: 'Sun',
    };
    final sorted = [...days]..sort();
    return sorted.map((d) => names[d]!).join(', ');
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'journeyId': journeyId,
        'journeyTitle': journeyTitle,
        'hour': hour,
        'minute': minute,
        'days': days,
        'enabled': enabled,
      };

  String toJson() => jsonEncode(toMap());

  static JourneyAlarm fromMap(Map<String, dynamic> map) => JourneyAlarm(
        id: map['id'] as String,
        journeyId: map['journeyId'] as String,
        journeyTitle: map['journeyTitle'] as String,
        hour: map['hour'] as int,
        minute: map['minute'] as int,
        days: List<int>.from(map['days'] as List),
        enabled: map['enabled'] as bool? ?? true,
      );

  static List<JourneyAlarm> fromJsonArray(String raw) {
    if (raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((m) => JourneyAlarm.fromMap(m as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static String toJsonArray(List<JourneyAlarm> list) =>
      jsonEncode(list.map((a) => a.toMap()).toList());
}
