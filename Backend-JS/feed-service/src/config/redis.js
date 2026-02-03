const Redis = require('ioredis');
const { CACHE_TTL } = require('../utils/constants');

let redisClient;
let useDummyClient = false;

/**
 * In-memory LRU cache with TTL support for fallback
 */
class LRUCache {
  constructor(maxSize = 5000) {
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

const fallbackCache = new LRUCache(5000);

function createDummyRedisClient() {
  console.warn('Using in-memory LRU cache - Redis unavailable');

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
    del: async (key) => {
      if (typeof key === 'string' && key.includes('*')) {
        const keys = fallbackCache.keys(key);
        keys.forEach((k) => fallbackCache.delete(k));
        return keys.length;
      }
      return fallbackCache.delete(key) ? 1 : 0;
    },
    keys: async (pattern) => fallbackCache.keys(pattern),
    disconnect: () => {
      fallbackCache.clear();
      console.log('[LRU Cache] Cleared');
    },
    info: async () => `lru-cache:size=${fallbackCache.size()}`,
  };
}

// Function to switch to dummy client
function switchToDummyClient() {
  if (!useDummyClient) {
    console.warn('Redis unavailable - switching to in-memory cache');
    useDummyClient = true;
    try {
      if (redisClient && typeof redisClient.disconnect === 'function') {
        redisClient.disconnect();
      }
    } catch (e) {
      // Ignore disconnect errors
    }
    redisClient = createDummyRedisClient();
  }
}

try {
  const redisPassword = process.env.REDIS_PASSWORD;

  const config = {
    host: process.env.REDIS_HOST || 'localhost',
    port: process.env.REDIS_PORT || 6379,
    retryStrategy(times) {
      if (useDummyClient) return false;
      if (times > 3) {
        switchToDummyClient();
        return false;
      }
      return Math.min(times * 100, 3000);
    },
    maxRetriesPerRequest: 2,
    connectTimeout: 5000,
    enableOfflineQueue: false,
    lazyConnect: false,
  };

  if (redisPassword && redisPassword.trim() !== '') {
    config.password = redisPassword;
  }

  redisClient = new Redis(config);

  const connectTimeout = setTimeout(() => {
    console.error('Redis connection timeout - using in-memory cache');
    switchToDummyClient();
  }, 5000);

  redisClient.on('error', (err) => {
    if (!useDummyClient) {
      console.error('Redis error:', err.message);
      if (err.message.includes('NOAUTH') || err.message.includes('AUTH') || err.message.includes('ECONNREFUSED')) {
        switchToDummyClient();
      }
    }
  });

  redisClient.on('connect', () => {
    console.log('Redis connected');
    clearTimeout(connectTimeout);
  });

  redisClient.on('ready', () => {
    console.log('Redis ready');
  });
} catch (error) {
  console.error('Redis initialization error:', error.message);
  switchToDummyClient();
}

// Wrap Redis operations with error handling
const redis = {
  async get(key) {
    try {
      return await redisClient.get(key);
    } catch (error) {
      if (!useDummyClient) {
        switchToDummyClient();
        return redisClient.get(key);
      }
      return null;
    }
  },

  async set(key, value) {
    try {
      return await redisClient.set(key, value);
    } catch (error) {
      if (!useDummyClient) {
        switchToDummyClient();
        return redisClient.set(key, value);
      }
      return null;
    }
  },

  async setex(key, seconds, value) {
    try {
      return await redisClient.setex(key, seconds, value);
    } catch (error) {
      if (!useDummyClient) {
        switchToDummyClient();
        return redisClient.setex(key, seconds, value);
      }
      return null;
    }
  },

  async del(key) {
    try {
      return await redisClient.del(key);
    } catch (error) {
      if (!useDummyClient) {
        switchToDummyClient();
        return redisClient.del(key);
      }
      return null;
    }
  },

  async keys(pattern) {
    try {
      return await redisClient.keys(pattern);
    } catch (error) {
      if (!useDummyClient) {
        switchToDummyClient();
        return redisClient.keys(pattern);
      }
      return [];
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

  isDummyClient: () => useDummyClient,

  // Graceful shutdown
  async disconnect() {
    if (redisClient && typeof redisClient.disconnect === 'function') {
      await redisClient.disconnect();
    }
  },
};

module.exports = redis;
