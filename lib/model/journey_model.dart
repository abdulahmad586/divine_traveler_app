/// Ayah counts per surah (index 0 unused; index 1 = Al-Fatiha = 7, etc.)
const List<int> ayahCounts = [
  0,   // unused
  7, 286, 200, 176, 120, 165, 206, 75, 129, 109,   // 1–10
  123, 111, 43, 52, 99, 128, 111, 110, 98, 135,    // 11–20
  112, 78, 118, 64, 77, 227, 93, 88, 69, 60,       // 21–30
  34, 30, 73, 54, 45, 83, 182, 88, 75, 85,         // 31–40
  54, 53, 89, 59, 37, 35, 38, 29, 18, 45,          // 41–50
  60, 49, 62, 55, 78, 96, 29, 22, 24, 13,          // 51–60
  14, 11, 11, 18, 12, 12, 30, 52, 52, 44,          // 61–70
  28, 28, 20, 56, 40, 31, 50, 40, 46, 42,          // 71–80
  29, 19, 36, 25, 22, 17, 19, 26, 30, 20,          // 81–90
  15, 21, 11, 8, 8, 19, 5, 8, 8, 11,               // 91–100
  11, 8, 3, 9, 5, 4, 7, 3, 6, 3, 5, 4, 5, 6,      // 101–114
];

/// Converts a surah+ayah pair to a monotonically increasing integer for
/// range comparisons.
int journeyLinearIndex(int surah, int ayah) {
  int index = 0;
  for (int s = 1; s < surah; s++) {
    index += ayahCounts[s];
  }
  return index + ayah;
}

DateTime _parseTs(dynamic raw) {
  if (raw == null) return DateTime.now();
  if (raw is Map) {
    final s = raw['_seconds'] as int? ?? 0;
    return DateTime.fromMillisecondsSinceEpoch(s * 1000);
  }
  if (raw is String) return DateTime.tryParse(raw) ?? DateTime.now();
  return DateTime.now();
}

// ─────────────────────────────────────────────────────────────────────────────
// JourneyMember — per-person progress and status
// ─────────────────────────────────────────────────────────────────────────────

class JourneyMember {
  final String userId;
  final String name;
  final String username;
  final String status;
  final Map<String, bool> completedAyahs;
  final int completedCount;
  final DateTime joinedAt;
  final DateTime updatedAt;

  const JourneyMember({
    required this.userId,
    required this.name,
    required this.username,
    required this.status,
    required this.completedAyahs,
    required this.completedCount,
    required this.joinedAt,
    required this.updatedAt,
  });

  bool get isActive    => status == 'active';
  bool get isPaused    => status == 'paused';
  bool get isDelayed   => status == 'delayed';
  bool get isCompleted => status == 'completed';
  bool get isAbandoned => status == 'abandoned';
  bool get isActionable => !isCompleted && !isAbandoned;

  bool isAyahDone(int surah, int ayah) =>
      completedAyahs['${surah}_$ayah'] == true;

  /// Returns a copy of this member with [extra] keys (`'surah_ayah'` format)
  /// overlaid as completed. Used for optimistic local progress display.
  JourneyMember withExtraCompletions(Set<String> extra) {
    if (extra.isEmpty) return this;
    return JourneyMember(
      userId:         userId,
      name:           name,
      username:       username,
      status:         status,
      completedAyahs: {...completedAyahs, for (final k in extra) k: true},
      completedCount: completedCount + extra.length,
      joinedAt:       joinedAt,
      updatedAt:      updatedAt,
    );
  }

