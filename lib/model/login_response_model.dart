import 'user_model.dart';

class LoginResponse{
  String token;
  User user;

  LoginResponse({required this.token, required this.user});

  factory LoginResponse.fromJson(Map<String, dynamic> json){
    return LoginResponse(
        token: json["token"] ?? json["token"],
        user: User.fromJson(json["user"]),
    );
  }

}