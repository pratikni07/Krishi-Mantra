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
      final response = await _apiService.post(
        ApiConstants.LOGIN,
        data: {
          'email': email,
          'password': password,
        },
      );

      final Map<String, dynamic> responseData = response.data;

      if (!responseData.containsKey('success') ||
          !responseData.containsKey('token') ||
          !responseData.containsKey('user')) {
        throw Exception('Invalid response format');
      }

      final token = responseData['token'] as String;
      final userData = responseData['user'] as Map<String, dynamic>;
      userData['token'] = token;

      await _storage.write(key: 'auth_token', value: token);

      if (responseData['refreshToken'] != null) {
        await _storage.write(key: 'refresh_token', value: responseData['refreshToken'] as String);
      }

      await _storage.write(key: 'user_data', value: json.encode(userData));

      return UserModel.fromJson(userData);
    } catch (e) {
      if (e is dio.DioException) {
        final response = e.response?.data;
        if (response != null && response['message'] != null) {
          throw Exception(response['message']);
        }
      }
      throw Exception('Login failed. Please try again.');
    }
  }

  // Phone authentication methods
  Future<Map<String, dynamic>> initiateAuth(String phoneNo, {String language = 'hi'}) async {
    try {
      final response = await _apiService.post(
        ApiConstants.INITIATE_AUTH,
        data: {
          'phoneNo': phoneNo,
          'language': language,
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

  // Logout. Best-effort backend revoke followed by local-state cleanup.
  // The backend call is wrapped because if the server is unreachable we
  // still want to clear local creds and route the user back to login —
  // skipping that would leave them stuck on a "logout failed" screen
  // with stale auth state.
  Future<void> logout() async {
    final refreshToken = await _storage.read(key: 'refresh_token');
    try {
      await _apiService.post(
        ApiConstants.LOGOUT,
        data: refreshToken != null ? {'refreshToken': refreshToken} : {},
      );
    } catch (e) {
      // Don't throw — local cleanup must still run.
      print('logout: backend revoke failed (continuing): $e');
    }
    await _storage.deleteAll();
  }

  /// Validate the cached access token by hitting a cheap protected
  /// endpoint. Returns true if the server accepts the token, false
  /// otherwise. The interceptor handles refresh-and-retry transparently
  /// for 401s, so a `false` here means the user really is logged out
  /// (refresh also failed, network down, etc.).
  Future<bool> validateToken() async {
    try {
      final response = await _apiService.get(ApiConstants.AUTH_ME);
      return response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300;
    } catch (_) {
      return false;
    }
  }

  // Helper Methods
  Future<void> _saveAuthToken(String token) async {
    await _storage.write(key: 'auth_token', value: token);
  }
}