  static JourneyMember fromMap(Map<dynamic, dynamic> map) {
    final completedRaw = map['completedAyahs'];
    final completedAyahs = completedRaw is Map
        ? Map<String, bool>.fromEntries(
            completedRaw.entries.map((e) => MapEntry(e.key as String, e.value as bool)),
          )
        : <String, bool>{};
    return JourneyMember(
      userId:         map['userId'] as String,
      name:           map['name'] as String? ?? '',
      username:       map['username'] as String? ?? '',
      status:         map['status'] as String? ?? 'active',
      completedAyahs: completedAyahs,
      completedCount: map['completedCount'] as int? ?? 0,
      joinedAt:       _parseTs(map['joinedAt']),
      updatedAt:      _parseTs(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
    'userId':         userId,
    'name':           name,
    'username':       username,
    'status':         status,
    'completedAyahs': completedAyahs,
    'completedCount': completedCount,
    'joinedAt':       joinedAt.toIso8601String(),
    'updatedAt':      updatedAt.toIso8601String(),
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Journey — group-first journey with per-member tracking
// ─────────────────────────────────────────────────────────────────────────────

class Journey {
  final String id;
  final String creatorId;
  final String title;
  final List<String> dimensions;
  final int startSurah;
  final int startAyah;
  final int endSurah;
  final int endAyah;
  final DateTime startDate;
  final DateTime endDate;
  final String status; // aggregate across all members
  final int totalAyahs;
  final bool allowJoining;
  final List<String> memberIds;
  final int memberCount;
  final List<JourneyMember> members;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Journey({
    required this.id,
    required this.creatorId,
    required this.title,
    required this.dimensions,
    required this.startSurah,
    required this.startAyah,
    required this.endSurah,
    required this.endAyah,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.totalAyahs,
    required this.allowJoining,
    required this.memberIds,
    required this.memberCount,
    required this.members,
    required this.createdAt,
    required this.updatedAt,
  });

  // ── Aggregate status helpers (group-level) ────────────────────────────────

  bool get isActive    => status == 'active';
  bool get isPaused    => status == 'paused';
  bool get isDelayed   => status == 'delayed';
  bool get isCompleted => status == 'completed';
  bool get isAbandoned => status == 'abandoned';

  int get daysOverdue =>
      isDelayed ? DateTime.now().difference(endDate).inDays.clamp(0, 9999) : 0;

  // ── Member helpers ────────────────────────────────────────────────────────

  JourneyMember? memberFor(String uid) {
    try {
      return members.firstWhere((m) => m.userId == uid);
    } catch (_) {
      return null;
    }
  }

  bool isMemberOf(String uid) => memberIds.contains(uid);
  bool isCreatorOf(String uid) => creatorId == uid;

  // ── Progress helpers (per-member) ─────────────────────────────────────────

  double progressFractionFor(JourneyMember member) =>
      totalAyahs > 0 ? member.completedCount / totalAyahs : 0.0;

  int progressPercentFor(JourneyMember member) =>
      (progressFractionFor(member) * 100).toInt();

  int doneInSurah(JourneyMember member, int surah) {
    final minA = surah == startSurah ? startAyah : 1;
    final maxA = surah == endSurah ? endAyah : ayahCounts[surah];
    int count = 0;
    for (int a = minA; a <= maxA; a++) {
      if (member.isAyahDone(surah, a)) count++;
    }
    return count;
  }

  int ayahsInSurahRange(int surah) {
    final minA = surah == startSurah ? startAyah : 1;
    final maxA = surah == endSurah ? endAyah : ayahCounts[surah];
    return maxA - minA + 1;
  }

  // ── Parsing ───────────────────────────────────────────────────────────────

  static Journey fromMap(Map<dynamic, dynamic> map) {
    return Journey(
      id:           map['id'] as String,
      creatorId:    map['creatorId'] as String,
      title:        map['title'] as String,
      dimensions:   List<String>.from(map['dimensions'] as List),
      startSurah:   map['startSurah'] as int,
      startAyah:    map['startAyah'] as int,
      endSurah:     map['endSurah'] as int,
      endAyah:      map['endAyah'] as int,
      startDate:    _parseTs(map['startDate']),
      endDate:      _parseTs(map['endDate']),
      status:       map['status'] as String? ?? 'active',
      totalAyahs:   map['totalAyahs'] as int? ?? 0,
      allowJoining: map['allowJoining'] as bool? ?? false,
      memberIds:    List<String>.from(map['memberIds'] as List? ?? []),
      memberCount:  map['memberCount'] as int? ?? 0,
      members:      (map['members'] as List? ?? [])
          .map((e) => JourneyMember.fromMap(e as Map))
          .toList(),
      createdAt:    _parseTs(map['createdAt']),
      updatedAt:    _parseTs(map['updatedAt']),
    );
  }

  static List<Journey> parseList(List<dynamic> list) =>
      list.map((e) => Journey.fromMap(e as Map)).toList();

  Map<String, dynamic> toMap() => {
    'id':           id,
    'creatorId':    creatorId,
    'title':        title,
    'dimensions':   dimensions,
    'startSurah':   startSurah,
    'startAyah':    startAyah,
    'endSurah':     endSurah,
    'endAyah':      endAyah,
    'startDate':    startDate.toIso8601String(),
    'endDate':      endDate.toIso8601String(),
    'status':       status,
    'totalAyahs':   totalAyahs,
    'allowJoining': allowJoining,
    'memberIds':    memberIds,
    'memberCount':  memberCount,
    'members':      members.map((m) => m.toMap()).toList(),
    'createdAt':    createdAt.toIso8601String(),
    'updatedAt':    updatedAt.toIso8601String(),
  };
}
