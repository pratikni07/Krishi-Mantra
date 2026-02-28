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
  SHORT: 60,
  MEDIUM: 300,
  LONG: 3600,
  USER_PREFS: 3600,
  NOTIFICATION: 300,
  DEDUPE: 1800,
  DIGEST_WINDOW: 3600,
};

const CACHE_KEYS = {
  USER_PREFS: 'user_prefs:',
  NOTIFICATION: 'notification:',
  USER_NOTIFICATIONS: 'user_notifications:',
  UNREAD_COUNT: 'unread_count:',
  DEDUPE: 'dedupe:',
  RATE_LIMIT: 'notif_rate:',
  DIGEST: 'digest:',
};

const PAGINATION = {
  DEFAULT_PAGE: 1,
  DEFAULT_LIMIT: 20,
  MAX_LIMIT: 100,
};

const RATE_LIMITS = {
  WINDOW_MS: 60 * 1000,
  MAX_REQUESTS: 100,
  CREATE_WINDOW_MS: 60 * 1000,
  MAX_CREATE: 50,
  BULK_WINDOW_MS: 60 * 1000,
  MAX_BULK: 10,
  MAX_BULK_SIZE: 1000,
  WS_EVENTS_PER_SECOND: 10,
  WS_MAX_CONNECTIONS_PER_USER: 3,
};

const NOTIFICATION_DELIVERY_MODE = {
  INSTANT: 'instant',
  DIGEST: 'digest',
};

const DEFAULT_CATEGORY_CAPS = {
  advertisement: { limit: 3, windowSeconds: 3600 },
  promotion: { limit: 3, windowSeconds: 3600 },
  post_engagement: { limit: 20, windowSeconds: 3600 },
  reel_engagement: { limit: 20, windowSeconds: 3600 },
  marketplace: { limit: 10, windowSeconds: 3600 },
};

const DB_CONFIG = {
  MAX_POOL_SIZE: 100,
  MIN_POOL_SIZE: 20,
  SOCKET_TIMEOUT_MS: 45000,
  SERVER_SELECTION_TIMEOUT_MS: 10000,
  HEARTBEAT_FREQUENCY_MS: 10000,
  MAX_IDLE_TIME_MS: 30000,
  MAX_RETRIES: 5,
};

const WEBSOCKET_CONFIG = {
  PING_INTERVAL: 25000,
  PING_TIMEOUT: 60000,
  MAX_PAYLOAD: 10 * 1024,
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
  SKIPPED: 'skipped',
  DEFERRED: 'deferred',
};

const NOTIFICATION_PRIORITY = {
  LOW: 'low',
  MEDIUM: 'medium',
  HIGH: 'high',
};

const NOTIFICATION_CATEGORIES = {
  SYSTEM: 'system',
  SUBSCRIPTION: 'subscription',
  PROMOTION: 'promotion',
  ADVERTISEMENT: 'advertisement',
  POST_ENGAGEMENT: 'post_engagement',
  REEL_ENGAGEMENT: 'reel_engagement',
  MARKETPLACE: 'marketplace',
  CONSULTANT_SERVICE: 'consultant_service',
  MESSAGE: 'message',
  NEW_POST: 'new_post',
  NEW_REEL: 'new_reel',
  FARM_VIDEOS: 'farm_videos',
  CROP_CARE_AI: 'crop_care_ai',
};

const NOTIFICATION_EVENTS = {
  SUBSCRIPTION_ENDING: 'subscription.ending',
  SUBSCRIPTION_DISCOUNT: 'subscription.discount',
  ADVERTISEMENT_BROADCAST: 'advertisement.broadcast',
  POST_LIKED: 'post.liked',
  POST_COMMENTED: 'post.commented',
  REEL_LIKED: 'reel.liked',
  REEL_COMMENTED: 'reel.commented',
  MARKETPLACE_PRODUCT_MATCH: 'marketplace.product.match',
};

const BATCH_CONFIG = {
  DEFAULT_SIZE: 100,
  MAX_SIZE: 1000,
  DEFAULT_INTERVAL_MS: 60000,
  MIN_INTERVAL_MS: 10000,
  DIGEST_FLUSH_INTERVAL_MS: 300000,
};

const RABBITMQ_CONFIG = {
  PREFETCH_COUNT: 10,
  MESSAGE_TTL: 86400000,
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
  NOTIFICATION_EVENTS,
  NOTIFICATION_DELIVERY_MODE,
  DEFAULT_CATEGORY_CAPS,
  BATCH_CONFIG,
  RABBITMQ_CONFIG,
};
