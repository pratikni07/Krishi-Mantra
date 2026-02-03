/**
 * Engagement Service Constants
 * Production-ready constants for 100k+ users
 */

// Event categories
const EVENT_CATEGORIES = {
  NAVIGATION: 'navigation',
  ENGAGEMENT: 'engagement',
  CONTENT: 'content',
  SOCIAL: 'social',
  COMMERCE: 'commerce',
  COMMUNICATION: 'communication',
  AI: 'ai',
  SYSTEM: 'system',
};

// Event names with their categories
const EVENT_NAMES = {
  // Navigation events
  SCREEN_VIEW: { name: 'screen_view', category: EVENT_CATEGORIES.NAVIGATION },
  APP_OPEN: { name: 'app_open', category: EVENT_CATEGORIES.NAVIGATION },
  APP_CLOSE: { name: 'app_close', category: EVENT_CATEGORIES.NAVIGATION },
  APP_BACKGROUND: { name: 'app_background', category: EVENT_CATEGORIES.NAVIGATION },
  APP_FOREGROUND: { name: 'app_foreground', category: EVENT_CATEGORIES.NAVIGATION },

  // Feed events
  FEED_VIEW: { name: 'feed_view', category: EVENT_CATEGORIES.CONTENT },
  FEED_LIKE: { name: 'feed_like', category: EVENT_CATEGORIES.ENGAGEMENT },
  FEED_UNLIKE: { name: 'feed_unlike', category: EVENT_CATEGORIES.ENGAGEMENT },
  FEED_COMMENT: { name: 'feed_comment', category: EVENT_CATEGORIES.SOCIAL },
  FEED_SHARE: { name: 'feed_share', category: EVENT_CATEGORIES.SOCIAL },
  FEED_CREATE: { name: 'feed_create', category: EVENT_CATEGORIES.CONTENT },
  FEED_SCROLL: { name: 'feed_scroll', category: EVENT_CATEGORIES.ENGAGEMENT },

  // Reel events
  REEL_VIEW: { name: 'reel_view', category: EVENT_CATEGORIES.CONTENT },
  REEL_LIKE: { name: 'reel_like', category: EVENT_CATEGORIES.ENGAGEMENT },
  REEL_COMMENT: { name: 'reel_comment', category: EVENT_CATEGORIES.SOCIAL },
  REEL_SHARE: { name: 'reel_share', category: EVENT_CATEGORIES.SOCIAL },
  REEL_COMPLETE: { name: 'reel_complete', category: EVENT_CATEGORIES.ENGAGEMENT },
  REEL_SKIP: { name: 'reel_skip', category: EVENT_CATEGORIES.ENGAGEMENT },

  // Product events
  PRODUCT_VIEW: { name: 'product_view', category: EVENT_CATEGORIES.COMMERCE },
  PRODUCT_SEARCH: { name: 'product_search', category: EVENT_CATEGORIES.COMMERCE },
  PRODUCT_ADD_CART: { name: 'product_add_cart', category: EVENT_CATEGORIES.COMMERCE },
  PRODUCT_PURCHASE: { name: 'product_purchase', category: EVENT_CATEGORIES.COMMERCE },
  PRODUCT_INQUIRY: { name: 'product_inquiry', category: EVENT_CATEGORIES.COMMERCE },

  // Chat events
  CHAT_OPEN: { name: 'chat_open', category: EVENT_CATEGORIES.COMMUNICATION },
  CHAT_MESSAGE_SENT: { name: 'chat_message_sent', category: EVENT_CATEGORIES.COMMUNICATION },
  CHAT_MESSAGE_RECEIVED: { name: 'chat_message_received', category: EVENT_CATEGORIES.COMMUNICATION },

  // AI events
  AI_CHAT_START: { name: 'ai_chat_start', category: EVENT_CATEGORIES.AI },
  AI_CHAT_MESSAGE: { name: 'ai_chat_message', category: EVENT_CATEGORIES.AI },
  AI_CROP_SCAN: { name: 'ai_crop_scan', category: EVENT_CATEGORIES.AI },

  // Other feature events
  SCHEME_VIEW: { name: 'scheme_view', category: EVENT_CATEGORIES.CONTENT },
  WEATHER_CHECK: { name: 'weather_check', category: EVENT_CATEGORIES.CONTENT },
  CROP_CALENDAR_VIEW: { name: 'crop_calendar_view', category: EVENT_CATEGORIES.CONTENT },
  VIDEO_TUTORIAL_VIEW: { name: 'video_tutorial_view', category: EVENT_CATEGORIES.CONTENT },
  NOTIFICATION_CLICK: { name: 'notification_click', category: EVENT_CATEGORIES.ENGAGEMENT },
  NOTIFICATION_RECEIVED: { name: 'notification_received', category: EVENT_CATEGORIES.SYSTEM },

  // User events
  USER_LOGIN: { name: 'user_login', category: EVENT_CATEGORIES.SYSTEM },
  USER_LOGOUT: { name: 'user_logout', category: EVENT_CATEGORIES.SYSTEM },
  USER_SIGNUP: { name: 'user_signup', category: EVENT_CATEGORIES.SYSTEM },
  USER_PROFILE_UPDATE: { name: 'user_profile_update', category: EVENT_CATEGORIES.SYSTEM },
};

