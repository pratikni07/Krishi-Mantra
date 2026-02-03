/**
 * Application constants for notification-service
 * Optimized for 10k concurrent users
 */

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
  BAD_GATEWAY: 502,
  SERVICE_UNAVAILABLE: 503,
  GATEWAY_TIMEOUT: 504,
};

const CACHE_TTL = {
  SHORT: 60,           // 1 minute
  MEDIUM: 300,         // 5 minutes
  LONG: 3600,          // 1 hour
  USER_PREFS: 3600,    // 1 hour for user preferences
  NOTIFICATION: 300,   // 5 minutes for notification data
};

const CACHE_KEYS = {
  USER_PREFS: 'user_prefs:',
  NOTIFICATION: 'notification:',
  USER_NOTIFICATIONS: 'user_notifications:',
  UNREAD_COUNT: 'unread_count:',
};

const PAGINATION = {
  DEFAULT_PAGE: 1,
  DEFAULT_LIMIT: 20,
  MAX_LIMIT: 100,
};

const RATE_LIMITS = {
  // General API limits - optimized for 10k users
  WINDOW_MS: 60 * 1000,        // 1 minute window
  MAX_REQUESTS: 100,           // 100 requests per window

  // Notification creation limits
  CREATE_WINDOW_MS: 60 * 1000,
  MAX_CREATE: 50,              // 50 notifications per minute

  // Bulk notification limits
  BULK_WINDOW_MS: 60 * 1000,
  MAX_BULK: 10,                // 10 bulk requests per minute
  MAX_BULK_SIZE: 1000,         // Max 1000 notifications per bulk request

  // WebSocket limits
  WS_EVENTS_PER_SECOND: 10,
  WS_MAX_CONNECTIONS_PER_USER: 3,
};

const DB_CONFIG = {
  // Optimized for 10k concurrent connections
  MAX_POOL_SIZE: 100,
  MIN_POOL_SIZE: 20,
  SOCKET_TIMEOUT_MS: 45000,
  SERVER_SELECTION_TIMEOUT_MS: 10000,
  HEARTBEAT_FREQUENCY_MS: 10000,
  MAX_IDLE_TIME_MS: 30000,
  MAX_RETRIES: 5,
};

const WEBSOCKET_CONFIG = {
  // Optimized for 10k concurrent WebSocket connections
  PING_INTERVAL: 25000,
  PING_TIMEOUT: 60000,
  MAX_PAYLOAD: 10 * 1024,      // 10KB max message size
  MAX_CONNECTIONS_PER_USER: 3,
  RECONNECTION_DELAY: 1000,
  RECONNECTION_DELAY_MAX: 5000,
};

const NOTIFICATION_TYPES = {
  IN_APP: 'in_app',
  PUSH: 'push',
  EMAIL: 'email',
  SMS: 'sms',
};

const NOTIFICATION_STATUS = {
  PENDING: 'pending',
  PROCESSING: 'processing',
  DELIVERED: 'delivered',
  FAILED: 'failed',
  READ: 'read',
};

const NOTIFICATION_PRIORITY = {
  LOW: 'low',
  MEDIUM: 'medium',
  HIGH: 'high',
};

const NOTIFICATION_CATEGORIES = {
  SYSTEM: 'system',
  CONSULTANT_SERVICE: 'consultant_service',
  NEW_POST: 'new_post',
  LIKE: 'new_post',
  COMMENT: 'new_post',
  NEW_REEL: 'new_reel',
  FARM_VIDEOS: 'farm_videos',
  CROP_CARE_AI: 'crop_care_ai',
  MESSAGE: 'consultant_service',
};

const BATCH_CONFIG = {
  DEFAULT_SIZE: 100,
  MAX_SIZE: 1000,
  DEFAULT_INTERVAL_MS: 60000,  // 1 minute
  MIN_INTERVAL_MS: 10000,      // 10 seconds minimum
};

const RABBITMQ_CONFIG = {
  PREFETCH_COUNT: 10,          // Process 10 messages at a time for better throughput
  MESSAGE_TTL: 86400000,       // 24 hours
  MAX_RETRIES: 3,
  RETRY_DELAY: 1000,
};

module.exports = {
  HTTP_STATUS,
  CACHE_TTL,
  CACHE_KEYS,
  PAGINATION,
  RATE_LIMITS,
  DB_CONFIG,
  WEBSOCKET_CONFIG,
  NOTIFICATION_TYPES,
  NOTIFICATION_STATUS,
  NOTIFICATION_PRIORITY,
  NOTIFICATION_CATEGORIES,
  BATCH_CONFIG,
  RABBITMQ_CONFIG,
};
