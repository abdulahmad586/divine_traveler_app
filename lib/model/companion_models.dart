import 'package:tahfeex/model/journey_model.dart';

// ── Companion request ─────────────────────────────────────────────────────────

class CompanionRequest {
  final String id;
  final String fromUserId;
  final String fromUsername;
  final String toUserId;
  final String toUsername;

  const CompanionRequest({
    required this.id,
    required this.fromUserId,
    required this.fromUsername,
    required this.toUserId,
    required this.toUsername,
  });

  factory CompanionRequest.fromJson(Map<dynamic, dynamic> json) =>
      CompanionRequest(
        id: json['id'] as String,
        fromUserId: json['fromUserId'] as String,
        fromUsername: json['fromUsername'] as String,
        toUserId: json['toUserId'] as String,
        toUsername: json['toUsername'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'fromUserId': fromUserId,
        'fromUsername': fromUsername,
        'toUserId': toUserId,
        'toUsername': toUsername,
      };

  static List<CompanionRequest> parseList(List<dynamic> data) =>
      data.map((e) => CompanionRequest.fromJson(e as Map)).toList();
}

// ── User stats ────────────────────────────────────────────────────────────────

class UserStats {
  final int totalCompanions;
  final int completedAyahs;

  const UserStats({
    required this.totalCompanions,
    required this.completedAyahs,
  });

  factory UserStats.fromJson(Map<String, dynamic> json) => UserStats(
        totalCompanions: json['totalCompanions'] as int? ?? 0,
        completedAyahs: json['completedAyahs'] as int? ?? 0,
      );
}

// ── Relationship between current user and a profile ──────────────────────────

class UserRelationship {
  final bool isCompanion;
  final bool sentRequest;
  final bool receivedRequest;
  final bool isBlocked;

  const UserRelationship({
    required this.isCompanion,
    required this.sentRequest,
    required this.receivedRequest,
    required this.isBlocked,
  });

  factory UserRelationship.fromJson(Map<String, dynamic> json) =>
      UserRelationship(
        isCompanion: json['isCompanion'] as bool? ?? false,
        sentRequest: json['sentRequest'] as bool? ?? false,
        receivedRequest: json['receivedRequest'] as bool? ?? false,
        isBlocked: json['isBlocked'] as bool? ?? false,
      );
}

// ── Public user profile ───────────────────────────────────────────────────────

class UserProfile {
  final String id;
  final String name;
  final String username;
  final UserStats stats;
  // Only present when the request was authenticated.
  final UserRelationship? relationship;
  // Only present when isCompanion == true.
  final List<Journey>? journeys;

  const UserProfile({
    required this.id,
    required this.name,
    required this.username,
    required this.stats,
    this.relationship,
    this.journeys,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as String,
        name: json['name'] as String,
        username: json['username'] as String,
        stats: UserStats.fromJson(json['stats'] as Map<String, dynamic>),
        relationship: json['relationship'] != null
            ? UserRelationship.fromJson(
                json['relationship'] as Map<String, dynamic>)
            : null,
        journeys: json['journeys'] != null
            ? Journey.parseList(json['journeys'] as List<dynamic>)
            : null,
      );

  /// First letter of display name for avatar fallback.
  String get initial => name.isNotEmpty ? name[0].toUpperCase() : '?';
}
