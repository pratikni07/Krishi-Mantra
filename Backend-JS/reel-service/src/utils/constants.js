/**
 * Application constants for reel-service
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
  REELS_LIST: 180,     // 3 minutes for reel lists
  TRENDING: 300,       // 5 minutes for trending
  COMMENTS: 30,        // 30 seconds for comments
  TAGS: 600,           // 10 minutes for tags
  VIDEO: 1800,         // 30 minutes for video details
};

const CACHE_KEYS = {
  REELS_PAGE: 'reels:page:',
  REELS_TRENDING: 'reels:trending:',
  REELS_RECOMMENDED: 'reels:recommended:',
  REELS_USER: 'reels:user:',
  REELS_SEARCH: 'reels:search:',
  REEL: 'reel:',
  COMMENTS: 'comment:',
  TAGS_TRENDING: 'trending:tags:',
  VIDEOS: 'videos:',
  VIDEO: 'video:',
  USER_INTERESTS: 'user:interests:',
};

const PAGINATION = {
  DEFAULT_PAGE: 1,
  DEFAULT_LIMIT: 10,
  MAX_LIMIT: 100,
  VIDEO_LIMIT: 12,
  COMMENTS_LIMIT: 20,
};

const RATE_LIMITS = {
  // General API limits
  WINDOW_MS: 60 * 1000,
  MAX_REQUESTS: 100,

  // Upload limits
  UPLOAD_WINDOW_MS: 60 * 1000,
  MAX_UPLOADS: 10,

  // Like/comment limits
  ENGAGEMENT_WINDOW_MS: 60 * 1000,
  MAX_ENGAGEMENTS: 60,
};

const DB_CONFIG = {
  // Optimized for 10k concurrent connections
  MAX_POOL_SIZE: 100,
  MIN_POOL_SIZE: 20,
  SOCKET_TIMEOUT_MS: 45000,
  SERVER_SELECTION_TIMEOUT_MS: 10000,
  HEARTBEAT_FREQUENCY_MS: 10000,
  MAX_IDLE_TIME_MS: 30000,
};

const REEL_LIMITS = {
  MAX_DESCRIPTION_LENGTH: 2000,
  MAX_COMMENT_LENGTH: 1000,
  MAX_COMMENT_DEPTH: 5,
  MAX_TAGS_PER_REEL: 30,
};

const VIDEO_LIMITS = {
  MAX_TITLE_LENGTH: 100,
  MAX_DESCRIPTION_LENGTH: 5000,
  MAX_TAGS: 20,
  MAX_REPORTS_BEFORE_REVIEW: 5,
};

const VIDEO_TYPES = {
  YOUTUBE: 'youtube',
  DRIVE: 'drive',
  CLOUDINARY: 'cloudinary',
  DIRECT: 'direct',
};

const VISIBILITY = {
  PUBLIC: 'public',
  PRIVATE: 'private',
  UNLISTED: 'unlisted',
};

const SORT_OPTIONS = {
  RECENT: 'recent',
  POPULAR: 'popular',
  TRENDING: 'trending',
  RELEVANCE: 'relevance',
  VIEWS: 'views',
};

module.exports = {
  HTTP_STATUS,
  CACHE_TTL,
  CACHE_KEYS,
  PAGINATION,
  RATE_LIMITS,
  DB_CONFIG,
  REEL_LIMITS,
  VIDEO_LIMITS,
  VIDEO_TYPES,
  VISIBILITY,
  SORT_OPTIONS,
};
