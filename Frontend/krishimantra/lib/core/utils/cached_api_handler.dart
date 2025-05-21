import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'error_handler.dart';
import 'error_with_translation.dart';

/// A utility class for handling API requests with caching and error handling
class CachedApiHandler {
  // Cache expiry durations
  static const Duration shortCache = Duration(minutes: 5);
  static const Duration mediumCache = Duration(hours: 1);
  static const Duration longCache = Duration(days: 1);

  /// Make an API request with caching support
  /// Returns data from cache if available and not expired, otherwise makes the API call
  static Future<dynamic> request({
    required Future<dynamic> Function() apiCall,
    required String cacheKey,
    required Duration cacheDuration,
    bool forceRefresh = false,
    Widget Function(dynamic error)? errorWidget,
    BuildContext? context,
  }) async {
    try {
      // Check connectivity first
      final connectivityResult = await Connectivity().checkConnectivity();
      final bool hasConnectivity =
          connectivityResult != ConnectivityResult.none;

      // Try to get from cache if not forcing refresh
      if (!forceRefresh) {
        final cachedData = await _getCachedData(cacheKey);
        if (cachedData != null) {
          debugPrint('✅ Using cached data for $cacheKey');
          return cachedData;
        }
      }

      // If no connectivity, throw a specific error
      if (!hasConnectivity) {
        throw DioException(
          requestOptions: RequestOptions(path: ''),
          type: DioExceptionType.connectionError,
          error: 'No internet connection',
        );
      }

      // Make the API call
      final response = await apiCall();

      // Cache the successful response
      await _cacheData(cacheKey, response, cacheDuration);

      return response;
    } catch (error) {
      // Log the error
      debugPrint('❌ API Error: $error');

      // Try to get data from cache even if expired (as fallback)
      final cachedData = await _getCachedData(cacheKey, ignoreExpiry: true);
      if (cachedData != null) {
        debugPrint('⚠️ Using expired cached data for $cacheKey due to error');
        return cachedData;
      }

      // Display error if context is provided
      if (context != null && context.mounted) {
        await TranslatedErrorHandler.showError(error, context: context);
      }

      // Rethrow the error for handling by the caller
      rethrow;
    }
  }

  /// Cache data with expiry time
  static Future<void> _cacheData(
      String key, dynamic data, Duration duration) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final expiryTime = DateTime.now().add(duration).millisecondsSinceEpoch;

      final Map<String, dynamic> cacheData = {
        'data': data,
        'expiry': expiryTime,
      };

      await prefs.setString(
        '${AppConstants.CACHE_PREFIX}_$key',
        jsonEncode(cacheData),
      );
    } catch (e) {
      debugPrint('❌ Caching error: $e');
    }
  }

  /// Get cached data if not expired
  static Future<dynamic> _getCachedData(String key,
      {bool ignoreExpiry = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedString = prefs.getString('${AppConstants.CACHE_PREFIX}_$key');

      if (cachedString == null) return null;

      final cacheData = jsonDecode(cachedString);
      final expiryTime = cacheData['expiry'] as int;

      // Check if the cache has expired, unless we're ignoring expiry
      if (!ignoreExpiry && DateTime.now().millisecondsSinceEpoch > expiryTime) {
        debugPrint('⚠️ Cache expired for $key');
        return null;
      }

      return cacheData['data'];
    } catch (e) {
      debugPrint('❌ Cache retrieval error: $e');
      return null;
    }
  }

  /// Clear a specific cache entry
  static Future<void> clearCache(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('${AppConstants.CACHE_PREFIX}_$key');
    } catch (e) {
      debugPrint('❌ Cache clearing error: $e');
    }
  }

  /// Clear all cached data
  static Future<void> clearAllCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();

      for (final key in keys) {
        if (key.startsWith(AppConstants.CACHE_PREFIX)) {
          await prefs.remove(key);
        }
      }
    } catch (e) {
      debugPrint('❌ Cache clearing error: $e');
    }
  }
}
