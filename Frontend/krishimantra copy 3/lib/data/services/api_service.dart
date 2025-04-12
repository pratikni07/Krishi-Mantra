// ignore_for_file: avoid_print, unused_catch_stack

import 'package:dio/dio.dart';
import '../../core/constants/api_constants.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';

class ApiService {
  final Dio _dio;
  final Connectivity _connectivity = Connectivity();

  ApiService(this._dio) {
    _dio.options.baseUrl = ApiConstants.BASE_URL;
    _dio.options.connectTimeout = const Duration(seconds: 15);
    _dio.options.receiveTimeout = const Duration(seconds: 10);

    // Only log in debug mode
    assert(() {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (obj) => print('🌐 Dio: $obj'),
      ));
      return true;
    }());

    // Add retry interceptor
    _dio.interceptors.add(
      RetryInterceptor(
        dio: _dio,
        retries: 3,
        retryDelays: const [
          Duration(seconds: 1),
          Duration(seconds: 2),
          Duration(seconds: 3),
        ],
      ),
    );
  }

  Future<bool> _checkConnectivity() async {
    final connectivityResult = await _connectivity.checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  Future<Response> get(String path,
      {Map<String, dynamic>? queryParameters}) async {
    if (!await _checkConnectivity()) {
      throw NoInternetException();
    }
    try {
      return await _dio.get(path, queryParameters: queryParameters);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> post(String path, {dynamic data}) async {
    try {
      final response = await _dio.post(path, data: data);
      if (response.data == null) {
        throw Exception('Received null response data');
      }
      return response;
    } catch (e, stackTrace) {
      throw _handleError(e);
    }
  }

  Future<Response> put(String path, {dynamic data}) async {
    try {
      final response = await _dio.put(path, data: data);
      if (response.data == null) {
        throw Exception('Received null response data');
      }
      return response;
    } catch (e, stackTrace) {
      throw _handleError(e);
    }
  }

  Future<Response> delete(String path, {dynamic data}) async {
    try {
      final response = await _dio.delete(path, data: data);
      if (response.data == null) {
        throw Exception('Received null response data');
      }
      return response;
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> patch(String path, {dynamic data}) async {
    try {
      final response = await _dio.patch(path, data: data);
      if (response.data == null) {
        throw Exception('Received null response data');
      }
      return response;
    } catch (e) {
      throw _handleError(e);
    }
  }

  Exception _handleError(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return TimeoutException('Request timed out');
        case DioExceptionType.badResponse:
          return _handleResponseError(error.response?.statusCode);
        case DioExceptionType.cancel:
          return RequestCancelledException();
        default:
          return NetworkException('Network error occurred');
      }
    }
    return Exception('An unexpected error occurred');
  }

  Exception _handleResponseError(int? statusCode) {
    switch (statusCode) {
      case 400:
        return BadRequestException();
      case 401:
        return UnauthorizedException();
      case 403:
        return ForbiddenException();
      case 404:
        return NotFoundException();
      case 500:
        return ServerException();
      default:
        return ApiException('API Error: ${statusCode ?? "Unknown"}');
    }
  }
}

class NoInternetException implements Exception {
  final String message = 'No internet connection';
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);
}

class RequestCancelledException implements Exception {
  final String message = 'Request was cancelled';
}

class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);
}

class BadRequestException implements Exception {
  final String message = 'Invalid request';
}

class UnauthorizedException implements Exception {
  final String message = 'Unauthorized';
}

class ForbiddenException implements Exception {
  final String message = 'Access denied';
}

class NotFoundException implements Exception {
  final String message = 'Resource not found';
}

class ServerException implements Exception {
  final String message = 'Server error';
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
}
