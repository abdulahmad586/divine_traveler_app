import 'dart:convert';

class ContributionModel {
  final String id;
  final String reciterName;
  final int surah;
  final String audioFileId;
  final String timingFileId;
  final String audioHash;
  final String createdBy;
  final String createdByName;
  final DateTime createdAt;
  final String status;
  final int downloads;
  final int likes;

  const ContributionModel({
    required this.id,
    required this.reciterName,
    required this.surah,
    required this.audioFileId,
    required this.timingFileId,
    required this.audioHash,
    required this.createdBy,
    required this.createdByName,
    required this.createdAt,
    required this.status,
    required this.downloads,
    required this.likes,
  });

  /// URL to stream/download the audio directly from the submitter's Drive.
  String get audioUrl =>
      'https://drive.google.com/uc?id=$audioFileId&export=download';

  /// URL to fetch the timing JSON from the submitter's Drive.
  String get timingUrl =>
      'https://drive.google.com/uc?id=$timingFileId&export=download';

  static ContributionModel fromMap(Map<String, dynamic> map) {
    return ContributionModel(
      id: map['id'] as String,
      reciterName: map['reciterName'] as String,
      surah: map['surah'] as int,
      audioFileId: map['audioFileId'] as String,
      timingFileId: map['timingFileId'] as String,
      audioHash: map['audioHash'] as String,
      createdBy: map['createdBy'] as String,
      createdByName: map['createdByName'] as String,
      createdAt: _parseTimestamp(map['createdAt']),
      status: map['status'] as String? ?? 'pending',
      downloads: map['downloads'] as int? ?? 0,
      likes: map['likes'] as int? ?? 0,
    );
  }

  static List<ContributionModel> parseList(List<dynamic> list) => list
      .map((e) => ContributionModel.fromMap(e as Map<String, dynamic>))
      .toList();

  Map<String, dynamic> toMap() => {
        'id': id,
        'reciterName': reciterName,
        'surah': surah,
        'audioFileId': audioFileId,
        'timingFileId': timingFileId,
        'audioHash': audioHash,
        'createdBy': createdBy,
        'createdByName': createdByName,
        'createdAt': createdAt.toIso8601String(),
        'status': status,
        'downloads': downloads,
        'likes': likes,
      };

  String toJson() => jsonEncode(toMap());

  // Firestore Timestamp: { "_seconds": 1743184800, "_nanoseconds": 0 }
  static DateTime _parseTimestamp(dynamic raw) {
    if (raw == null) return DateTime.now();
    if (raw is Map) {
      final seconds = raw['_seconds'] as int? ?? 0;
      return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    }
    // Fallback: ISO string
    if (raw is String) return DateTime.tryParse(raw) ?? DateTime.now();
    return DateTime.now();
  }
}
