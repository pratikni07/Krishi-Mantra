const rateLimit = require("express-rate-limit");
const Redis = require("../config/redis");

const createRateLimiter = (options = {}) => {
  const windowMs =
    parseInt(process.env.RATE_LIMIT_WINDOW) * 60 * 1000 || 15 * 60 * 1000; // 15 minutes default
  const maxRequests = parseInt(process.env.RATE_LIMIT_MAX_REQUESTS) || 100; // Limit each IP to 100 requests per windowMs

  // Create a simple Redis-based store
  const RedisStore = {
    init: () => {
      // Optional initialization
    },
    increment: async (key) => {
      const current = await Redis.incr(key);
      await Redis.expire(key, Math.ceil(windowMs / 1000));
      return current;
    },
    decrement: async (key) => {
      return await Redis.decr(key);
    },
    resetKey: async (key) => {
      return await Redis.del(key);
    },
  };

  return rateLimit({
    windowMs,
    max: maxRequests,
    standardHeaders: true,
    legacyHeaders: false,
    // Use custom key generator to include user ID if available
    keyGenerator: (req) => {
      const userId = req.body?.userId || req.query?.userId || "anonymous";
      return `rate_limit:${userId}:${req.ip}`;
    },
    // Custom handler for when rate limit is exceeded
    handler: (req, res) => {
      res.status(429).json({
        error: "Too many requests, please try again later",
        retryAfter: Math.ceil(windowMs / 1000),
      });
    },
    // Use Redis to store rate limit data
    store: RedisStore,
    ...options,
  });
};

module.exports = createRateLimiter;
