import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_model.dart';

class UserService {
  final FlutterSecureStorage _storage = FlutterSecureStorage();
  final String _key = 'user_data';

  Future<void> saveUser(UserModel user) async {
    await _storage.write(key: _key, value: json.encode(user.toJson()));
  }

  Future<UserModel?> getUser() async {
    String? userData = await _storage.read(key: _key);
    if (userData != null) {
      return UserModel.fromJson(json.decode(userData));
    }
    return null;
  }

  Future<void> clearAllData() async {
    await _storage.deleteAll();
  }

  Future<String?> getFirstName() async {
    UserModel? user = await getUser();
    return user?.firstName;
  }

  Future<String?> getLastName() async {
    UserModel? user = await getUser();
    return user?.lastName;
  }

  Future<String?> getEmail() async {
    UserModel? user = await getUser();
    return user?.email;
  }

  Future<String?> getAccountType() async {
    UserModel? user = await getUser();
    return user?.accountType;
  }

  Future<String?> getImage() async {
    UserModel? user = await getUser();
    return user?.image;
  }

  Future<String?> getUserId() async {
    UserModel? user = await getUser();
    return user?.id;
  }
}
