// ignore_for_file: avoid_print, unused_catch_stack

import 'dart:io'; // Add this import for SocketException
import 'dart:convert';
import 'package:dio/dio.dart' as dio;
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:dio_cache_interceptor_hive_store/dio_cache_interceptor_hive_store.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/api_constants.dart';
import '../../core/utils/cached_api_handler.dart';
import '../../core/utils/error_with_translation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart' hide Response, FormData, MultipartFile;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  // Cache options
  late CacheOptions _defaultCacheOptions;
  static const Duration defaultCacheDuration = Duration(minutes: 10);

  ApiService(this._dio) {
    _dio.options.baseUrl = ApiConstants.BASE_URL;
    _dio.options.connectTimeout = const Duration(seconds: 15);
    _dio.options.receiveTimeout = const Duration(seconds: 15);

    _initializeCache();

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

  Future<void> _initializeCache() async {
    try {
      final dir = await getTemporaryDirectory();
      final cacheStore = HiveCacheStore("${dir.path}/dio_cache",
          hiveBoxName: "krishimantra_api_cache");

      _defaultCacheOptions = CacheOptions(
          store: cacheStore,
          policy: CachePolicy.refreshForceCache,
          hitCacheOnErrorExcept: [401, 403], // Do not use cache for auth errors
          maxStale:
              const Duration(days: 1), // When serving stale, accept 1 day old
          priority: CachePriority.normal,
          cipher: null,
          keyBuilder: CacheOptions.defaultCacheKeyBuilder,
          allowPostMethod: false // Allow caching POST requests too
          );

      // Add cache interceptor
      _dio.interceptors.add(DioCacheInterceptor(options: _defaultCacheOptions));
    } catch (e) {
      print('Failed to initialize cache: $e');
      // If cache initialization fails, we can still continue without caching
    }
  }

  // Creates custom cache options with a specific duration
  CacheOptions getCacheOptions({Duration? maxAge}) {
    return _defaultCacheOptions.copyWith(
      policy: CachePolicy.refreshForceCache,
      hitCacheOnErrorExcept: null,
    );
  }

  // Clear the entire cache
  Future<void> clearCache() async {
    try {
      await _defaultCacheOptions.store?.clean();
      await CachedApiHandler
          .clearAllCache(); // Also clear shared preferences cache
    } catch (e) {
      print('Failed to clear cache: $e');
    }
  }

  // Clear specific cache entries by URL pattern
  Future<void> clearCacheEntry(String urlPattern) async {
    try {
      // Currently, the cache store doesn't provide a direct way to
      // filter and delete by pattern, so we'll just clean all for now
      // Future improvements could implement selective cleaning
      await _defaultCacheOptions.store?.clean();
      await CachedApiHandler.clearCache(
          urlPattern); // Also clear specific shared preferences cache
      print('Cache cleared for pattern: $urlPattern');
    } catch (e) {
      print('Failed to clear cache for $urlPattern: $e');
    }
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

  // Enhanced GET request with caching support
  Future<dynamic> getCached(
    String path, {
    Map<String, dynamic>? queryParameters,
    Duration cacheDuration = defaultCacheDuration,
    bool forceRefresh = false,
    String? cacheKey,
    BuildContext? context,
  }) async {
    final effectiveCacheKey = cacheKey ?? path.replaceAll('/', '_');

    return CachedApiHandler.request(
      apiCall: () => _dio
          .get(
            path,
            queryParameters: queryParameters,
            options: dio.Options(
              extra: {
                'dio_cache_options': getCacheOptions(maxAge: cacheDuration),
              },
            ),
          )
          .then((response) => response.data),
      cacheKey: effectiveCacheKey,
      cacheDuration: cacheDuration,
      forceRefresh: forceRefresh,
      context: context,
    );
  }

  // Regular GET request
  Future<dio.Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    dio.Options? options,
    Duration? cacheDuration,
  }) async {
    _checkCircuitBreaker();
    try {
      dio.Options effectiveOptions = options ?? dio.Options();

      // Add cache options if cacheDuration is provided
      if (cacheDuration != null) {
        effectiveOptions.extra ??= {};
        effectiveOptions.extra!['dio_cache_options'] =
            getCacheOptions(maxAge: cacheDuration);
      }

      final response = await _dio.get(
        path,
        queryParameters: queryParameters,
        options: effectiveOptions,
      );
      _resetCircuitBreaker();
      return response;
    } catch (e) {
      _incrementFailureCount();
      rethrow;
    }
  }

  // Get response from cache directly
  Future<dio.Response?> getCachedResponse(
    String path, {
    Map<String, dynamic>? queryParameters,
    String? cacheKey,
  }) async {
    try {
      final effectiveCacheKey = cacheKey ?? path.replaceAll('/', '_');

      // Try to get cached data
      final prefs = await SharedPreferences.getInstance();
      final cachedString =
          prefs.getString('${AppConstants.CACHE_PREFIX}_$effectiveCacheKey');

      if (cachedString == null) return null;

      final cacheData = jsonDecode(cachedString);

      // Create a mock Response object
      return dio.Response(
        data: cacheData['data'],
        statusCode: 200,
        requestOptions: dio.RequestOptions(
          path: path,
          queryParameters: queryParameters,
        ),
      );
    } catch (e) {
      debugPrint('Error retrieving from cache: $e');
      return null;
    }
  }

  // Regular POST request
  Future<dio.Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    dio.Options? options,
  }) async {
    _checkCircuitBreaker();
    try {
      final response = await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      _resetCircuitBreaker();
      return response;
    } catch (e) {
      _incrementFailureCount();
      rethrow;
    }
  }

  // Regular PUT request
  Future<dio.Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    dio.Options? options,
  }) async {
    _checkCircuitBreaker();
    try {
      final response = await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      _resetCircuitBreaker();
      return response;
    } catch (e) {
      _incrementFailureCount();
      rethrow;
    }
  }

  // Regular PATCH request
  Future<dio.Response> patch(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    dio.Options? options,
  }) async {
    _checkCircuitBreaker();
    try {
      final response = await _dio.patch(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      _resetCircuitBreaker();
      return response;
    } catch (e) {
      _incrementFailureCount();
      rethrow;
    }
  }

  // Regular DELETE request
  Future<dio.Response> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    dio.Options? options,
  }) async {
    _checkCircuitBreaker();
    try {
      final response = await _dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      _resetCircuitBreaker();
      return response;
    } catch (e) {
      _incrementFailureCount();
      rethrow;
    }
  }

  // Circuit breaker pattern
  void _checkCircuitBreaker() {
    if (_circuitOpen) {
      final now = DateTime.now();
      if (_circuitOpenTime != null &&
          now.difference(_circuitOpenTime!) > _resetTimeout) {
        // Reset the circuit breaker after the timeout
        _circuitOpen = false;
        _consecutiveFailures = 0;
      } else {
        // Circuit is still open
        throw dio.DioException(
          requestOptions: dio.RequestOptions(path: ''),
          error: 'Circuit breaker is open. API requests temporarily disabled.',
          type: dio.DioExceptionType.connectionError,
        );
      }
    }
  }

  void _incrementFailureCount() {
    _consecutiveFailures++;
    if (_consecutiveFailures >= _failureThreshold) {
      _circuitOpen = true;
      _circuitOpenTime = DateTime.now();
    }
  }

  void _resetCircuitBreaker() {
    _consecutiveFailures = 0;
    _circuitOpen = false;
  }

  // Checks if we actually have internet connection by reaching a known endpoint
  Future<bool> verifyConnectivity() async {
    final connectivityResult = await _connectivity.checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      return false;
    }

    // Double-check by actually trying to reach a known endpoint
    try {
      final response = await _dio.get(
        'https://8.8.8.8', // Google's DNS - usually reachable
        options: dio.Options(
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      return response.statusCode == 200;
    } catch (e) {
      // If we can't reach Google's DNS, try another reliable service
      try {
        final response = await _dio.get(
          'https://api.github.com',
          options: dio.Options(
            sendTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 5),
          ),
        );
        return response.statusCode == 200;
      } catch (e) {
        return false;
      }
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
