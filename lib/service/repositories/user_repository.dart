import 'package:tahfeex/model/app_user_model.dart';
import 'package:tahfeex/shared/connections/connections.dart';
import 'package:tahfeex/shared/constants/constants.dart';

class UserRepository {
  final _client = DioClient();

  Future<AppUser> getMe() async {
    final data = await _client.get(ApiConstants.me);
    return AppUser.fromJson(data as Map<String, dynamic>);
  }

  Future<AppUser> updateUsername(String username) async {
    final data = await _client.patch(
      ApiConstants.meUsername,
      data: {'username': username},
    );
    return AppUser.fromJson(data as Map<String, dynamic>);
  }

  Future<AppUser> updateSettings({required bool allowFriendRequests}) async {
    final data = await _client.patch(
      ApiConstants.meSettings,
      data: {'allowFriendRequests': allowFriendRequests},
    );
    return AppUser.fromJson(data as Map<String, dynamic>);
  }

  Future<void> updateFcmToken(String fcmToken) async {
    await _client.patch(
      ApiConstants.meFcmToken,
      data: {'fcmToken': fcmToken},
    );
  }
}
