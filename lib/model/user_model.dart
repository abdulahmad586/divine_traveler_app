class User{

  static const String defaultProfileImage = "https://uxwing.com/wp-content/themes/uxwing/download/peoples-avatars/default-profile-picture-grey-male-icon.png";

  String id;
  String name;
  String email;
  String profileImage;

  User({required this.id, required this.name, required this.email, this.profileImage=defaultProfileImage});

  factory User.fromJson(Map<String, dynamic> json){
    return User(
      id: json["id"] ?? json["_id"],
      name: json["name"],
      email: json["email"],
      profileImage: json["profileImage"],
    );
  }

  Map<String,dynamic> toJson(){
    return {
      'id': id,
      'name':name,
      'email':email,
      'profileImage': profileImage == defaultProfileImage ? null : profileImage
    };
  }

}