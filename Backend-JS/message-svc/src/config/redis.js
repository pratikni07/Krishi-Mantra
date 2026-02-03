const Redis = require('ioredis');
const { CACHE_TTL } = require('../utils/constants');

let redisClient;
let useFallback = false;

/**
 * In-memory LRU cache with TTL support for fallback
 */
class LRUCache {
  constructor(maxSize = 10000) {
    this.cache = new Map();
    this.maxSize = maxSize;
    this.timers = new Map();
  }

  get(key) {
    if (!this.cache.has(key)) return null;
    const value = this.cache.get(key);
    this.cache.delete(key);
    this.cache.set(key, value);
    return value;
  }

  set(key, value, ttlSeconds = 0) {
    if (this.timers.has(key)) {
      clearTimeout(this.timers.get(key));
      this.timers.delete(key);
    }

    if (this.cache.size >= this.maxSize) {
      const firstKey = this.cache.keys().next().value;
      this.cache.delete(firstKey);
      if (this.timers.has(firstKey)) {
        clearTimeout(this.timers.get(firstKey));
        this.timers.delete(firstKey);
      }
    }

    this.cache.set(key, value);

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

  // Hash operations for online users
  hset(key, field, value) {
    const hash = this.get(key) || {};
    hash[field] = value;
    this.set(key, hash);
  }

  hget(key, field) {
    const hash = this.get(key);
    return hash ? hash[field] : null;
  }

  hdel(key, field) {
    const hash = this.get(key);
    if (hash && hash[field]) {
      delete hash[field];
      this.set(key, hash);
      return 1;
    }
    return 0;
  }

  hgetall(key) {
    return this.get(key) || {};
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
  console.warn('Using in-memory cache - Redis unavailable');

  return {
    get: async (key) => fallbackCache.get(key),
    set: async (key, value) => {
      fallbackCache.set(key, value);
      return 'OK';
    },
    setex: async (key, seconds, value) => {
      fallbackCache.set(key, value, seconds);
      return 'OK';
    },
    del: async (key) => (fallbackCache.delete(key) ? 1 : 0),
    hset: async (key, field, value) => {
      fallbackCache.hset(key, field, value);
      return 1;
    },
    hget: async (key, field) => fallbackCache.hget(key, field),
    hdel: async (key, field) => fallbackCache.hdel(key, field),
    hgetall: async (key) => fallbackCache.hgetall(key),
    hDel: async (key, field) => fallbackCache.hdel(key, field),
    expire: async (key, seconds) => {
      const value = fallbackCache.get(key);
      if (value !== null) {
        fallbackCache.set(key, value, seconds);
      }
      return 1;
    },
    incr: async (key) => {
      const current = parseInt(fallbackCache.get(key) || '0');
      const newVal = current + 1;
      fallbackCache.set(key, String(newVal));
      return newVal;
    },
    decr: async (key) => {
      const current = parseInt(fallbackCache.get(key) || '0');
      const newVal = Math.max(0, current - 1);
      fallbackCache.set(key, String(newVal));
      return newVal;
    },
    keys: async () => [],
    disconnect: () => {
      fallbackCache.clear();
      console.log('Fallback cache cleared');
    },
  };
}

/**
 * Switch to fallback client
 */
function switchToFallback() {
  if (!useFallback) {
    console.warn('Switching to in-memory cache');
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

  const config = {
    host: process.env.REDIS_HOST || 'localhost',
    port: parseInt(process.env.REDIS_PORT) || 6379,
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
    config.password = redisPassword;
  }

  redisClient = new Redis(config);

  const connectTimeout = setTimeout(() => {
    console.error('Redis connection timeout');
    switchToFallback();
  }, 5000);

  redisClient.on('error', (err) => {
    if (!useFallback) {
      console.error('Redis error:', err.message);
      if (err.message.includes('ECONNREFUSED') || err.message.includes('NOAUTH')) {
        switchToFallback();
      }
    }
  });

  redisClient.on('connect', () => {
    console.log('Redis Client Connected');
    clearTimeout(connectTimeout);
  });

  redisClient.on('ready', () => {
    console.log('Redis ready');
  });

} catch (error) {
  console.error('Redis initialization error:', error.message);
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

  async set(key, value) {
    try {
      return await redisClient.set(key, value);
    } catch (error) {
      if (!useFallback) {
        switchToFallback();
        return redisClient.set(key, value);
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

  async hset(key, field, value) {
    try {
      return await redisClient.hset(key, field, value);
    } catch (error) {
      if (!useFallback) {
        switchToFallback();
        return redisClient.hset(key, field, value);
      }
      return null;
    }
  },

  async hget(key, field) {
    try {
      return await redisClient.hget(key, field);
    } catch (error) {
      if (!useFallback) {
        switchToFallback();
        return redisClient.hget(key, field);
      }
      return null;
    }
  },

  async hdel(key, field) {
    try {
      return await redisClient.hdel(key, field);
    } catch (error) {
      if (!useFallback) {
        switchToFallback();
        return redisClient.hdel(key, field);
      }
      return null;
    }
  },

  // Alias for compatibility
  async hDel(key, field) {
    return this.hdel(key, field);
  },

  async hgetall(key) {
    try {
      return await redisClient.hgetall(key);
    } catch (error) {
      if (!useFallback) {
        switchToFallback();
        return redisClient.hgetall(key);
      }
      return {};
    }
  },

  async incr(key) {
    try {
      return await redisClient.incr(key);
    } catch (error) {
      if (!useFallback) {
        switchToFallback();
        return redisClient.incr(key);
      }
      // Fallback incr
      const current = parseInt(fallbackCache.get(key) || '0');
      const newVal = current + 1;
      fallbackCache.set(key, String(newVal));
      return newVal;
    }
  },

  async decr(key) {
    try {
      return await redisClient.decr(key);
    } catch (error) {
      if (!useFallback) {
        switchToFallback();
        return redisClient.decr(key);
      }
      // Fallback decr
      const current = parseInt(fallbackCache.get(key) || '0');
      const newVal = Math.max(0, current - 1);
      fallbackCache.set(key, String(newVal));
      return newVal;
    }
  },

  async expire(key, seconds) {
    try {
      return await redisClient.expire(key, seconds);
    } catch (error) {
      if (!useFallback) {
        switchToFallback();
        return redisClient.expire(key, seconds);
      }
      // Fallback: re-set with TTL (approximation)
      const value = fallbackCache.get(key);
      if (value !== null) {
        fallbackCache.set(key, value, seconds);
      }
      return 1;
    }
  },

  /**
   * Get cached data or fetch and cache it
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
      return fetchFn();
    }
  },

  get client() {
    return redisClient;
  },

  isFallback: () => useFallback,
  isDummyClient: () => useFallback,

  async disconnect() {
    if (redisClient && typeof redisClient.disconnect === 'function') {
      await redisClient.disconnect();
    }
  },
};

module.exports = redis;
