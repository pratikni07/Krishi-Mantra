/**
 * Application constants
 */

// Cache TTL (Time To Live) in seconds
const CACHE_TTL = {
  SHORT: 300,        // 5 minutes
  MEDIUM: 1800,      // 30 minutes
  LONG: 3600,        // 1 hour
  VERY_LONG: 86400,  // 24 hours
};

// Cache key prefixes
const CACHE_KEYS = {
  // User related
  USER: 'user',
  USERS_PAGE: 'users:page',
  CONSULTANTS: 'consultants',

  // Content related
  NEWS: 'news',
  NEWS_ALL: 'news:all',
  NEWS_SEARCH: 'news:search',

  // Product/Company related
  COMPANIES: 'companies',
  PRODUCTS: 'products',
  MARKETPLACE: 'marketplace',

  // Crop related
  CROPS: 'crops',
  CROPS_ALL: 'all_crops',
  CROP_CALENDAR: 'calendar',
  ACTIVITIES: 'all_activities',
  REGIONS: 'all_regions',

  // Services/Schemes
  SERVICES: 'all_services',
  SCHEMES: 'schemes',

  // Ads
  HOME_ADS: 'home_ads',
  FEED_ADS: 'feed_ads',
  REEL_ADS: 'reel_ads',
  NEWS_ADS: 'news_ads',
  HOME_SCREEN_ADS: 'HomeScreenAds',
  SPLASH_MODAL: 'SplashModal',
  DISPLAY: 'display',
};

// Pagination defaults
const PAGINATION = {
  DEFAULT_PAGE: 1,
  DEFAULT_LIMIT: 10,
  MAX_LIMIT: 100,
};

// Account types
const ACCOUNT_TYPES = {
  USER: 'user',
  CONSULTANT: 'consultant',
  ADMIN: 'admin',
  MARKETPLACE: 'marketplace',
};

// Subscription types
const SUBSCRIPTION_TYPES = {
  FREE: 'FREE',
  PRIME: 'PRIME',
  MEGA: 'MEGA',
};

// OTP settings
const OTP_CONFIG = {
  LENGTH: 6,
  EXPIRY_MINUTES: 10,
  MAX_ATTEMPTS: 3,
};

// JWT settings
const JWT_CONFIG = {
  ACCESS_TOKEN_EXPIRY: '15m',
  REFRESH_TOKEN_EXPIRY: '30d',
  // Cookie covers refresh-token lifetime so browser clients don't get
  // logged out mid-session; the access token inside it still expires
  // per ACCESS_TOKEN_EXPIRY above.
  COOKIE_EXPIRY_DAYS: 30,
};

// Rate limiting - optimized for 10k users
const RATE_LIMIT = {
  WINDOW_MS: 60 * 1000, // 1 minute
  MAX_REQUESTS: 100,    // 100 requests per minute per IP
};

// Database configuration - optimized for 10k concurrent users
const DB_CONFIG = {
  MAX_POOL_SIZE: 100,
  MIN_POOL_SIZE: 20,
  SOCKET_TIMEOUT_MS: 45000,
  SERVER_SELECTION_TIMEOUT_MS: 10000,
  HEARTBEAT_FREQUENCY_MS: 10000,
  MAX_IDLE_TIME_MS: 30000,
};

// File upload limits
const FILE_UPLOAD = {
  MAX_SIZE_MB: 10,
  ALLOWED_IMAGE_TYPES: ['image/jpeg', 'image/png', 'image/gif', 'image/webp'],
  ALLOWED_VIDEO_TYPES: ['video/mp4', 'video/webm', 'video/quicktime'],
};

// HTTP status codes
const HTTP_STATUS = {
  OK: 200,
  CREATED: 201,
  NO_CONTENT: 204,
  BAD_REQUEST: 400,
  UNAUTHORIZED: 401,
  FORBIDDEN: 403,
  NOT_FOUND: 404,
  CONFLICT: 409,
  UNPROCESSABLE_ENTITY: 422,
  TOO_MANY_REQUESTS: 429,
  INTERNAL_SERVER_ERROR: 500,
  SERVICE_UNAVAILABLE: 503,
};

module.exports = {
  CACHE_TTL,
  CACHE_KEYS,
  PAGINATION,
  ACCOUNT_TYPES,
  SUBSCRIPTION_TYPES,
  OTP_CONFIG,
  JWT_CONFIG,
  RATE_LIMIT,
  DB_CONFIG,
  FILE_UPLOAD,
  HTTP_STATUS,
};
