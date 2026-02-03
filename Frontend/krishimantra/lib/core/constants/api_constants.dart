import '../config/app_config.dart';

/// API Constants - Now uses AppConfig for environment-aware URLs
/// This file defines all API endpoints and configuration
class ApiConstants {
  ApiConstants._();

  // Base URLs - Now read from AppConfig
  static String get BASE_URL => AppConfig.instance.baseUrl;
  static String get IMAGE_BASE_URL => AppConfig.instance.imageBaseUrl;
  static String get socketUrl => AppConfig.instance.socketUrl;

  // Authentication endpoints
  static const String LOGIN = '/api/main/auth/login';
  static const String REGISTER = '/api/main/auth/signup';
  static const String FORGOT_PASSWORD = '/api/main/auth/forgot-password';
  static const String RESET_PASSWORD = '/api/main/auth/reset-password';
  static const String REFRESH_TOKEN = '/api/main/auth/refresh-token';

  // Phone auth endpoints
  static const String INITIATE_AUTH = '/api/main/auth/initiate-auth';
  static const String VERIFY_OTP = '/api/main/auth/verify-otp';
  static const String SIGNUP_WITH_PHONE = '/api/main/auth/signup-with-phone';

  // Upload endpoints
  static const String UPLOAD_IMAGE = '/upload/image';
  static const String GET_PRESIGNED_URL = '/api/upload/getPresignedUrl';

  // User endpoints
  static const String USER_PROFILE = '/api/main/user/profile';
  static const String UPDATE_PROFILE = '/api/main/user/update';

  // Feed Endpoints
  static const String FEEDS = '/api/feed/feeds';
  static const String FEED_BY_ID = '/api/feed/feeds/:id';
  static const String FEED_LIKE = '/api/feed/feeds/:id/like';
  static const String FEED_COMMENT = '/api/feed/feeds/:id/comment';
  static const String FEED_COMMENTS = '/api/feed/comments/getComment';
  static const String FEED_RANDOM = '/api/feed/feeds/feeds/random';
  static const String FEED_RECOMMENDED = '/api/feed/feeds/user/:userId/recommended';
  static const String FEED_TOP = '/api/feed/feeds/getoptwo';
  static const String FEED_TRENDING_HASHTAGS = '/api/feed/feeds/trending/hashtags';
  static const String FEED_BY_TAG = '/api/feed/feeds/tag/:tagName/feeds';
  static const String USER_STATS = '/api/feed/feeds/user/:userId/stats';
  static const String FEED_USER_INTEREST = '/api/feed/feeds/user/interest';
  static const String FEED_USER_INTERACTION = '/api/feed/feeds/user/interaction';
  static const String FEED_SYNC_INTERESTS = '/api/feed/feeds/user/sync-interests';

  // Company Endpoints
  static const String COMPANIES = '/api/main/companies';
  static const String COMPANY_DETAIL = '/api/main/companies/:id';

  // Product Endpoints
  static const String PRODUCTS = '/api/main/products';
  static const String PRODUCT_DETAIL = '/api/main/products/:id';
  static const String PRODUCTS_BY_CATEGORY = '/api/main/products/category/:category';

  // Marketplace Endpoints
  static const String MARKETPLACE = '/api/main/marketplace';
  static const String MARKETPLACE_PRODUCT = '/api/main/marketplace/:id';
  static const String MARKETPLACE_COMMENTS = '/api/main/marketplace/:id/comments';

  // Reel Endpoints
  static const String REELS = '/api/reels';
  static const String REEL_BY_ID = '/api/reels/:id';
  static const String REEL_COMMENTS = '/api/reels/:id/comments';
  static const String REEL_LIKE = '/api/reels/:id/like';
  static const String REEL_TRENDING_TAGS = '/api/reels/trending/tags';
  static const String REEL_BY_TAG = '/api/reels/tag/:tagName';

  // Video Tutorial Endpoints
  static const String VIDEO_TUTORIALS = '/api/reels/videos';
  static const String VIDEO_TUTORIAL_DETAIL = '/api/reels/videos/:id';
  static const String VIDEO_TUTORIAL_COMMENTS = '/api/reels/videos/:id/comments';
  static const String VIDEO_TUTORIAL_LIKE = '/api/reels/videos/:id/like';
  static const String VIDEO_TUTORIAL_RELATED = '/api/reels/videos/:id/related';

  // Crop Endpoints
  static const String CROPS = '/api/main/crops';
  static const String CROP_DETAIL = '/api/main/crops/:id';
  static const String CROP_CALENDAR = '/api/main/crops/:id/calendar';

  // Scheme Endpoints
  static const String SCHEMES = '/api/main/schemes';
  static const String SCHEME_DETAIL = '/api/main/schemes/:id';
  static const String SCHEME_SEARCH = '/api/main/schemes/search';

  // AI Chat Endpoints
  static const String AI_CHAT = '/api/ai/chat';
  static const String AI_CHAT_HISTORY = '/api/ai/chat/history';
  static const String AI_CHAT_CLEAR = '/api/ai/chat/clear';

  // Message Endpoints
  static const String MESSAGES = '/api/messages/api/message';
  static const String CHATS = '/api/messages/api/chat';
  static const String CHAT_DIRECT = '/api/messages/api/chat/direct';
  static const String MESSAGES_BY_CHAT = '/api/messages/api/message/chat/:chatId';
  static const String MESSAGE_READ = '/api/messages/api/message/:id/read';

  // Notification Endpoints
  static const String NOTIFICATIONS = '/api/main/notifications';
  static const String NOTIFICATION_READ = '/api/main/notifications/:id/read';
  static const String NOTIFICATION_PREFERENCES = '/api/main/notifications/preferences';

  // Ads Endpoints
  static const String ADS = '/api/main/ads';
  static const String ADS_BY_PLACEMENT = '/api/main/ads/placement/:placement';
  static const String ADS_FEED = '/api/main/ads/feed';

  // Weather Endpoints
  static const String WEATHER = '/api/main/weather';
  static const String WEATHER_FORECAST = '/api/main/weather/forecast';

  // Consultant Endpoints
  static const String CONSULTANTS = '/api/main/consultants';
  static const String CONSULTANT_DETAIL = '/api/main/consultants/:id';

  // API Headers
  static const Map<String, String> headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // API Timeout durations (now from AppConfig)
  static int get connectionTimeout => AppConfig.instance.connectTimeout.inMilliseconds;
  static int get receiveTimeout => AppConfig.instance.receiveTimeout.inMilliseconds;

  /// Helper method to replace path parameters
  static String replacePathParams(String path, Map<String, String> params) {
    String result = path;
    params.forEach((key, value) {
      result = result.replaceAll(':$key', value);
    });
    return result;
  }
}
