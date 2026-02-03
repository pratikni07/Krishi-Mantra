/**
 * Application constants for message-svc
 * Optimized for 10k concurrent WebSocket connections
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
  USER_STATUS: 120,    // 2 minutes for online status
  CHAT_LIST: 180,      // 3 minutes for chat lists
  MESSAGE_BATCH: 30,   // 30 seconds for message batches
};

const CACHE_KEYS = {
  USER_STATUS: 'user:status:',
  ONLINE_USERS: 'online_users',
  CHAT: 'chat:',
  USER_CHATS: 'user:chats:',
  MESSAGES: 'messages:',
  TYPING: 'typing:',
  AI_CONTEXT: 'ai:context:',
};

const PAGINATION = {
  DEFAULT_PAGE: 1,
  DEFAULT_LIMIT: 20,
  MAX_LIMIT: 100,
  MESSAGE_LIMIT: 50,
  MAX_MESSAGE_LIMIT: 100,
};

const SOCKET_CONFIG = {
  // Optimized for 10k concurrent connections
  PING_TIMEOUT: 60000,
  PING_INTERVAL: 25000,
  MAX_HTTP_BUFFER_SIZE: 10 * 1024 * 1024, // 10MB
  MAX_CONNECTIONS_PER_USER: 3,
  RECONNECTION_DELAY: 1000,
  RECONNECTION_DELAY_MAX: 5000,
};

const RATE_LIMITS = {
  // General API limits
  WINDOW_MS: 60 * 1000,
  MAX_REQUESTS: 100,

  // Message-specific limits
  MESSAGE_WINDOW_MS: 60 * 1000,
  MAX_MESSAGES_PER_MINUTE: 60,

  // AI limits
  AI_WINDOW_MS: 60 * 1000,
  MAX_AI_REQUESTS: 20,

  // Socket event limits
  SOCKET_EVENTS_PER_SECOND: 10,
};

const DB_CONFIG = {
  // Optimized for 10k concurrent connections
  MAX_POOL_SIZE: 150,
  MIN_POOL_SIZE: 30,
  SOCKET_TIMEOUT_MS: 45000,
  SERVER_SELECTION_TIMEOUT_MS: 10000,
  HEARTBEAT_FREQUENCY_MS: 10000,
  MAX_IDLE_TIME_MS: 30000,
};

const MESSAGE_TYPES = {
  TEXT: 'text',
  IMAGE: 'image',
  VIDEO: 'video',
  TEXT_IMAGE: 'text_image',
  TEXT_VIDEO: 'text_video',
  AUDIO: 'audio',
  FILE: 'file',
};

const CHAT_TYPES = {
  DIRECT: 'direct',
  GROUP: 'group',
};

const USER_STATUS = {
  ONLINE: 'online',
  OFFLINE: 'offline',
  AWAY: 'away',
  BUSY: 'busy',
};

const AI_CONFIG = {
  MAX_RETRIES: 3,
  INITIAL_DELAY: 1000,
  MAX_DELAY: 10000,
  BACKOFF_FACTOR: 2,
  REQUEST_TIMEOUT: 30000,
  CIRCUIT_BREAKER_THRESHOLD: 5,
  CIRCUIT_RESET_TIME: 120000, // 2 minutes
};

const GROUP_LIMITS = {
  MAX_MEMBERS: 400,
  MAX_ADMINS: 10,
  MAX_NAME_LENGTH: 100,
  MAX_DESCRIPTION_LENGTH: 500,
};

module.exports = {
  HTTP_STATUS,
  CACHE_TTL,
  CACHE_KEYS,
  PAGINATION,
  SOCKET_CONFIG,
  RATE_LIMITS,
  DB_CONFIG,
  MESSAGE_TYPES,
  CHAT_TYPES,
  USER_STATUS,
  AI_CONFIG,
  GROUP_LIMITS,
};
