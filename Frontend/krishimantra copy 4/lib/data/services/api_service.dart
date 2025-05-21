// ignore_for_file: avoid_print, unused_catch_stack

import 'dart:io'; // Add this import for SocketException
import 'package:dio/dio.dart' as dio;
import '../../core/constants/api_constants.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart' hide Response, FormData, MultipartFile;

class ApiService {
  final dio.Dio _dio;
  final Connectivity _connectivity = Connectivity();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Track if we need to refresh token
  bool _isRefreshingToken = false;
  String? _accessToken;

  // Add circuit breaker pattern properties
  bool _circuitOpen = false;
  DateTime? _circuitOpenTime;
  int _consecutiveFailures = 0;
  final int _failureThreshold = 3;
  final Duration _resetTimeout = Duration(minutes: 2);

  ApiService(this._dio) {
    _dio.options.baseUrl = ApiConstants.BASE_URL;
    _dio.options.connectTimeout = const Duration(seconds: 15);
    _dio.options.receiveTimeout =
        const Duration(seconds: 15); // Increased from 10s to 15s

    // Only log in debug mode
    assert(() {
      _dio.interceptors.add(dio.LogInterceptor(
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

    // Add auth interceptor
    _dio.interceptors.add(
      dio.InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Add auth token to all requests if available
          final token =
              _accessToken ?? await _secureStorage.read(key: 'auth_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
            _accessToken = token; // Cache token for future requests
          }
          return handler.next(options);
        },
        onError: (dio.DioException error, handler) async {
          // Handle token expiration
          if (error.response?.statusCode == 401 &&
              !_isRefreshingToken &&
              error.requestOptions.path != ApiConstants.LOGIN &&
              error.requestOptions.path != ApiConstants.REFRESH_TOKEN) {
            _isRefreshingToken = true;

            try {
              final refreshToken =
                  await _secureStorage.read(key: 'refresh_token');
              if (refreshToken != null) {
                // Try to refresh the token
                final response = await _dio.post(
                  ApiConstants.REFRESH_TOKEN,
                  data: {'refreshToken': refreshToken},
                );

                if (response.statusCode == 200 &&
                    response.data['token'] != null) {
                  final newToken = response.data['token'];
                  await _secureStorage.write(
                      key: 'auth_token', value: newToken);
                  _accessToken = newToken;

                  // Retry the original request
                  final opts = dio.Options(
                    method: error.requestOptions.method,
                    headers: {
                      ...error.requestOptions.headers,
                      'Authorization': 'Bearer $newToken',
                    },
                  );

                  final clonedRequest = await _dio.request(
                    error.requestOptions.path,
                    options: opts,
                    data: error.requestOptions.data,
                    queryParameters: error.requestOptions.queryParameters,
                  );

                  return handler.resolve(clonedRequest);
                }
              }
            } catch (e) {
              // Token refresh failed, redirect to login
              print('Token refresh failed: $e');
              _handleAuthFailure();
            } finally {
              _isRefreshingToken = false;
            }
          }
          return handler.next(error);
        },
      ),
    );
  }

  // Handle authentication failure
  void _handleAuthFailure() async {
    // Clear stored tokens
    await _secureStorage.delete(key: 'auth_token');
    await _secureStorage.delete(key: 'refresh_token');
    await _secureStorage.delete(key: 'user_data');

    // Navigate to login screen
    Get.offAllNamed('/login');
  }

  Future<bool> _checkConnectivity() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();

      // Try to actually reach a known internet endpoint to verify real connectivity
      if (connectivityResult != ConnectivityResult.none) {
        try {
          // Try to reach Google's DNS server which is highly reliable
          final response = await _dio.get('https://www.google.com',
              options: dio.Options(
                validateStatus: (status) => true,
                sendTimeout: const Duration(seconds: 5),
                receiveTimeout: const Duration(seconds: 5),
              ));
          return response.statusCode == 200;
        } catch (e) {
          // Even if we can't reach Google, let's not assume no internet
          // The specific API endpoints might still be reachable
          return true;
        }
      }

      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      // If the connectivity check itself fails, assume internet is available
      // and let the actual request determine if there's a connection issue
      return true;
    }
  }

  // Check if circuit breaker is open
  bool _isCircuitOpen() {
    if (!_circuitOpen) return false;

    // Check if reset timeout has passed
    final now = DateTime.now();
    if (_circuitOpenTime != null &&
        now.difference(_circuitOpenTime!) > _resetTimeout) {
      // Half-open the circuit to test if service is back
      _circuitOpen = false;
      _consecutiveFailures = 0;
      print('Circuit breaker reset after timeout');
      return false;
    }

    return true;
  }

  // Track failures and open circuit if needed
  void _trackFailure(dynamic error) {
    // Only track connection errors for circuit breaking
    if (error is dio.DioException) {
      final isConnectionError =
          error.type == dio.DioExceptionType.connectionError ||
              (error.error is SocketException) ||
              error.message?.toLowerCase().contains('reset') == true ||
              error.message?.toLowerCase().contains('socket') == true;

      if (isConnectionError) {
        _consecutiveFailures++;
        print('Connection failure #$_consecutiveFailures tracked');

        // Open circuit if threshold reached
        if (_consecutiveFailures >= _failureThreshold) {
          _circuitOpen = true;
          _circuitOpenTime = DateTime.now();
          print(
              'Circuit breaker opened after $_failureThreshold consecutive failures');
        }
      }
    }
  }

  // Reset failure tracking on success
  void _trackSuccess() {
    if (_consecutiveFailures > 0) {
      _consecutiveFailures = 0;
      print('Connection failure count reset after success');
    }
  }

