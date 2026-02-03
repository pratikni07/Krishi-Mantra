/**
 * Application constants for feed-service
 * Centralized configuration for scalability (10k+ concurrent users)
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
  SERVICE_UNAVAILABLE: 503,
};

const CACHE_TTL = {
  SHORT: 60,           // 1 minute - for rapidly changing data
  MEDIUM: 300,         // 5 minutes - for moderately changing data
  LONG: 3600,          // 1 hour - for stable data
  VERY_LONG: 86400,    // 24 hours - for rarely changing data
  TRENDING: 1800,      // 30 minutes - for trending content
  USER_INTEREST: 600,  // 10 minutes - for user preferences
};

const CACHE_KEYS = {
  FEED: 'feed:',
  FEED_LIST: 'feeds:list:',
  COMMENTS: 'comments:',
  TAG: 'tag:',
  RANDOM_FEEDS: 'random-feeds:',
  RECOMMENDED_FEEDS: 'recommended-feeds:',
  USER_INTEREST: 'user-interest:',
  TRENDING_HASHTAGS: 'trending-hashtags',
  LOCATION_FEEDS: 'location-feeds:',
  TOP_FEEDS: 'top-feeds',
};

const PAGINATION = {
  DEFAULT_PAGE: 1,
  DEFAULT_LIMIT: 10,
  MAX_LIMIT: 50,
  MAX_OFFSET: 10000, // Prevent deep pagination for performance
};

const FEED_CONSTANTS = {
  MAX_RADIUS_KM: 1000,
  MAX_CACHE_ITEMS: 500,
  MAX_COMMENT_DEPTH: 5,
  LOCATION_GRID_SIZE: 0.1,  // ~11.1km grid size
  MAX_RECENT_VIEWS: 500,
  MAX_INTERESTS: 50,
  DEFAULT_DISCOVERY_LIMIT: 20,
};

const INTERACTION_SCORES = {
  VIEW: 0.2,
  LIKE: 0.5,
  UNLIKE: -0.3,
  COMMENT: 1.0,
  SHARE: 1.5,
  SAVE: 1.2,
};

const ENGAGEMENT_THRESHOLDS = {
  HIGH: 100,
  MEDIUM: 30,
  LOW: 0,
};

const RATE_LIMITS = {
  // Optimized for 10k concurrent users
  WINDOW_MS: 60 * 1000,        // 1 minute window
  MAX_REQUESTS: 100,           // 100 requests per window
  FEED_CREATE_MAX: 10,         // 10 feeds per minute
  COMMENT_MAX: 30,             // 30 comments per minute
  LIKE_MAX: 60,                // 60 likes per minute
};

const DB_CONFIG = {
  MAX_POOL_SIZE: 100,          // Connection pool for 10k users
  MIN_POOL_SIZE: 20,
  SOCKET_TIMEOUT_MS: 45000,
  SERVER_SELECTION_TIMEOUT_MS: 10000,
  HEARTBEAT_FREQUENCY_MS: 10000,
  MAX_IDLE_TIME_MS: 30000,
};

module.exports = {
  HTTP_STATUS,
  CACHE_TTL,
  CACHE_KEYS,
  PAGINATION,
  FEED_CONSTANTS,
  INTERACTION_SCORES,
  ENGAGEMENT_THRESHOLDS,
  RATE_LIMITS,
  DB_CONFIG,
};
