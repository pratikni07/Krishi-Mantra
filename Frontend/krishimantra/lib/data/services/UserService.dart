import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_model.dart';

class UserService {
  final FlutterSecureStorage _storage = FlutterSecureStorage();
  final String _key = 'user_data';
  UserModel? _currentUser;

  // Getter for current user
  UserModel? get currentUser => _currentUser;

  Future<void> saveUser(UserModel user) async {
    _currentUser = user;
    await _storage.write(key: _key, value: json.encode(user.toJson()));
  }

  Future<UserModel?> getUser() async {
    if (_currentUser != null) return _currentUser;

    String? userData = await _storage.read(key: _key);
    if (userData != null) {
      _currentUser = UserModel.fromJson(json.decode(userData));
      return _currentUser;
    }
    return null;
  }

  Future<void> clearAllData() async {
    _currentUser = null;
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
