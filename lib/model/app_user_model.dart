class AppUser {
  final String id;
  final String name;
  final String email;
  final String username;
  final bool allowFriendRequests;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.username,
    required this.allowFriendRequests,
  });

  factory AppUser.fromJson(Map<dynamic, dynamic> json) => AppUser(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        username: json['username'] as String,
        allowFriendRequests: json['allowFriendRequests'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'username': username,
        'allowFriendRequests': allowFriendRequests,
      };

  AppUser copyWith({String? username, bool? allowFriendRequests}) => AppUser(
        id: id,
        name: name,
        email: email,
        username: username ?? this.username,
        allowFriendRequests: allowFriendRequests ?? this.allowFriendRequests,
      );

  /// First letter of display name, used for avatar fallback.
  String get initial => name.isNotEmpty ? name[0].toUpperCase() : '?';
}
