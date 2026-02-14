/// Application configuration that supports multiple environments
/// This replaces hardcoded URLs and makes the app production-ready
class AppConfig {
  static AppConfig? _instance;
  static AppConfig get instance => _instance ?? AppConfig._();

  AppConfig._();

  /// Initialize with a specific environment
  static void initialize(Environment env) {
    _instance = AppConfig._();
    _instance!._environment = env;
  }

  Environment _environment = Environment.development;
  Environment get environment => _environment;

  /// Development IP address - change this to your computer's local IP for physical device testing
  /// Use 'localhost' for iOS simulator, '10.0.2.2' for Android emulator
  /// Use your actual IP (e.g., '192.168.1.100') for physical device testing
  static const String _devHost = '10.33.209.39'; // Your local machine IP
  static const String _devPort = '3001';
  static const String _devSocketPort = '3004';

  /// API Base URL based on environment
  String get baseUrl {
    switch (_environment) {
      case Environment.development:
        return 'http://$_devHost:$_devPort';
      case Environment.staging:
        return 'https://staging-api.krishimantra.com';
      case Environment.production:
        return 'https://api.krishimantra.com';
    }
  }

  /// Socket URL based on environment
  String get socketUrl {
    switch (_environment) {
      case Environment.development:
        return 'http://$_devHost:$_devSocketPort';
      case Environment.staging:
        return 'https://staging-socket.krishimantra.com';
      case Environment.production:
        return 'https://socket.krishimantra.com';
    }
  }

  /// Image CDN URL
  String get imageBaseUrl => 'https://cdn.krishimantra.com';

  /// API Timeouts
  Duration get connectTimeout => const Duration(seconds: 15);
  Duration get receiveTimeout => const Duration(seconds: 30);
  Duration get uploadTimeout => const Duration(minutes: 5);

  /// Cache Durations
  Duration get shortCacheDuration => const Duration(minutes: 5);
  Duration get mediumCacheDuration => const Duration(hours: 1);
  Duration get longCacheDuration => const Duration(days: 1);

  /// Pagination
  int get defaultPageSize => 20;
  int get maxPageSize => 100;

  /// Feature Flags
  bool get enableOfflineMode => true;
  bool get enableAnalytics => _environment == Environment.production;
  bool get enableCrashlytics => _environment == Environment.production;
  bool get enableDebugLogging => _environment == Environment.development;

  /// Circuit Breaker Settings
  int get circuitBreakerThreshold => 3;
  Duration get circuitBreakerTimeout => const Duration(minutes: 2);

  /// Retry Settings
  int get maxRetries => 3;
  List<Duration> get retryDelays => const [
        Duration(seconds: 1),
        Duration(seconds: 2),
        Duration(seconds: 3),
      ];

  /// Translation Cache Settings
  Duration get translationCacheDuration => const Duration(days: 7);
  int get maxTranslationCacheEntries => 1000;
}

/// Supported environments
enum Environment {
  development,
  staging,
  production,
}

/// Extension for easy environment detection
extension EnvironmentExtension on Environment {
  bool get isDevelopment => this == Environment.development;
  bool get isStaging => this == Environment.staging;
  bool get isProduction => this == Environment.production;
}