// Screen names for tracking
const SCREENS = {
  HOME: 'home',
  FEED: 'feed',
  FEED_DETAILS: 'feed_details',
  REELS: 'reels',
  MARKETPLACE: 'marketplace',
  PRODUCT_DETAILS: 'product_details',
  CHAT_LIST: 'chat_list',
  CHAT_DETAIL: 'chat_detail',
  AI_CHAT: 'ai_chat',
  CROP_CALENDAR: 'crop_calendar',
  CROP_DETAILS: 'crop_details',
  WEATHER: 'weather',
  SCHEMES: 'schemes',
  SCHEME_DETAILS: 'scheme_details',
  VIDEO_TUTORIALS: 'video_tutorials',
  COMPANIES: 'companies',
  COMPANY_DETAILS: 'company_details',
  PROFILE: 'profile',
  SETTINGS: 'settings',
  NOTIFICATIONS: 'notifications',
  LOGIN: 'login',
  SIGNUP: 'signup',
  OTP: 'otp',
  LANGUAGE: 'language',
};

// Engagement levels
const ENGAGEMENT_LEVELS = {
  INACTIVE: 'inactive',
  LOW: 'low',
  MEDIUM: 'medium',
  HIGH: 'high',
  POWER_USER: 'power_user',
};

// Engagement level thresholds (based on daily engagement score)
const ENGAGEMENT_THRESHOLDS = {
  POWER_USER: 80, // Top 5% - extremely active users
  HIGH: 50, // Active daily users
  MEDIUM: 20, // Regular users
  LOW: 5, // Occasional users
  INACTIVE: 0, // Very low activity
};

// Churn risk levels
const CHURN_RISK_LEVELS = {
  LOW: 'low',
  MEDIUM: 'medium',
  HIGH: 'high',
  CRITICAL: 'critical',
};

// Churn risk thresholds
const CHURN_RISK_THRESHOLDS = {
  CRITICAL: 80, // Very likely to churn
  HIGH: 60,
  MEDIUM: 40,
  LOW: 0,
};

// Cache TTLs (in seconds)
const CACHE_TTL = {
  USER_METRICS: 300, // 5 minutes
  DASHBOARD_SUMMARY: 60, // 1 minute
  DAILY_METRICS: 900, // 15 minutes
  SESSION_DATA: 1800, // 30 minutes
  LEADERBOARD: 300, // 5 minutes
  REAL_TIME_STATS: 10, // 10 seconds
};

// Batch processing settings
const BATCH_SETTINGS = {
  MAX_BATCH_SIZE: 1000,
  FLUSH_INTERVAL_MS: 5000,
  MAX_RETRIES: 3,
  RETRY_DELAY_MS: 1000,
};

// RabbitMQ queue names
const QUEUES = {
  EVENTS: 'engagement_events',
  BATCH: 'engagement_batch',
  AGGREGATION: 'engagement_aggregation',
  ALERTS: 'engagement_alerts',
};

// Time periods for analytics
const TIME_PERIODS = {
  HOUR: 'hour',
  DAY: 'day',
  WEEK: 'week',
  MONTH: 'month',
  QUARTER: 'quarter',
  YEAR: 'year',
};

// Platform types
const PLATFORMS = {
  IOS: 'ios',
  ANDROID: 'android',
  WEB: 'web',
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
  TOO_MANY_REQUESTS: 429,
  INTERNAL_ERROR: 500,
  SERVICE_UNAVAILABLE: 503,
};

// Error codes
const ERROR_CODES = {
  VALIDATION_ERROR: 'VALIDATION_ERROR',
  INVALID_EVENT: 'INVALID_EVENT',
  INVALID_SESSION: 'INVALID_SESSION',
  USER_NOT_FOUND: 'USER_NOT_FOUND',
  RATE_LIMITED: 'RATE_LIMITED',
  DATABASE_ERROR: 'DATABASE_ERROR',
  CACHE_ERROR: 'CACHE_ERROR',
  QUEUE_ERROR: 'QUEUE_ERROR',
  INTERNAL_ERROR: 'INTERNAL_ERROR',
};

module.exports = {
  EVENT_CATEGORIES,
  EVENT_NAMES,
  SCREENS,
  ENGAGEMENT_LEVELS,
  ENGAGEMENT_THRESHOLDS,
  CHURN_RISK_LEVELS,
  CHURN_RISK_THRESHOLDS,
  CACHE_TTL,
  BATCH_SETTINGS,
  QUEUES,
  TIME_PERIODS,
  PLATFORMS,
  HTTP_STATUS,
  ERROR_CODES,
};
