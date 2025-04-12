import 'dart:convert';
import 'package:dio/dio.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/api_constants.dart';

class ApiHelper {
  static final FlutterSecureStorage _storage = FlutterSecureStorage();

  // Add auth token to request header
  static Future<Map<String, String>> getHeaders() async {
    Map<String, String> headers = Map.from(ApiConstants.headers);
    String? token = await _storage.read(key: 'auth_token');
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  // Handle API Response
  static dynamic handleResponse(Response response) {
    switch (response.statusCode) {
      case 200:
      case 201:
        return response.data;
      case 400:
        throw 'Bad Request: ${response.data['message'] ?? 'Unknown error'}';
      case 401:
        throw 'Unauthorized: ${response.data['message'] ?? 'Please login again'}';
      case 403:
        throw 'Forbidden: ${response.data['message'] ?? 'Access denied'}';
      case 404:
        throw 'Not Found: ${response.data['message'] ?? 'Resource not found'}';
      case 500:
        throw 'Server Error: Please try again later';
      default:
        throw 'Unknown Error: ${response.statusCode}';
    }
  }

  // Handle API Error
  static String handleError(dynamic error) {
    if (error is DioError) {
      switch (error.type) {
        case DioErrorType.connectionTimeout:
          return 'Connection timeout. Please check your internet connection';
        case DioErrorType.sendTimeout:
          return 'Send timeout. Please try again';
        case DioErrorType.receiveTimeout:
          return 'Receive timeout. Please try again';
        case DioErrorType.badResponse:
          return handleResponse(error.response!);
        case DioErrorType.cancel:
          return 'Request cancelled';
        default:
          return 'Network error occurred';
      }
    }
    return error.toString();
  }

  // Parse JSON safely
  static dynamic parseJson(String? jsonString) {
    if (jsonString == null) return null;
    try {
      return json.decode(jsonString);
    } catch (e) {
      return null;
    }
  }
}
