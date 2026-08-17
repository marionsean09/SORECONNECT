class UserModel {

  final String uid;
  final String fullName;
  final String email;
  final String userType;

  UserModel({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.userType,
  });

  Map<String, dynamic> toMap() {

    return {
      'uid': uid,
      'full_name': fullName,
      'email': email,
      'user_type': userType,
    };
  }
}