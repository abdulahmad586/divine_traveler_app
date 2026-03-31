import 'package:tahfeex/model/models.dart';
import 'package:tahfeex/shared/connections/connections.dart';
import 'package:tahfeex/shared/constants/constants.dart';

/// Wraps all `/journeys` endpoints.
class JourneyRepository {
  final _client = DioClient();

  Future<List<Journey>> getJourneys() async {
    final data = await _client.get(ApiConstants.journeys);
    return Journey.parseList(data as List<dynamic>);
  }

  Future<Journey> getJourneyById(String id) async {
    final data = await _client.get(ApiConstants.journeyById(id));
    return Journey.fromMap(data as Map<String, dynamic>);
  }

  Future<Journey> createJourney({
    String? title,
    required List<String> dimensions,
    required int startSurah,
    required int startAyah,
    required int endSurah,
    required int endAyah,
    required DateTime startDate,
    required DateTime endDate,
    bool allowJoining = false,
  }) async {
    final data = await _client.post(ApiConstants.journeys, data: {
      'dimensions': dimensions,
      'startSurah': startSurah,
      'startAyah': startAyah,
      'endSurah': endSurah,
      'endAyah': endAyah,
      'startDate': startDate.toUtc().toIso8601String(),
      'endDate': endDate.toUtc().toIso8601String(),
      'allowJoining': allowJoining,
      if (title != null && title.isNotEmpty) 'title': title,
    });
    return Journey.fromMap(data as Map<String, dynamic>);
  }

  /// [ayah] null → mark entire surah; non-null → mark single ayah.
  Future<Journey> updateProgress({
    required String id,
    required int surah,
    int? ayah,
  }) async {
    final data = await _client.post(ApiConstants.journeyProgress(id), data: {
      'surah': surah,
      if (ayah != null) 'ayah': ayah,
    });
    return Journey.fromMap(data as Map<String, dynamic>);
  }

  Future<Journey> updateStatus({
    required String id,
    required String status,
  }) async {
    final data = await _client.patch(
      ApiConstants.journeyStatus(id),
      data: {'status': status},
    );
    return Journey.fromMap(data as Map<String, dynamic>);
  }

  Future<Journey> joinJourney(String id) async {
    final data = await _client.post(ApiConstants.journeyJoin(id));
    return Journey.fromMap(data as Map<String, dynamic>);
  }

  /// Leaves the journey. Returns null (204 No Content).
  Future<void> leaveJourney(String id) async {
    await _client.delete(ApiConstants.journeyLeave(id));
  }

  /// Creator removes a member. Returns updated journey.
  Future<Journey> removeMember({
    required String journeyId,
    required String memberId,
  }) async {
    final data = await _client.delete(
      ApiConstants.journeyMember(journeyId, memberId),
    );
    return Journey.fromMap(data as Map<String, dynamic>);
  }

  /// Nudges a member (sends a push notification to them). Returns void.
  Future<void> nudgeMember({
    required String journeyId,
    required String memberId,
  }) async {
    await _client.post(ApiConstants.journeyMemberNudge(journeyId, memberId));
  }

  Future<Journey> updateSettings({
    required String id,
    required bool allowJoining,
  }) async {
    final data = await _client.patch(
      ApiConstants.journeySettings(id),
      data: {'allowJoining': allowJoining},
    );
    return Journey.fromMap(data as Map<String, dynamic>);
  }
}
