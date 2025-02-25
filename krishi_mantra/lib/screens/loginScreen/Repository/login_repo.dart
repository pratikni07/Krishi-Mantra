import 'dart:convert';
import 'package:krishi_mantra/API/SignInSignUpAPI.dart';

import 'package:shared_preferences/shared_preferences.dart';

class LoginRepo {
  final ApiService _apiService = ApiService();
  final SharedPreferences _prefs;

  LoginRepo(this._prefs);

  Future<bool> login(String email, String password) async {
    try {
      final response = await _apiService.login(email, password);
      if (response['success'] == true) {
        await _saveUserData(response);
        return true;
      }
      return false;
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }

  Future<void> _saveUserData(Map<String, dynamic> response) async {
    await _prefs.setString('token', response['token']);
    await _prefs.setString('userData', json.encode(response['user']));
  }

  Future<bool> isLoggedIn() async {
    final token = _prefs.getString('token');
    return token != null && token.isNotEmpty;
  }

  Future<void> logout() async {
    await _prefs.remove('token');
    await _prefs.remove('userData');
  }
}
