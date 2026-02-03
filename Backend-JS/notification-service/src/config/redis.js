const Redis = require('ioredis');
const config = require('./index');
const logger = require('../utils/logger');
const { CACHE_TTL } = require('../utils/constants');

let redisClient;
let useFallback = false;

/**
 * In-memory LRU cache with TTL support for fallback
 * Optimized for 10k concurrent users
 */
class LRUCache {
  constructor(maxSize = 10000) {
    this.cache = new Map();
    this.maxSize = maxSize;
    this.timers = new Map();
  }

  get(key) {
    if (!this.cache.has(key)) return null;
    // Move to end (most recently used)
    const value = this.cache.get(key);
    this.cache.delete(key);
    this.cache.set(key, value);
    return value;
  }

  set(key, value, ttlSeconds = 0) {
    // Clear existing timer if any
    if (this.timers.has(key)) {
      clearTimeout(this.timers.get(key));
      this.timers.delete(key);
    }

    // Remove oldest if at capacity
    if (this.cache.size >= this.maxSize) {
      const firstKey = this.cache.keys().next().value;
      this.cache.delete(firstKey);
      if (this.timers.has(firstKey)) {
        clearTimeout(this.timers.get(firstKey));
        this.timers.delete(firstKey);
      }
    }

    this.cache.set(key, value);

    // Set TTL if specified
    if (ttlSeconds > 0) {
      const timer = setTimeout(() => {
        this.cache.delete(key);
        this.timers.delete(key);
      }, ttlSeconds * 1000);
      this.timers.set(key, timer);
    }
  }

  delete(key) {
    if (this.timers.has(key)) {
      clearTimeout(this.timers.get(key));
      this.timers.delete(key);
    }
    return this.cache.delete(key);
  }

  keys(pattern) {
    const prefix = pattern.replace('*', '');
    return Array.from(this.cache.keys()).filter((k) =>
      pattern.includes('*') ? k.startsWith(prefix) : k === pattern
    );
  }

  clear() {
    this.timers.forEach((timer) => clearTimeout(timer));
    this.timers.clear();
    this.cache.clear();
  }

  size() {
    return this.cache.size;
  }
}

const fallbackCache = new LRUCache(10000);

/**
 * Create fallback client for when Redis is unavailable
 */
function createFallbackClient() {
  logger.warn('Using in-memory LRU cache - Redis unavailable');

  return {
    get: async (key) => fallbackCache.get(key),
    set: async (key, value, ...args) => {
      // Handle both set(key, value) and set(key, value, 'EX', ttl)
      let ttl = 0;
      if (args.length >= 2 && args[0] === 'EX') {
        ttl = parseInt(args[1], 10);
      }
      fallbackCache.set(key, value, ttl);
      return 'OK';
    },
    setex: async (key, seconds, value) => {
      fallbackCache.set(key, value, seconds);
      return 'OK';
    },
    del: async (key) => {
      if (typeof key === 'string' && key.includes('*')) {
        const keys = fallbackCache.keys(key);
        keys.forEach((k) => fallbackCache.delete(k));
        return keys.length;
      }
      return fallbackCache.delete(key) ? 1 : 0;
    },
    keys: async (pattern) => fallbackCache.keys(pattern),
    exists: async (key) => (fallbackCache.get(key) !== null ? 1 : 0),
    expire: async () => 1,
    incr: async (key) => {
      const current = parseInt(fallbackCache.get(key) || '0', 10);
      const newValue = current + 1;
      fallbackCache.set(key, String(newValue));
      return newValue;
    },
    disconnect: () => {
      fallbackCache.clear();
      logger.info('[LRU Cache] Cleared');
    },
    info: async () => `lru-cache:size=${fallbackCache.size()}`,
  };
}

/**
 * Switch to fallback client
 */
function switchToFallback() {
  if (!useFallback) {
    logger.warn('Switching to in-memory cache');
    useFallback = true;
    try {
      if (redisClient && typeof redisClient.disconnect === 'function') {
        redisClient.disconnect();
      }
    } catch (e) {
      // Ignore disconnect errors
    }
    redisClient = createFallbackClient();
  }
}

