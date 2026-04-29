import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';

/// Centralized logging system for the application
/// Replaces scattered print statements with structured logging
class AppLogger {
  static final AppLogger _instance = AppLogger._();
  static AppLogger get instance => _instance;

  AppLogger._();

  /// Log levels
  static const int _verbose = 0;
  static const int _debug = 1;
  static const int _info = 2;
  static const int _warning = 3;
  static const int _error = 4;

  int _minLevel = _verbose;

  /// Initialize the logger with minimum log level
  void initialize() {
    _minLevel = AppConfig.instance.enableDebugLogging ? _verbose : _warning;
  }

  /// Log a verbose message (most detailed)
  void v(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(_verbose, message, tag: tag, error: error, stackTrace: stackTrace);
  }

  /// Log a debug message
  void d(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(_debug, message, tag: tag, error: error, stackTrace: stackTrace);
  }

  /// Log an info message
  void i(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(_info, message, tag: tag, error: error, stackTrace: stackTrace);
  }

  /// Log a warning message
  void w(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(_warning, message, tag: tag, error: error, stackTrace: stackTrace);
  }

  /// Log an error message
  void e(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(_error, message, tag: tag, error: error, stackTrace: stackTrace);
  }

  /// Internal logging method
  void _log(
    int level,
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (level < _minLevel) return;

    final levelName = _getLevelName(level);
    final emoji = _getLevelEmoji(level);
    final timestamp = DateTime.now().toIso8601String();
    final tagStr = tag != null ? '[$tag] ' : '';

    final logMessage = '$emoji $levelName $tagStr$message';

    if (kDebugMode) {
      developer.log(
        logMessage,
        time: DateTime.now(),
        name: tag ?? 'Krishi Mantra',
        error: error,
        stackTrace: stackTrace,
      );
    }

    // In production, errors should be sent to a crash reporting service
    if (level >= _error && AppConfig.instance.enableCrashlytics) {
      _sendToCrashlytics(message, error, stackTrace);
    }
  }

  String _getLevelName(int level) {
    switch (level) {
      case _verbose:
        return 'VERBOSE';
      case _debug:
        return 'DEBUG';
      case _info:
        return 'INFO';
      case _warning:
        return 'WARNING';
      case _error:
        return 'ERROR';
      default:
        return 'UNKNOWN';
    }
  }

  String _getLevelEmoji(int level) {
    switch (level) {
      case _verbose:
        return '';
      case _debug:
        return '';
      case _info:
        return '';
      case _warning:
        return '';
      case _error:
        return '';
      default:
        return '';
    }
  }

  void _sendToCrashlytics(String message, Object? error, StackTrace? stackTrace) {
    // TODO: Implement Firebase Crashlytics integration
    // FirebaseCrashlytics.instance.recordError(error, stackTrace, reason: message);
  }
}

/// Convenient global logger access
AppLogger get logger => AppLogger.instance;

/// Extension methods for easy logging from any class
extension LoggerExtension on Object {
  void logVerbose(String message) => logger.v(message, tag: runtimeType.toString());
  void logDebug(String message) => logger.d(message, tag: runtimeType.toString());
  void logInfo(String message) => logger.i(message, tag: runtimeType.toString());
  void logWarning(String message) => logger.w(message, tag: runtimeType.toString());
  void logError(String message, {Object? error, StackTrace? stackTrace}) =>
      logger.e(message, tag: runtimeType.toString(), error: error, stackTrace: stackTrace);
}

/// API-specific logger for network calls
class ApiLogger {
  static void request(String method, String url, {dynamic data}) {
    logger.d('$method $url', tag: 'API');
    if (data != null && AppConfig.instance.enableDebugLogging) {
      // Handle FormData specially - don't try to print it directly
      if (data.runtimeType.toString().contains('FormData')) {
        logger.v('Request data: [FormData]', tag: 'API');
      } else {
        logger.v('Request data: $data', tag: 'API');
      }
    }
  }

  static void response(String url, int? statusCode, {dynamic data}) {
    logger.d('Response [$statusCode] $url', tag: 'API');
    if (data != null && AppConfig.instance.enableDebugLogging) {
      logger.v('Response data: $data', tag: 'API');
    }
  }

  static void error(String url, Object error, {StackTrace? stackTrace}) {
    logger.e('Error $url: $error', tag: 'API', error: error, stackTrace: stackTrace);
  }
}

/// Translation-specific logger
class TranslationLogger {
  static void translate(String original, String translated, String language) {
    logger.v('Translated "$original" -> "$translated" ($language)', tag: 'Translation');
  }

  static void cacheHit(String text) {
    logger.v('Cache hit for: "$text"', tag: 'Translation');
  }

  static void cacheMiss(String text) {
    logger.v('Cache miss for: "$text"', tag: 'Translation');
  }

  static void error(String text, Object error) {
    logger.w('Translation failed for "$text": $error', tag: 'Translation');
  }
}
