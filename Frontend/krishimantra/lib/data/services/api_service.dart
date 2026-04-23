import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart' as dio;
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:dio_cache_interceptor_hive_store/dio_cache_interceptor_hive_store.dart';
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart' hide Response, FormData, MultipartFile;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/api_constants.dart';
import '../../core/config/app_config.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/cached_api_handler.dart';

/// Thread-safe token refresh lock
class TokenRefreshLock {
  Completer<bool>? _completer;
  bool _isRefreshing = false;

  /// Returns true if token was refreshed successfully
  Future<bool> synchronized(Future<bool> Function() refreshOperation) async {
    // If already refreshing, wait for the result
    if (_isRefreshing && _completer != null) {
      logger.d('Waiting for ongoing token refresh', tag: 'Auth');
      return _completer!.future;
    }

    _isRefreshing = true;
    _completer = Completer<bool>();

    try {
      final result = await refreshOperation();
      _completer!.complete(result);
      return result;
    } catch (e) {
      _completer!.completeError(e);
      return false;
    } finally {
      _isRefreshing = false;
      _completer = null;
    }
  }

  bool get isRefreshing => _isRefreshing;
}

/// Per-endpoint circuit breaker for better fault isolation
class EndpointCircuitBreaker {
  final Map<String, _CircuitState> _circuits = {};
  final int failureThreshold;
  final Duration resetTimeout;

  EndpointCircuitBreaker({
    this.failureThreshold = 3,
    this.resetTimeout = const Duration(minutes: 2),
  });

  bool isOpen(String endpoint) {
    final circuit = _circuits[_normalizeEndpoint(endpoint)];
    if (circuit == null) return false;

    if (circuit.isOpen && DateTime.now().difference(circuit.openedAt!) > resetTimeout) {
      // Reset circuit after timeout
      _circuits.remove(_normalizeEndpoint(endpoint));
      return false;
    }

    return circuit.isOpen;
  }

  void recordSuccess(String endpoint) {
    final normalized = _normalizeEndpoint(endpoint);
    _circuits[normalized] = _CircuitState(failures: 0);
  }

  void recordFailure(String endpoint) {
    final normalized = _normalizeEndpoint(endpoint);
    final circuit = _circuits[normalized] ?? _CircuitState(failures: 0);

    final newFailures = circuit.failures + 1;
    if (newFailures >= failureThreshold) {
      _circuits[normalized] = _CircuitState(
        failures: newFailures,
        isOpen: true,
        openedAt: DateTime.now(),
      );
      logger.w('Circuit opened for endpoint: $normalized', tag: 'CircuitBreaker');
    } else {
      _circuits[normalized] = _CircuitState(failures: newFailures);
    }
  }

  String _normalizeEndpoint(String endpoint) {
    // Normalize endpoints by removing IDs and query params
    return endpoint.replaceAll(RegExp(r'/[a-f0-9]{24}'), '/:id').split('?').first;
  }
}

class _CircuitState {
  final int failures;
  final bool isOpen;
  final DateTime? openedAt;

  _CircuitState({
    required this.failures,
    this.isOpen = false,
    this.openedAt,
  });
}

/// Main API Service with improved architecture
class ApiService {
  final dio.Dio _dio;
  final Connectivity _connectivity = Connectivity();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Thread-safe token refresh
  final TokenRefreshLock _tokenRefreshLock = TokenRefreshLock();
  String? _accessToken;

  // Per-endpoint circuit breaker
  late final EndpointCircuitBreaker _circuitBreaker;

  // Cache options
  late CacheOptions _defaultCacheOptions;
  bool _cacheInitialized = false;

  ApiService(this._dio) {
    _circuitBreaker = EndpointCircuitBreaker(
      failureThreshold: AppConfig.instance.circuitBreakerThreshold,
      resetTimeout: AppConfig.instance.circuitBreakerTimeout,
    );

    _dio.options.baseUrl = ApiConstants.BASE_URL;
    _dio.options.connectTimeout = AppConfig.instance.connectTimeout;
    _dio.options.receiveTimeout = AppConfig.instance.receiveTimeout;

    _initializeInterceptors();
  }

