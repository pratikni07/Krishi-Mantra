require('dotenv').config({
  path: `.env.${process.env.NODE_ENV || 'development'}`,
});

/**
 * Configuration for Engagement Service
 * Optimized for 100k+ concurrent users
 */
const config = {
  env: process.env.NODE_ENV || 'development',
  port: parseInt(process.env.PORT, 10) || 3007,

  // MongoDB configuration with connection pooling for high concurrency
  mongodb: {
    uri: process.env.MONGODB_URI || 'mongodb://localhost:27017/engagementdb',
    options: {
      maxPoolSize: parseInt(process.env.MONGODB_MAX_POOL_SIZE, 10) || 150,
      minPoolSize: parseInt(process.env.MONGODB_MIN_POOL_SIZE, 10) || 30,
      serverSelectionTimeoutMS: 10000,
      socketTimeoutMS: 45000,
      retryWrites: true,
      retryReads: true,
      w: 'majority',
      readPreference: 'secondaryPreferred', // Read from secondaries for scalability
    },
  },

  // Redis configuration for caching and real-time counters
  redis: {
    host: process.env.REDIS_HOST || 'localhost',
    port: parseInt(process.env.REDIS_PORT, 10) || 6379,
    password: process.env.REDIS_PASSWORD || undefined,
    keyPrefix: process.env.REDIS_KEY_PREFIX || 'engagement:',
    ttl: parseInt(process.env.REDIS_TTL, 10) || 3600,
    maxRetriesPerRequest: 3,
    enableReadyCheck: true,
    lazyConnect: true,
  },

  // RabbitMQ configuration for async event processing
  rabbitmq: {
    url: process.env.RABBITMQ_URL || 'amqp://localhost:5672',
    queues: {
      events: process.env.RABBITMQ_EVENT_QUEUE || 'engagement_events',
      batch: process.env.RABBITMQ_BATCH_QUEUE || 'engagement_batch',
    },
    prefetch: parseInt(process.env.RABBITMQ_PREFETCH, 10) || 10,
  },

  // Event processing configuration
  events: {
    batchSize: parseInt(process.env.BATCH_SIZE, 10) || 1000,
    batchIntervalMs: parseInt(process.env.BATCH_INTERVAL_MS, 10) || 5000,
    ttlDays: parseInt(process.env.EVENT_TTL_DAYS, 10) || 90,
  },

  // Rate limiting configuration
  rateLimit: {
    windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS, 10) || 60000,
    maxRequests: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS, 10) || 500,
    trackMax: parseInt(process.env.RATE_LIMIT_TRACK_MAX, 10) || 1000,
  },

  // Analytics configuration
  analytics: {
    aggregationIntervalMs: parseInt(process.env.AGGREGATION_INTERVAL_MS, 10) || 60000,
    realtimeUpdateIntervalMs: parseInt(process.env.REALTIME_UPDATE_INTERVAL_MS, 10) || 5000,
    sessionTimeoutMs: parseInt(process.env.SESSION_TIMEOUT_MS, 10) || 1800000, // 30 minutes
  },

  // Security
  security: {
    jwtSecret: process.env.JWT_SECRET || 'default-secret',
    allowedOrigins: process.env.ALLOWED_ORIGINS?.split(',') || ['http://localhost:3000'],
  },

  // Logging
  logging: {
    level: process.env.LOG_LEVEL || 'info',
    format: process.env.LOG_FORMAT || 'json',
  },

  // CORS
  cors: {
    origin: process.env.CORS_ORIGIN?.split(',') || ['http://localhost:3000', 'http://localhost:3001'],
  },

  // Node environment helpers
  nodeEnv: process.env.NODE_ENV || 'development',
  logLevel: process.env.LOG_LEVEL || 'info',

  // Batch processing aliases
  batch: {
    size: parseInt(process.env.BATCH_SIZE, 10) || 1000,
    intervalMs: parseInt(process.env.BATCH_INTERVAL_MS, 10) || 5000,
  },
};

module.exports = config;