  Future<dio.Response> get(String path,
      {Map<String, dynamic>? queryParameters, dio.Options? options}) async {
    if (_isCircuitOpen()) {
      throw ServiceUnavailableException(
          'Service temporarily unavailable, please try again later');
    }

    try {
      final response = await _dio.get(path,
          queryParameters: queryParameters, options: options);
      _trackSuccess();
      return response;
    } catch (e) {
      _trackFailure(e);
      throw _handleError(e);
    }
  }

  Future<dio.Response> post(String path,
      {dynamic data, dio.Options? options}) async {
    if (_isCircuitOpen()) {
      throw ServiceUnavailableException(
          'Service temporarily unavailable, please try again later');
    }

    try {
      final response = await _dio.post(path, data: data, options: options);
      if (response.data == null) {
        throw Exception('Received null response data');
      }
      _trackSuccess();
      return response;
    } catch (e, stackTrace) {
      _trackFailure(e);
      throw _handleError(e);
    }
  }

  Future<dio.Response> put(String path,
      {dynamic data, dio.Options? options}) async {
    if (_isCircuitOpen()) {
      throw ServiceUnavailableException(
          'Service temporarily unavailable, please try again later');
    }

    try {
      final response = await _dio.put(path, data: data, options: options);
      if (response.data == null) {
        throw Exception('Received null response data');
      }
      return response;
    } catch (e, stackTrace) {
      _trackFailure(e);
      throw _handleError(e);
    }
  }

  Future<dio.Response> delete(String path,
      {dynamic data, dio.Options? options}) async {
    if (_isCircuitOpen()) {
      throw ServiceUnavailableException(
          'Service temporarily unavailable, please try again later');
    }

    try {
      final response = await _dio.delete(path, data: data, options: options);
      if (response.data == null) {
        throw Exception('Received null response data');
      }
      return response;
    } catch (e) {
      _trackFailure(e);
      throw _handleError(e);
    }
  }

  Future<dio.Response> patch(String path,
      {dynamic data, dio.Options? options}) async {
    if (_isCircuitOpen()) {
      throw ServiceUnavailableException(
          'Service temporarily unavailable, please try again later');
    }

    try {
      final response = await _dio.patch(path, data: data, options: options);
      if (response.data == null) {
        throw Exception('Received null response data');
      }
      return response;
    } catch (e) {
      _trackFailure(e);
      throw _handleError(e);
    }
  }

  Exception _handleError(dynamic error) {
    if (error is dio.DioException) {
      switch (error.type) {
        case dio.DioExceptionType.connectionTimeout:
        case dio.DioExceptionType.sendTimeout:
        case dio.DioExceptionType.receiveTimeout:
          return RequestTimeoutException('Request timed out');
        case dio.DioExceptionType.badResponse:
          return _handleResponseError(
              error.response?.statusCode, error.response?.data);
        case dio.DioExceptionType.cancel:
          return RequestCancelledException();
        case dio.DioExceptionType.connectionError:
          // Specific handling for connection errors
          final errorMessage = error.message?.toLowerCase() ?? '';
          if (errorMessage.contains('reset') ||
              errorMessage.contains('econnreset')) {
            return ConnectionResetException(
                'Connection was reset by the server. Please try again later.');
          }
          if (errorMessage.contains('socket')) {
            return SocketException(
                'Network socket error. Please check your internet connection.');
          }
          return NoInternetException();
        default:
          // Only return NoInternetException for clear socket exceptions
          if (error.error is SocketException) {
            return NoInternetException();
          }
          // Log the error for debugging
          print('Network error: ${error.message}');
          // Default to a more general network error
          return NetworkException('Network error occurred: ${error.message}');
      }
    }
    // Log unknown errors for debugging
    print('Unknown error: $error');
    return Exception('An unexpected error occurred: $error');
  }

  Exception _handleResponseError(int? statusCode, dynamic responseData) {
    String errorMessage = 'Unknown error';

    // Try to extract error message from response
    if (responseData != null && responseData is Map) {
      errorMessage =
          responseData['message'] ?? responseData['error'] ?? errorMessage;
    }

    switch (statusCode) {
      case 400:
        return BadRequestException(errorMessage);
      case 401:
        return UnauthorizedException(errorMessage);
      case 403:
        return ForbiddenException(errorMessage);
      case 404:
        return NotFoundException(errorMessage);
      case 500:
      case 502:
      case 503:
      case 504:
        return ServerException(errorMessage);
      default:
        return ApiException(
            'API Error: ${statusCode ?? "Unknown"} - $errorMessage');
    }
  }
}

class NoInternetException implements Exception {
  final String message;
  NoInternetException([this.message = 'No internet connection available']);
  @override
  String toString() => message;
}

class RequestTimeoutException implements Exception {
  final String message;
  RequestTimeoutException(this.message);
  @override
  String toString() => message;
}

class RequestCancelledException implements Exception {
  final String message;
  RequestCancelledException([this.message = 'Request was cancelled']);
  @override
  String toString() => message;
}

class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);
  @override
  String toString() => message;
}

class ConnectionResetException implements Exception {
  final String message;
  ConnectionResetException(this.message);
  @override
  String toString() => message;
}

class ServiceUnavailableException implements Exception {
  final String message;
  ServiceUnavailableException(this.message);
  @override
  String toString() => message;
}

class BadRequestException implements Exception {
  final String message;
  BadRequestException([this.message = 'Bad request']);
}

class UnauthorizedException implements Exception {
  final String message;
  UnauthorizedException([this.message = 'Unauthorized']);
}

class ForbiddenException implements Exception {
  final String message;
  ForbiddenException([this.message = 'Access forbidden']);
}

class NotFoundException implements Exception {
  final String message;
  NotFoundException([this.message = 'Resource not found']);
}

class ServerException implements Exception {
  final String message;
  ServerException([this.message = 'Server error']);
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
}