  void _initializeInterceptors() {
    // Initialize cache asynchronously
    _initializeCache();

    // Add logging interceptor only in debug mode
    if (AppConfig.instance.enableDebugLogging) {
      _dio.interceptors.add(dio.InterceptorsWrapper(
        onRequest: (options, handler) {
          ApiLogger.request(options.method, options.path, data: options.data);
          return handler.next(options);
        },
        onResponse: (response, handler) {
          ApiLogger.response(response.requestOptions.path, response.statusCode);
          return handler.next(response);
        },
        onError: (error, handler) {
          ApiLogger.error(error.requestOptions.path, error);
          return handler.next(error);
        },
      ));
    }

    // Add retry interceptor (exclude multipart requests - they handle their own retries)
    _dio.interceptors.add(
      RetryInterceptor(
        dio: _dio,
        retries: AppConfig.instance.maxRetries,
        retryDelays: AppConfig.instance.retryDelays,
        retryEvaluator: (error, attempt) {
          // Don't retry multipart/form-data requests here - they have their own retry logic
          final contentType = error.requestOptions.contentType;
          if (contentType != null && contentType.contains('multipart/form-data')) {
            return false;
          }
          // Default retry behavior for other requests
          return error.type != dio.DioExceptionType.cancel &&
              error.type != dio.DioExceptionType.badResponse;
        },
      ),
    );

    // Add auth interceptor
    _dio.interceptors.add(
      dio.InterceptorsWrapper(
        onRequest: _handleRequest,
        onError: _handleError,
      ),
    );
  }

  Future<void> _handleRequest(
    dio.RequestOptions options,
    dio.RequestInterceptorHandler handler,
  ) async {
    // Check circuit breaker
    if (_circuitBreaker.isOpen(options.path)) {
      return handler.reject(
        dio.DioException(
          requestOptions: options,
          error: 'Circuit breaker open for ${options.path}',
          type: dio.DioExceptionType.connectionError,
        ),
      );
    }

    // Add auth token
    final token = _accessToken ?? await _secureStorage.read(key: 'auth_token');
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
      _accessToken = token;
    }

