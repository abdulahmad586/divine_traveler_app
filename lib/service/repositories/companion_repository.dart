import 'package:tahfeex/model/app_user_model.dart';
import 'package:tahfeex/model/companion_models.dart';
import 'package:tahfeex/shared/connections/connections.dart';
import 'package:tahfeex/shared/constants/constants.dart';

class CompanionRepository {
  final _client = DioClient();

  // ── Profiles ──────────────────────────────────────────────────────────────

  Future<UserProfile> getUserProfile(String username) async {
    final data = await _client.get(ApiConstants.userProfile(username));
    return UserProfile.fromJson(data as Map<String, dynamic>);
  }

  // ── Companions ────────────────────────────────────────────────────────────

  Future<List<AppUser>> getCompanions() async {
    final data = await _client.get(ApiConstants.companions);
    return (data as List<dynamic>)
        .map((e) => AppUser.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> removeCompanion(String userId) async {
    await _client.delete(ApiConstants.companionById(userId));
  }

  // ── Requests ──────────────────────────────────────────────────────────────

  Future<List<CompanionRequest>> getIncomingRequests() async {
    final data = await _client.get(ApiConstants.companionRequestsIncoming);
    return CompanionRequest.parseList(data as List<dynamic>);
  }

  Future<List<CompanionRequest>> getOutgoingRequests() async {
    final data = await _client.get(ApiConstants.companionRequestsOutgoing);
    return CompanionRequest.parseList(data as List<dynamic>);
  }

  /// Returns true if the request was auto-accepted (both users had pending
  /// requests to each other), false if the request is now pending.
  Future<bool> sendRequest(String username) async {
    final data = await _client.post(
      ApiConstants.companionRequests,
      data: {'username': username},
    );
    final body = data as Map<String, dynamic>;
    return body['autoAccepted'] == true;
  }

  Future<void> acceptRequest(String requestId) async {
    await _client.post(ApiConstants.companionRequestAccept(requestId));
  }

  Future<void> cancelOrRejectRequest(String requestId) async {
    await _client.delete(ApiConstants.companionRequestById(requestId));
  }

  // ── Blocks ────────────────────────────────────────────────────────────────

  Future<void> block(String username) async {
    await _client.post(
      ApiConstants.blocks,
      data: {'username': username},
    );
  }

  Future<void> unblock(String userId) async {
    await _client.delete(ApiConstants.blockById(userId));
  }
}
