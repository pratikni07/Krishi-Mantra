const Redis = require('ioredis');
const { logger } = require('./logger');

class RedisService {
  constructor() {
    this.client = null;
    this.isConnected = false;
    this.init();
  }

  init() {
    try {
      // Create Redis client based on environment configuration
      const redisOptions = {
        host: process.env.REDIS_HOST || 'localhost',
        port: process.env.REDIS_PORT || 6379,
        password: process.env.REDIS_PASSWORD || '',
        retryStrategy: (times) => {
          const delay = Math.min(times * 50, 2000);
          logger.info(`Redis reconnecting in ${delay}ms (attempt ${times})`);
          return delay;
        },
        maxRetriesPerRequest: 3,
      };

      // Add TLS configuration for production
      if (process.env.NODE_ENV === 'production' && process.env.REDIS_SSL === 'true') {
        redisOptions.tls = {};
        redisOptions.socket = {
          servername: process.env.REDIS_HOST,
        };
      }

      this.client = new Redis(redisOptions);

      // Handle connection events
      this.client.on('connect', () => {
        this.isConnected = true;
        logger.info('Connected to Redis server');
      });

      this.client.on('error', (err) => {
        this.isConnected = false;
        logger.error('Redis client error:', err);
      });

      this.client.on('reconnecting', () => {
        logger.info('Redis client reconnecting');
      });

      this.client.on('close', () => {
        this.isConnected = false;
        logger.info('Redis connection closed');
      });

      this.client.on('end', () => {
        this.isConnected = false;
        logger.info('Redis connection ended');
      });
    } catch (error) {
      logger.error('Redis initialization error:', error);
      this.useDummyClient();
    }
  }

  useDummyClient() {
    // Create in-memory fallback when Redis is unavailable
    logger.warn('Using in-memory dummy Redis client');
    const memoryStore = new Map();

    this.client = {
      get: async (key) => memoryStore.get(key),
      set: async (key, value) => memoryStore.set(key, value),
      setex: async (key, seconds, value) => {
        memoryStore.set(key, value);
        setTimeout(() => memoryStore.delete(key), seconds * 1000);
      },
      del: async (key) => memoryStore.delete(key),
      hset: async (key, field, value) => {
        const hash = memoryStore.get(key) || {};
        hash[field] = value;
        memoryStore.set(key, hash);
      },
      hget: async (key, field) => {
        const hash = memoryStore.get(key) || {};
        return hash[field];
      },
      hgetall: async (key) => memoryStore.get(key) || {},
      exists: async (key) => memoryStore.has(key),
      expire: async (key, seconds) => {
        if (memoryStore.has(key)) {
          setTimeout(() => memoryStore.delete(key), seconds * 1000);
          return true;
        }
        return false;
      },
      lpush: async (key, ...values) => {
        const list = memoryStore.get(key) || [];
        list.unshift(...values);
        memoryStore.set(key, list);
        return list.length;
      },
      rpop: async (key) => {
        const list = memoryStore.get(key) || [];
        return list.pop();
      },
      lrange: async (key, start, end) => {
        const list = memoryStore.get(key) || [];
        return list.slice(start, end === -1 ? undefined : end + 1);
      },
      // Indicate this is a dummy client
      isDummyClient: () => true,
    };

    this.isConnected = true;
  }

  // Cache methods with TTL
  async get(key) {
    try {
      return await this.client.get(key);
    } catch (error) {
      logger.error(`Redis get error for key ${key}:`, error);
      return null;
    }
  }

  async set(key, value, ttl = 3600) {
    try {
      if (ttl > 0) {
        return await this.client.setex(key, ttl, value);
      } else {
        return await this.client.set(key, value);
      }
    } catch (error) {
      logger.error(`Redis set error for key ${key}:`, error);
      return false;
    }
  }

  async del(key) {
    try {
      return await this.client.del(key);
    } catch (error) {
      logger.error(`Redis del error for key ${key}:`, error);
      return 0;
    }
  }

  async clear(pattern) {
    try {
      const keys = await this.client.keys(pattern);
      if (keys.length > 0) {
        return await this.client.del(...keys);
      }
      return 0;
    } catch (error) {
      logger.error(`Redis clear error for pattern ${pattern}:`, error);
      return 0;
    }
  }

  // User data caching
  async cacheUser(userId, userData, ttl = 3600) {
    return this.set(`user_details:${userId}`, JSON.stringify(userData), ttl);
  }

  async getUserCache(userId) {
    const data = await this.get(`user_details:${userId}`);
    return data ? JSON.parse(data) : null;
  }

  async invalidateUserCache(userId) {
    return this.del(`user_details:${userId}`);
  }

  // Close connection
  async close() {
    if (this.client && !this.client.isDummyClient) {
      await this.client.quit();
      this.isConnected = false;
    }
  }
}

// Create and export singleton instance
const redisService = new RedisService();
module.exports = redisService; 