    return handler.next(options);
  }

  Future<void> _handleError(
    dio.DioException error,
    dio.ErrorInterceptorHandler handler,
  ) async {
    // Handle token expiration with thread-safe refresh
    if (_shouldRefreshToken(error)) {
      try {
        final success = await _tokenRefreshLock.synchronized(() async {
          return await _refreshToken();
        });

        if (success) {
          // Retry the original request
          final response = await _retryRequest(error.requestOptions);
          return handler.resolve(response);
        }
      } catch (e) {
        logger.e('Token refresh failed: $e', tag: 'Auth');
        _handleAuthFailure();
      }
    }

    // Record failure for circuit breaker
    _circuitBreaker.recordFailure(error.requestOptions.path);

    return handler.next(error);
  }

  bool _shouldRefreshToken(dio.DioException error) {
    return error.response?.statusCode == 401 &&
        !_tokenRefreshLock.isRefreshing &&
        error.requestOptions.path != ApiConstants.LOGIN &&
        error.requestOptions.path != ApiConstants.REFRESH_TOKEN;
  }

  Future<bool> _refreshToken() async {
    try {
      final refreshToken = await _secureStorage.read(key: 'refresh_token');
      if (refreshToken == null) return false;

      final response = await _dio.post(
        ApiConstants.REFRESH_TOKEN,
        data: {'refreshToken': refreshToken},
      );

      if (response.statusCode == 200 && response.data['token'] != null) {
        final newToken = response.data['token'];
        await _secureStorage.write(key: 'auth_token', value: newToken);
        _accessToken = newToken;

        // Server rotates the refresh token on every use — persist the
        // new one so the next refresh doesn't replay the consumed token
        // (which the server treats as theft and revokes everything).
        final newRefresh = response.data['refreshToken'];
        if (newRefresh != null) {
          await _secureStorage.write(key: 'refresh_token', value: newRefresh as String);
        }

        logger.i('Token refreshed successfully', tag: 'Auth');
        return true;
      }

      return false;
    } catch (e) {
      logger.e('Token refresh error: $e', tag: 'Auth');
      return false;
    }
  }

  Future<dio.Response> _retryRequest(dio.RequestOptions requestOptions) async {
    final opts = dio.Options(
      method: requestOptions.method,
      headers: {
        ...requestOptions.headers,
        'Authorization': 'Bearer $_accessToken',
      },
    );

    return await _dio.request(
      requestOptions.path,
      options: opts,
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
    );
  }

  Future<void> _initializeCache() async {
    if (_cacheInitialized) return;

    try {
      final dir = await getTemporaryDirectory();
      final cacheStore = HiveCacheStore(
        "${dir.path}/dio_cache",
        hiveBoxName: "krishimantra_api_cache",
      );

      _defaultCacheOptions = CacheOptions(
        store: cacheStore,
        policy: CachePolicy.refreshForceCache,
        hitCacheOnErrorExcept: [401, 403],
        maxStale: AppConfig.instance.longCacheDuration,
        priority: CachePriority.normal,
        cipher: null,
        keyBuilder: CacheOptions.defaultCacheKeyBuilder,
        allowPostMethod: false,
      );

      _dio.interceptors.add(DioCacheInterceptor(options: _defaultCacheOptions));
      _cacheInitialized = true;
      logger.i('Cache initialized successfully', tag: 'API');
    } catch (e) {
      logger.w('Failed to initialize cache: $e', tag: 'API');
    }
  }

  CacheOptions getCacheOptions({Duration? maxAge}) {
    return _defaultCacheOptions.copyWith(
      policy: CachePolicy.refreshForceCache,
      hitCacheOnErrorExcept: null,
    );
  }

  Future<void> clearCache() async {
    try {
      await _defaultCacheOptions.store?.clean();
      await CachedApiHandler.clearAllCache();
      logger.i('Cache cleared', tag: 'API');
    } catch (e) {
      logger.w('Failed to clear cache: $e', tag: 'API');
    }
  }

  Future<void> clearCacheEntry(String urlPattern) async {
    try {
      await _defaultCacheOptions.store?.clean();
      await CachedApiHandler.clearCache(urlPattern);
      logger.d('Cache cleared for pattern: $urlPattern', tag: 'API');
    } catch (e) {
      logger.w('Failed to clear cache for $urlPattern: $e', tag: 'API');
    }
  }

  void _handleAuthFailure() async {
    await _secureStorage.delete(key: 'auth_token');
    await _secureStorage.delete(key: 'refresh_token');
    await _secureStorage.delete(key: 'user_data');
    _accessToken = null;

    Get.offAllNamed('/login');
    logger.i('User logged out due to auth failure', tag: 'Auth');
  }

  // Enhanced GET request with caching support
  Future<dynamic> getCached(
    String path, {
    Map<String, dynamic>? queryParameters,
    Duration? cacheDuration,
    bool forceRefresh = false,
    String? cacheKey,
  }) async {
    final effectiveCacheKey = cacheKey ?? path.replaceAll('/', '_');
    final effectiveDuration = cacheDuration ?? AppConfig.instance.mediumCacheDuration;

    return CachedApiHandler.request(
      apiCall: () => _dio
          .get(
            path,
            queryParameters: queryParameters,
            options: dio.Options(
              extra: {'dio_cache_options': getCacheOptions(maxAge: effectiveDuration)},
            ),
          )
          .then((response) => response.data),
      cacheKey: effectiveCacheKey,
      cacheDuration: effectiveDuration,
      forceRefresh: forceRefresh,
    );
  }

  // Regular GET request
  Future<dio.Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    dio.Options? options,
    Duration? cacheDuration,
  }) async {
    try {
      dio.Options effectiveOptions = options ?? dio.Options();

      if (cacheDuration != null) {
        effectiveOptions.extra ??= {};
        effectiveOptions.extra!['dio_cache_options'] = getCacheOptions(maxAge: cacheDuration);
      }

      final response = await _dio.get(
        path,
        queryParameters: queryParameters,
        options: effectiveOptions,
      );

      _circuitBreaker.recordSuccess(path);
      return response;
    } catch (e) {
      _circuitBreaker.recordFailure(path);
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
      final prefs = await SharedPreferences.getInstance();
      final cachedString = prefs.getString('${AppConstants.CACHE_PREFIX}_$effectiveCacheKey');

      if (cachedString == null) return null;

      final cacheData = jsonDecode(cachedString);
      return dio.Response(
        data: cacheData['data'],
        statusCode: 200,
        requestOptions: dio.RequestOptions(
          path: path,
          queryParameters: queryParameters,
        ),
      );
    } catch (e) {
      logger.d('Error retrieving from cache: $e', tag: 'API');
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
    try {
      final response = await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      _circuitBreaker.recordSuccess(path);
      return response;
    } catch (e) {
      _circuitBreaker.recordFailure(path);
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
    try {
      final response = await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      _circuitBreaker.recordSuccess(path);
      return response;
    } catch (e) {
      _circuitBreaker.recordFailure(path);
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
    try {
      final response = await _dio.patch(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      _circuitBreaker.recordSuccess(path);
      return response;
    } catch (e) {
      _circuitBreaker.recordFailure(path);
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
    try {
      final response = await _dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      _circuitBreaker.recordSuccess(path);
      return response;
    } catch (e) {
      _circuitBreaker.recordFailure(path);
      rethrow;
    }
  }

  // Check connectivity
  Future<bool> verifyConnectivity() async {
    final connectivityResult = await _connectivity.checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      return false;
    }

    try {
      final response = await _dio.get(
        'https://8.8.8.8',
        options: dio.Options(
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      return response.statusCode == 200;
    } catch (e) {
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

// Exception classes
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
  @override
  String toString() => message;
}

class UnauthorizedException implements Exception {
  final String message;
  UnauthorizedException([this.message = 'Unauthorized']);
  @override
  String toString() => message;
}

class ForbiddenException implements Exception {
  final String message;
  ForbiddenException([this.message = 'Access forbidden']);
  @override
  String toString() => message;
}

class NotFoundException implements Exception {
  final String message;
  NotFoundException([this.message = 'Resource not found']);
  @override
  String toString() => message;
}

class ServerException implements Exception {
  final String message;
  ServerException([this.message = 'Server error']);
  @override
  String toString() => message;
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}
