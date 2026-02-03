const Redis = require('ioredis');
const { CACHE_TTL } = require('../utils/constants');

/**
 * LRU Cache fallback when Redis is unavailable
 */
class LRUCache {
  constructor(maxSize = 1000) {
    this.cache = new Map();
    this.maxSize = maxSize;
  }

  get(key) {
    if (!this.cache.has(key)) return null;

    const item = this.cache.get(key);
    if (item.expiry && Date.now() > item.expiry) {
      this.cache.delete(key);
      return null;
    }

    // Move to end (most recently used)
    this.cache.delete(key);
    this.cache.set(key, item);
    return item.value;
  }

  set(key, value, ttlSeconds = null) {
    // Remove oldest if at capacity
    if (this.cache.size >= this.maxSize) {
      const firstKey = this.cache.keys().next().value;
      this.cache.delete(firstKey);
    }

    this.cache.set(key, {
      value,
      expiry: ttlSeconds ? Date.now() + (ttlSeconds * 1000) : null,
    });
  }

  del(key) {
    // Support wildcard patterns
    if (key.includes('*')) {
      const pattern = new RegExp('^' + key.replace(/\*/g, '.*') + '$');
      for (const k of this.cache.keys()) {
        if (pattern.test(k)) {
          this.cache.delete(k);
        }
      }
      return;
    }
    this.cache.delete(key);
  }

  keys(pattern) {
    const regex = new RegExp('^' + pattern.replace(/\*/g, '.*') + '$');
    return Array.from(this.cache.keys()).filter(k => regex.test(k));
  }

  clear() {
    this.cache.clear();
  }

  size() {
    return this.cache.size;
  }
}

// Initialize Redis client or fallback
let redisClient;
let usingFallback = false;
const fallbackCache = new LRUCache(2000);

try {
  const config = {
    host: process.env.REDIS_HOST || 'localhost',
    port: parseInt(process.env.REDIS_PORT) || 6379,
    retryStrategy(times) {
      if (times > 10) {
        console.warn('Redis max retries reached, switching to in-memory cache');
        usingFallback = true;
        return null;
      }
      return Math.min(times * 100, 3000);
    },
    maxRetriesPerRequest: 3,
    lazyConnect: true,
    enableReadyCheck: true,
    connectTimeout: 10000,
  };

  // Add password if provided
  if (process.env.REDIS_PASSWORD && process.env.REDIS_PASSWORD.trim()) {
    config.password = process.env.REDIS_PASSWORD;
  }

  redisClient = new Redis(config);

  redisClient.on('error', (err) => {
    if (!usingFallback) {
      console.error('Redis Client Error:', err.message);
    }
  });

  redisClient.on('connect', () => {
    usingFallback = false;
    console.log('Redis Client Connected');
  });

  redisClient.on('ready', () => {
    console.log('Redis Client Ready');
  });

  redisClient.on('close', () => {
    console.warn('Redis connection closed');
  });

  // Attempt connection
  redisClient.connect().catch((err) => {
    console.warn('Redis initial connection failed:', err.message);
    usingFallback = true;
  });

} catch (error) {
  console.error('Redis initialization error:', error.message);
  usingFallback = true;
}

/**
 * Redis wrapper with fallback support
 */
const redis = {
  async get(key) {
    try {
      if (usingFallback) {
        return fallbackCache.get(key);
      }
      return await redisClient.get(key);
    } catch (error) {
      console.warn(`Redis GET error for key ${key}:`, error.message);
      return fallbackCache.get(key);
    }
  },

  async set(key, value, ...args) {
    try {
      if (usingFallback) {
        // Parse EX ttl from args
        const exIndex = args.indexOf('EX');
        const ttl = exIndex !== -1 ? args[exIndex + 1] : null;
        fallbackCache.set(key, value, ttl);
        return 'OK';
      }
      return await redisClient.set(key, value, ...args);
    } catch (error) {
      console.warn(`Redis SET error for key ${key}:`, error.message);
      fallbackCache.set(key, value);
      return null;
    }
  },

  async setex(key, seconds, value) {
    try {
      if (usingFallback) {
        fallbackCache.set(key, value, seconds);
        return 'OK';
      }
      return await redisClient.setex(key, seconds, value);
    } catch (error) {
      console.warn(`Redis SETEX error for key ${key}:`, error.message);
      fallbackCache.set(key, value, seconds);
      return null;
    }
  },

  async del(key) {
    try {
      if (usingFallback) {
        fallbackCache.del(key);
        return 1;
      }

      // Handle wildcard patterns
      if (key.includes('*')) {
        const keys = await redisClient.keys(key);
        if (keys.length > 0) {
          return await redisClient.del(...keys);
        }
        return 0;
      }

      return await redisClient.del(key);
    } catch (error) {
      console.warn(`Redis DEL error for key ${key}:`, error.message);
      fallbackCache.del(key);
      return null;
    }
  },

  async keys(pattern) {
    try {
      if (usingFallback) {
        return fallbackCache.keys(pattern);
      }
      return await redisClient.keys(pattern);
    } catch (error) {
      console.warn(`Redis KEYS error for pattern ${pattern}:`, error.message);
      return fallbackCache.keys(pattern);
    }
  },

  async getOrSet(key, ttl, fetchFn) {
    try {
      let data = await this.get(key);
      if (data) {
        return JSON.parse(data);
      }

      const result = await fetchFn();
      await this.setex(key, ttl, JSON.stringify(result));
      return result;
    } catch (error) {
      console.warn('Redis getOrSet error:', error.message);
      return fetchFn();
    }
  },

  isFallback() {
    return usingFallback;
  },

  async disconnect() {
    if (redisClient && !usingFallback) {
      await redisClient.quit();
      console.log('Redis connection closed');
    }
  },

  // Expose raw client for advanced operations
  client: redisClient,
};

module.exports = redis;