/**
 * Initialize Redis client
 */
try {
  const redisPassword = process.env.REDIS_PASSWORD;

  const redisConfig = {
    host: config.redis.host,
    port: config.redis.port,
    retryStrategy(times) {
      if (useFallback) return false;
      if (times > 3) {
        switchToFallback();
        return false;
      }
      return Math.min(times * 100, 3000);
    },
    maxRetriesPerRequest: 3,
    connectTimeout: 5000,
    enableOfflineQueue: false,
    lazyConnect: false,
  };

  if (redisPassword && redisPassword.trim() !== '') {
    redisConfig.password = redisPassword;
  }

  redisClient = new Redis(redisConfig);

  const connectTimeout = setTimeout(() => {
    logger.error('Redis connection timeout - using in-memory cache');
    switchToFallback();
  }, 5000);

  redisClient.on('error', (err) => {
    if (!useFallback) {
      logger.error('Redis error:', err.message);
      if (err.message.includes('NOAUTH') || err.message.includes('AUTH') || err.message.includes('ECONNREFUSED')) {
        switchToFallback();
      }
    }
  });

  redisClient.on('connect', () => {
    logger.info('Redis connected');
    clearTimeout(connectTimeout);
  });

  redisClient.on('ready', () => {
    logger.info('Redis ready');
  });
} catch (error) {
  logger.error('Redis initialization error:', error.message);
  switchToFallback();
}

/**
 * Redis wrapper with error handling and helper methods
 */
const redis = {
  async get(key) {
    try {
      return await redisClient.get(key);
    } catch (error) {
      if (!useFallback) {
        switchToFallback();
        return redisClient.get(key);
      }
      return null;
    }
  },

  async set(key, value, ...args) {
    try {
      return await redisClient.set(key, value, ...args);
    } catch (error) {
      if (!useFallback) {
        switchToFallback();
        return redisClient.set(key, value, ...args);
      }
      return null;
    }
  },

  async setex(key, seconds, value) {
    try {
      return await redisClient.setex(key, seconds, value);
    } catch (error) {
      if (!useFallback) {
        switchToFallback();
        return redisClient.setex(key, seconds, value);
      }
      return null;
    }
  },

  async del(key) {
    try {
      return await redisClient.del(key);
    } catch (error) {
      if (!useFallback) {
        switchToFallback();
        return redisClient.del(key);
      }
      return null;
    }
  },

  async keys(pattern) {
    try {
      return await redisClient.keys(pattern);
    } catch (error) {
      if (!useFallback) {
        switchToFallback();
        return redisClient.keys(pattern);
      }
      return [];
    }
  },

  async exists(key) {
    try {
      return await redisClient.exists(key);
    } catch (error) {
      if (!useFallback) {
        switchToFallback();
        return redisClient.exists(key);
      }
      return 0;
    }
  },

  /**
   * Get cached data or fetch and cache it
   * @param {string} key - Cache key
   * @param {number} ttl - TTL in seconds
   * @param {Function} fetchFn - Function to fetch data if not cached
   * @returns {Promise<any>}
   */
  async getOrSet(key, ttl, fetchFn) {
    try {
      const cached = await this.get(key);
      if (cached) {
        return JSON.parse(cached);
      }
      const data = await fetchFn();
      await this.setex(key, ttl, JSON.stringify(data));
      return data;
    } catch (error) {
      // If cache fails, just fetch the data
      return fetchFn();
    }
  },

  /**
   * Delete multiple keys by pattern
   * @param {string} pattern - Pattern to match keys
   * @returns {Promise<number>}
   */
  async deleteByPattern(pattern) {
    try {
      const keys = await this.keys(pattern);
      if (keys.length > 0) {
        await Promise.all(keys.map((k) => this.del(k)));
      }
      return keys.length;
    } catch (error) {
      return 0;
    }
  },

  // Raw client access
  get client() {
    return redisClient;
  },

  isFallback: () => useFallback,
  isDummyClient: () => useFallback,

  // Graceful shutdown
  async disconnect() {
    if (redisClient && typeof redisClient.disconnect === 'function') {
      await redisClient.disconnect();
    }
  },
};

module.exports = redis;
