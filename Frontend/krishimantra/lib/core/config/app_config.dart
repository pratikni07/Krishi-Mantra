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

  // Build-time overrides via `--dart-define=KEY=value`. Empty string means
  // "unset" — we then fall back to the per-environment default below.
  // Keeping defaults here so builds still work without the defines, but
  // CI/release builds should always inject these explicitly.
  static const String _apiBaseUrlOverride =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');
  static const String _socketUrlOverride =
      String.fromEnvironment('SOCKET_BASE_URL', defaultValue: '');
  static const String _imageBaseUrlOverride =
      String.fromEnvironment('IMAGE_BASE_URL', defaultValue: '');
  static const String _devHost =
      String.fromEnvironment('DEV_HOST', defaultValue: 'localhost');
  static const String _devApiPort =
      String.fromEnvironment('DEV_API_PORT', defaultValue: '3001');
  static const String _devSocketPort =
      String.fromEnvironment('DEV_SOCKET_PORT', defaultValue: '3004');

  /// API Base URL based on environment
  String get baseUrl {
    if (_apiBaseUrlOverride.isNotEmpty) return _apiBaseUrlOverride;
    switch (_environment) {
      case Environment.development:
        return 'http://$_devHost:$_devApiPort';
      case Environment.staging:
        return 'https://staging-api.krishimantra.com';
      case Environment.production:
        return 'https://api.krishimantra.com';
    }
  }

  /// Socket URL based on environment
  String get socketUrl {
    if (_socketUrlOverride.isNotEmpty) return _socketUrlOverride;
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
  String get imageBaseUrl => _imageBaseUrlOverride.isNotEmpty
      ? _imageBaseUrlOverride
      : 'https://cdn.krishimantra.com';

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
