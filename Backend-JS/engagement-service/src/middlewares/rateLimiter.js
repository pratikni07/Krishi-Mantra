/**
 * Rate Limiter Middleware
 * Protects API from abuse - optimized for 100k+ users
 */

const Redis = require('../config/redis');
const logger = require('../utils/logger');
const { HTTP_STATUS, ERROR_CODES } = require('../utils/constants');

// In-memory fallback for when Redis is unavailable
const memoryStore = new Map();
const MEMORY_CLEANUP_INTERVAL = 60000; // 1 minute

// Cleanup old entries from memory store
setInterval(() => {
  const now = Date.now();
  for (const [key, data] of memoryStore.entries()) {
    if (data.resetAt < now) {
      memoryStore.delete(key);
    }
  }
}, MEMORY_CLEANUP_INTERVAL);

/**
 * Create rate limiter middleware
 * @param {Object} options - Rate limiter options
 * @param {number} options.windowMs - Time window in milliseconds
 * @param {number} options.max - Maximum requests per window
 * @param {string} options.keyPrefix - Redis key prefix
 * @param {boolean} options.skipFailedRequests - Don't count failed requests
 */
const createRateLimiter = (options = {}) => {
  const {
    windowMs = 60000, // 1 minute
    max = 100,
    keyPrefix = 'rl',
    skipFailedRequests = false,
    message = 'Too many requests, please try again later',
  } = options;

  return async (req, res, next) => {
    try {
      // Get identifier (user ID or IP)
      const identifier = req.body?.userId || req.params?.userId || req.ip || 'anonymous';
      const key = `${keyPrefix}:${identifier}`;

      let current;
      let resetAt;

      // Try Redis first
      const client = Redis.getClient();
      if (client) {
        try {
          const multi = client.multi();
          multi.incr(key);
          multi.pttl(key);

          const results = await multi.exec();
          current = results[0][1];
          const ttl = results[1][1];

          // Set expiry on first request
          if (ttl === -1) {
            await client.pexpire(key, windowMs);
          }

          resetAt = Date.now() + (ttl > 0 ? ttl : windowMs);
        } catch (redisError) {
          logger.warn('Rate limiter Redis error, falling back to memory:', redisError.message);
          // Fall back to memory store
          const memData = memoryStore.get(key) || { count: 0, resetAt: Date.now() + windowMs };
          if (memData.resetAt < Date.now()) {
            memData.count = 0;
            memData.resetAt = Date.now() + windowMs;
          }
          memData.count++;
          memoryStore.set(key, memData);
          current = memData.count;
          resetAt = memData.resetAt;
        }
      } else {
        // Use memory store when Redis is unavailable
        const memData = memoryStore.get(key) || { count: 0, resetAt: Date.now() + windowMs };
        if (memData.resetAt < Date.now()) {
          memData.count = 0;
          memData.resetAt = Date.now() + windowMs;
        }
        memData.count++;
        memoryStore.set(key, memData);
        current = memData.count;
        resetAt = memData.resetAt;
      }

      // Set rate limit headers
      res.set('X-RateLimit-Limit', max);
      res.set('X-RateLimit-Remaining', Math.max(0, max - current));
      res.set('X-RateLimit-Reset', Math.ceil(resetAt / 1000));

      // Check if limit exceeded
      if (current > max) {
        logger.warn('Rate limit exceeded', { identifier, current, max });

        res.set('Retry-After', Math.ceil((resetAt - Date.now()) / 1000));

        return res.status(HTTP_STATUS.TOO_MANY_REQUESTS).json({
          success: false,
          error: ERROR_CODES.RATE_LIMITED,
          message,
          retryAfter: Math.ceil((resetAt - Date.now()) / 1000),
        });
      }

      // Track if we should decrement on failed request
      if (skipFailedRequests) {
        res.on('finish', async () => {
          if (res.statusCode >= 400) {
            try {
              if (client) {
                await client.decr(key);
              } else if (memoryStore.has(key)) {
                const memData = memoryStore.get(key);
                memData.count = Math.max(0, memData.count - 1);
              }
            } catch (e) {
              // Ignore decrement errors
            }
          }
        });
      }

      next();
    } catch (error) {
      logger.error('Rate limiter error:', error.message);
      // On error, allow request through
      next();
    }
  };
};

// Pre-configured rate limiters for different endpoints

// Event tracking - high throughput (1000 per minute per user)
const eventRateLimiter = createRateLimiter({
  windowMs: 60000,
  max: 1000,
  keyPrefix: 'rl:events',
});

// Batch events - lower limit (100 per minute)
const batchRateLimiter = createRateLimiter({
  windowMs: 60000,
  max: 100,
  keyPrefix: 'rl:batch',
});

// Session operations (50 per minute)
const sessionRateLimiter = createRateLimiter({
  windowMs: 60000,
  max: 50,
  keyPrefix: 'rl:session',
});

// Analytics endpoints (30 per minute)
const analyticsRateLimiter = createRateLimiter({
  windowMs: 60000,
  max: 30,
  keyPrefix: 'rl:analytics',
});

// Dashboard (10 per minute - heavy queries)
const dashboardRateLimiter = createRateLimiter({
  windowMs: 60000,
  max: 10,
  keyPrefix: 'rl:dashboard',
});

module.exports = {
  createRateLimiter,
  eventRateLimiter,
  batchRateLimiter,
  sessionRateLimiter,
  analyticsRateLimiter,
  dashboardRateLimiter,
};
