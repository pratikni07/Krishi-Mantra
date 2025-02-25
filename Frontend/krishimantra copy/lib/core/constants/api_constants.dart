// ignore_for_file: constant_identifier_names

class ApiConstants {
  // Base URLs
  static const String BASE_URL = 'http://localhost:3004';
  static const String IMAGE_BASE_URL = 'https://cdn.yourapp.com';

  // Authentication endpoints
  // static const String AUTH_BASE_URL = 'http://localhost:3002';

  static const String LOGIN = '/auth/login';
  static const String REGISTER = '/auth/register';
  static const String FORGOT_PASSWORD = '/auth/forgot-password';
  static const String RESET_PASSWORD = '/auth/reset-password';
  static const String REFRESH_TOKEN = '/auth/refresh-token';

  // User endpoints
  static const String USER_PROFILE = '/user/profile';
  static const String UPDATE_PROFILE = '/user/update';

  // Feed Endpoints
  static const String FEEDS = '/feeds';

  // API Headers
  static const Map<String, String> headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // API Timeout durations
  static const int connectionTimeout = 30000; // 30 seconds
  static const int receiveTimeout = 30000; // 30 seconds
}
