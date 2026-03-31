class ApiConstants {
  // Base URLs — call DioClient().setBaseUrl(...) at app start to pick the right one.
  static const String devBaseUrl = 'https://divine-traveler.onrender.com';
  static const String prodBaseUrl = 'https://divine-traveler.onrender.com';

  // Health
  static const String health = '/health';

  // Contributions
  static const String contributions = '/contributions';
  static String contributionById(String id) => '/contributions/$id';
  static String likeContribution(String id) => '/contributions/$id/like';
  static String downloadContribution(String id) =>
      '/contributions/$id/download';

  // Journeys
  static const String journeys = '/journeys';
  static String journeyById(String id) => '/journeys/$id';
  static String journeyProgress(String id) => '/journeys/$id/progress';
  static String journeyStatus(String id) => '/journeys/$id/status';
  static String journeyJoin(String id) => '/journeys/$id/join';
  static String journeyLeave(String id) => '/journeys/$id/leave';
  static String journeySettings(String id) => '/journeys/$id/settings';
  static String journeyMember(String id, String memberId) =>
      '/journeys/$id/members/$memberId';
  static String journeyMemberNudge(String id, String memberId) =>
      '/journeys/$id/members/$memberId/nudge';

  // Current user
  static const String me = '/me';
  static const String meUsername = '/me/username';
  static const String meSettings = '/me/settings';
  static const String meFcmToken = '/me/fcm-token';

  // Public profiles
  static String userProfile(String username) => '/users/$username';

  // Companions
  static const String companions = '/companions';
  static String companionById(String userId) => '/companions/$userId';

  // Companion requests
  static const String companionRequests = '/companions/requests';
  static const String companionRequestsIncoming = '/companions/requests/incoming';
  static const String companionRequestsOutgoing = '/companions/requests/outgoing';
  static String companionRequestAccept(String id) =>
      '/companions/requests/$id/accept';
  static String companionRequestById(String id) => '/companions/requests/$id';

  // Blocks
  static const String blocks = '/blocks';
  static String blockById(String userId) => '/blocks/$userId';
}
