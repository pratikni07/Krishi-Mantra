// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:dio/dio.dart' as dio;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../../core/constants/api_constants.dart';
import '../../core/utils/api_helper.dart';

class AuthRepository {
  final ApiService _apiService;
  final _storage = const FlutterSecureStorage();

  AuthRepository(this._apiService);

  // Traditional email/password login
  Future<UserModel> login(String email, String password) async {
    try {
      print('🔍 Starting login in repository');
      print('📝 Request data: email=$email, password=***');

      final response = await _apiService.post(
        ApiConstants.LOGIN,
        data: {
          'email': email,
          'password': password,
        },
      );

      final Map<String, dynamic> responseData = response.data;

      print('🔍 Checking response format');
      if (!responseData.containsKey('success')) print('❌ Missing success key');
      if (!responseData.containsKey('token')) print('❌ Missing token key');
      if (!responseData.containsKey('user')) print('❌ Missing user key');

      if (!responseData.containsKey('success') ||
          !responseData.containsKey('token') ||
          !responseData.containsKey('user')) {
        throw Exception('Invalid response format');
      }

      final token = responseData['token'] as String;
      print('🎟️ Token received: ${token.substring(0, 10)}...');

      final userData = responseData['user'] as Map<String, dynamic>;
      print('👤 User data received: $userData');

      // Add token to user data
      userData['token'] = token;

      print('💾 Storing auth token');
      await _storage.write(key: 'auth_token', value: token);

      print('💾 Storing user data');
      await _storage.write(key: 'user_data', value: json.encode(userData));

      print('🏗️ Creating UserModel');
      final userModel = UserModel.fromJson(userData);
      print('✅ UserModel created: $userModel');

      return userModel;
    } catch (e, stackTrace) {
      print('⚠️ Login error in repository: $e');
      print('📚 Stack trace: $stackTrace');
      if (e is dio.DioException) {
        final response = e.response?.data;
        print('🌐 Dio error response: $response');
        if (response != null && response['message'] != null) {
          throw Exception(response['message']);
        }
      }
      throw Exception('Login failed. Please try again.');
    }
  }

  // Phone authentication methods
  Future<Map<String, dynamic>> initiateAuth(String phoneNo) async {
    try {
      final response = await _apiService.post(
        ApiConstants.INITIATE_AUTH,
        data: {
          'phoneNo': phoneNo,
        },
      );

      return response.data;
    } catch (e) {
      if (e is dio.DioException && e.response != null) {
        return e.response!.data;
      }
      throw Exception('Failed to initiate authentication: $e');
    }
  }

  Future<Map<String, dynamic>> verifyOTP(String phoneNo, String otp) async {
    try {
      final response = await _apiService.post(
        ApiConstants.VERIFY_OTP,
        data: {
          'phoneNo': phoneNo,
          'otp': otp,
        },
      );

      return response.data;
    } catch (e) {
      if (e is dio.DioException && e.response != null) {
        return e.response!.data;
      }
      throw Exception('OTP verification failed: $e');
    }
  }

  Future<Map<String, dynamic>> signupWithPhone(
      Map<String, dynamic> data) async {
    try {
      final response = await _apiService.post(
        ApiConstants.SIGNUP_WITH_PHONE,
        data: data,
      );

      return response.data;
    } catch (e) {
      if (e is dio.DioException && e.response != null) {
        return e.response!.data;
      }
      throw Exception('Registration failed: $e');
    }
  }

  // Future<Map<String, dynamic>> uploadProfileImage(dio.FormData formData) async {
  //   try {
  //     final response = await _apiService.post(
  //       ApiConstants.UPLOAD_IMAGE,
  //       data: formData,
  //     );

  //     return response.data;
  //   } catch (e) {
  //     if (e is dio.DioException && e.response != null) {
  //       return e.response!.data;
  //     }
  //     throw Exception('Image upload failed: $e');
  //   }
  // }

  // Register
  Future<UserModel> register(String name, String email, String password) async {
    try {
      final response = await _apiService.post(
        ApiConstants.REGISTER,
        data: {
          'name': name,
          'email': email,
          'password': password,
        },
      );

      final data = ApiHelper.handleResponse(response);

      // Save auth token
      await _saveAuthToken(data['token']);

      // Return user data
      return UserModel.fromJson(data['user']);
    } catch (e) {
      throw ApiHelper.handleError(e);
    }
  }

  // Forgot Password
  Future<void> forgotPassword(String email) async {
    try {
      final response = await _apiService.post(
        ApiConstants.FORGOT_PASSWORD,
        data: {'email': email},
      );

      ApiHelper.handleResponse(response);
    } catch (e) {
      throw ApiHelper.handleError(e);
    }
  }

  // Reset Password
  Future<void> resetPassword(String token, String password) async {
    try {
      final response = await _apiService.post(
        ApiConstants.RESET_PASSWORD,
        data: {
          'token': token,
          'password': password,
        },
      );

      ApiHelper.handleResponse(response);
    } catch (e) {
      throw ApiHelper.handleError(e);
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      await _clearAuthToken();
    } catch (e) {
      throw ApiHelper.handleError(e);
    }
  }

  // Helper Methods
  Future<void> _saveAuthToken(String token) async {
    final storage = FlutterSecureStorage();
    await storage.write(key: 'auth_token', value: token);
  }

  Future<void> _clearAuthToken() async {
    final storage = FlutterSecureStorage();
    await storage.delete(key: 'auth_token');
  }
}
