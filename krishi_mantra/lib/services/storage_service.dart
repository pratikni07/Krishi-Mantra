// lib/services/storage_service.dart

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static Future<Map<String, dynamic>?> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? userDataString = prefs.getString('userData');

    if (userDataString != null) {
      return json.decode(userDataString) as Map<String, dynamic>;
    }
    return null;
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<String?> getUserName() async {
    final userData = await getUserData();
    return userData?['name'] as String?;
  }

  static Future<String?> getUserEmail() async {
    final userData = await getUserData();
    return userData?['email'] as String?;
  }

  static Future<String?> getPhoneNumber() async {
    final userData = await getUserData();
    return userData?['phoneNo']?.toString();
  }

  static Future<String?> getUserImage() async {
    final userData = await getUserData();
    return userData?['image'] as String?;
  }

  static Future<String?> getAccountType() async {
    final userData = await getUserData();
    return userData?['accountType'] as String?;
  }

  // Example of getting nested data
  static Future<Map<String, dynamic>?> getAdditionalDetails() async {
    final userData = await getUserData();
    return userData?['additionalDetails'] as Map<String, dynamic>?;
  }

  static Future<void> clearUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userData');
    await prefs.remove('token');
  }
}
