// ignore_for_file: constant_identifier_names

class ApiConstants {
  // Base URLs
  static const String BASE_URL = 'http://localhost:3001';
  static const String IMAGE_BASE_URL = 'https://cdn.yourapp.com';

  // Authentication endpoints
  // static const String AUTH_BASE_URL = 'http://localhost:3002';

  static const String LOGIN = '/api/main/auth/login';
  static const String REGISTER = '/api/main/auth/register';
  static const String FORGOT_PASSWORD = '/api/main/auth/forgot-password';
  static const String RESET_PASSWORD = '/api/main/auth/reset-password';
  static const String REFRESH_TOKEN = '/api/main/auth/refresh-token';

  // User endpoints
  static const String USER_PROFILE = '/api/main/user/profile';
  static const String UPDATE_PROFILE = '/api/main/user/update';

  // Feed Endpoints
  static const String FEEDS = '/feeds';

  // Company Endpoints
  static const String COMPANIES = '/companies';
  static const String COMPANY_DETAIL = '/companies/:id';

  // API Headers
  static const Map<String, String> headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // API Timeout durations
  static const int connectionTimeout = 10000; // 10 seconds
  static const int receiveTimeout = 30000; // 30 seconds

  // Update this to your actual WebSocket server URL
  static const String socketUrl = 'http://localhost:3004';
}
