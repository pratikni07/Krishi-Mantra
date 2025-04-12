class UserModel {
  final String id;
  final String name;
  final String firstName;
  final String lastName;
  final String email;
  final String phoneNo;
  final String accountType;
  final String image;
  final String token;

  UserModel({
    required this.id,
    required this.name,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phoneNo,
    required this.accountType,
    required this.image,
    required this.token,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      email: json['email'] ?? '',
      phoneNo: json['phoneNo']?.toString() ?? '',
      accountType: json['accountType'] ?? '',
      image: json['image'] ?? '',
      token: json['token'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phoneNo': phoneNo,
      'accountType': accountType,
      'image': image,
      'token': token,
    };
  }
}
