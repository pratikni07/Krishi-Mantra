// ignore_for_file: constant_identifier_names

class AppConstants {
  // App Info
  static const String APP_NAME = 'Your App Name';
  static const String APP_VERSION = '1.0.0';

  // Storage Keys
  static const String TOKEN_KEY = 'auth_token';
  static const String USER_KEY = 'user_data';
  static const String THEME_KEY = 'app_theme';
  static const String LANGUAGE_KEY = 'app_language';

  // Validation Constants
  static const int MIN_PASSWORD_LENGTH = 8;
  static const int MAX_NAME_LENGTH = 50;
  static const int OTP_LENGTH = 6;

  // Animation Durations
  static const int SPLASH_DURATION = 2000;
  static const int TOAST_DURATION = 3000;

  // Pagination
  static const int ITEMS_PER_PAGE = 20;

  // Cache Duration
  static const int CACHE_DURATION_HOURS = 24;

  // API constants
  static const String BASE_URL = 'https://krishimantra-api.vercel.app';
  static const int API_TIMEOUT = 15000; // 15 seconds

  // Cache constants
  static const String CACHE_PREFIX = 'krishi_cache';
  static const String CACHE_USER_PREFIX = 'krishi_user';
  static const String CACHE_PRODUCTS = 'products';
  static const String CACHE_FEED = 'feed';
  static const String CACHE_WEATHER = 'weather';

  // Authentication constants
  static const String AUTH_TOKEN_KEY = 'auth_token';
  static const String REFRESH_TOKEN_KEY = 'refresh_token';

  // App settings
  static const bool ENABLE_ANALYTICS = true;
  static const bool ENABLE_CRASHLYTICS = true;

  // Feature flags
  static const bool ENABLE_OFFLINE_MODE = true;
  static const bool ENABLE_NOTIFICATIONS = true;
}
