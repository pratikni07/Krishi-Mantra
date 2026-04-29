const Redis = require('redis');
const logger = require('../utils/logger');

/**
 * Redis Client Singleton
 * Provides caching functionality with graceful fallback
 */
class RedisClient {
  constructor() {
    this.client = null;
    this.isAvailable = false;
    this.reconnectAttempts = 0;
    this.maxReconnectAttempts = 5;

    this._initialize();
  }

  /**
   * Initialize Redis connection
   * @private
   */
  _initialize() {
    try {
      this.client = Redis.createClient({
        socket: {
          host: process.env.REDIS_HOST || 'localhost',
          port: parseInt(process.env.REDIS_PORT, 10) || 6379,
          reconnectStrategy: (retries) => {
            if (retries > this.maxReconnectAttempts) {
              logger.warn('Max Redis reconnection attempts reached');
              return false;
            }
            return Math.min(retries * 100, 3000);
          },
        },
        password: process.env.REDIS_PASSWORD || undefined,
      });

      this._setupEventHandlers();
      this._connect();
    } catch (error) {
      logger.warn('Redis client initialization failed:', error.message);
      this.isAvailable = false;
    }
  }

  /**
   * Setup Redis event handlers
   * @private
   */
  _setupEventHandlers() {
    this.client.on('connect', () => {
      this.isAvailable = true;
      this.reconnectAttempts = 0;
      logger.info('Redis client connected');
    });

    this.client.on('ready', () => {
      this.isAvailable = true;
      logger.info('Redis client ready');
    });

    this.client.on('error', (err) => {
      this.isAvailable = false;
      logger.warn('Redis client error:', err.message);
    });

    this.client.on('end', () => {
      this.isAvailable = false;
      logger.warn('Redis connection ended');
    });

    this.client.on('reconnecting', () => {
      this.reconnectAttempts++;
      logger.info(`Redis reconnecting... Attempt ${this.reconnectAttempts}`);
    });
  }

  /**
   * Connect to Redis
   * @private
   */
  async _connect() {
    try {
      if (!this.client.isOpen) {
        await this.client.connect();
      }
    } catch (error) {
      this.isAvailable = false;
      logger.warn('Redis connection failed:', error.message);
    }
  }

  /**
   * Ensure connection is open
   * @private
   */
  async _ensureConnection() {
    if (!this.isAvailable) return false;

    try {
      if (!this.client.isOpen) {
        await this.client.connect();
      }
      return true;
    } catch (error) {
      this.isAvailable = false;
      return false;
    }
  }

  /**
   * Get value from cache
   * @param {string} key - Cache key
   * @returns {Promise<string|null>}
   */
  async get(key) {
    try {
      if (!(await this._ensureConnection())) return null;
      return await this.client.get(key);
    } catch (error) {
      logger.warn(`Redis GET error for key "${key}":`, error.message);
      return null;
    }
  }

  /**
   * Set value in cache
   * @param {string} key - Cache key
   * @param {string} value - Value to cache
   * @param {Object} options - Options (EX for expiry in seconds)
   * @returns {Promise<boolean>}
   */
  async set(key, value, options = {}) {
    try {
      if (!(await this._ensureConnection())) return false;

      if (options.EX) {
        await this.client.set(key, value, { EX: options.EX });
      } else {
        await this.client.set(key, value);
      }
      return true;
    } catch (error) {
      logger.warn(`Redis SET error for key "${key}":`, error.message);
      return false;
    }
  }

  /**
   * Atomic SET-if-absent with TTL. Returns true iff this caller acquired
   * the key (it was previously unset). Use this for distributed locks
   * and per-event dedupe — one-and-only-one semantics that the regular
   * `set` doesn't expose. Maps to redis `SET key val EX ttl NX` which
   * either inserts and returns 'OK' or returns null on contention.
   *
   * @param {string} key
   * @param {string} value
   * @param {number} ttlSeconds
   * @returns {Promise<boolean>}
   */
  async setIfAbsent(key, value, ttlSeconds) {
    try {
      if (!(await this._ensureConnection())) return false;
      const result = await this.client.set(key, value, {
        EX: ttlSeconds,
        NX: true,
      });
      return result === 'OK';
    } catch (error) {
      logger.warn(`Redis SET NX error for key "${key}":`, error.message);
      return false;
    }
  }

  /**
   * Set value with expiry
   * @param {string} key - Cache key
   * @param {number} seconds - TTL in seconds
   * @param {string} value - Value to cache
   * @returns {Promise<boolean>}
   */
  async setex(key, seconds, value) {
    try {
      if (!(await this._ensureConnection())) return false;
      await this.client.setEx(key, seconds, value);
      return true;
    } catch (error) {
      logger.warn(`Redis SETEX error for key "${key}":`, error.message);
      return false;
    }
  }

  /**
   * Delete key from cache
   * @param {string} key - Cache key
   * @returns {Promise<boolean>}
   */
  async del(key) {
    try {
      if (!(await this._ensureConnection())) return false;
      await this.client.del(key);
      return true;
    } catch (error) {
      logger.warn(`Redis DEL error for key "${key}":`, error.message);
      return false;
    }
  }

  /**
   * Delete multiple keys matching pattern
   * @param {string} pattern - Key pattern (e.g., "user:*")
   * @returns {Promise<boolean>}
   */
  async delPattern(pattern) {
    try {
      if (!(await this._ensureConnection())) return false;

      const keys = await this.client.keys(pattern);
      if (keys.length > 0) {
        await this.client.del(keys);
      }
      return true;
    } catch (error) {
      logger.warn(`Redis DEL pattern error for "${pattern}":`, error.message);
      return false;
    }
  }

  /**
   * Check if key exists
   * @param {string} key - Cache key
   * @returns {Promise<boolean>}
   */
  async exists(key) {
    try {
      if (!(await this._ensureConnection())) return false;
      const result = await this.client.exists(key);
      return result === 1;
    } catch (error) {
      logger.warn(`Redis EXISTS error for key "${key}":`, error.message);
      return false;
    }
  }

  /**
   * Increment value
   * @param {string} key - Cache key
   * @returns {Promise<number|null>}
   */
  async incr(key) {
    try {
      if (!(await this._ensureConnection())) return null;
      return await this.client.incr(key);
    } catch (error) {
      logger.warn(`Redis INCR error for key "${key}":`, error.message);
      return null;
    }
  }

  /**
   * Set key expiry
   * @param {string} key - Cache key
   * @param {number} seconds - TTL in seconds
   * @returns {Promise<boolean>}
   */
  async expire(key, seconds) {
    try {
      if (!(await this._ensureConnection())) return false;
      await this.client.expire(key, seconds);
      return true;
    } catch (error) {
      logger.warn(`Redis EXPIRE error for key "${key}":`, error.message);
      return false;
    }
  }

  /**
   * Get or set pattern - fetch from cache or execute function and cache result
   * @param {string} key - Cache key
   * @param {number} ttl - TTL in seconds
   * @param {Function} fetchFn - Function to execute if cache miss
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
      logger.warn(`Redis getOrSet error for key "${key}":`, error.message);
      return await fetchFn();
    }
  }

  /**
   * Publish a message to a channel. Returns the number of subscribers
   * that received it, or null if redis is unavailable.
   */
  async publish(channel, payload) {
    try {
      if (!(await this._ensureConnection())) return null;
      const body = typeof payload === 'string' ? payload : JSON.stringify(payload);
      return await this.client.publish(channel, body);
    } catch (error) {
      logger.warn(`Redis PUBLISH error for channel "${channel}":`, error.message);
      return null;
    }
  }

  /**
   * Close Redis connection
   * @returns {Promise<void>}
   */
  async disconnect() {
    try {
      if (this.client && this.client.isOpen) {
        await this.client.quit();
        logger.info('Redis connection closed');
      }
    } catch (error) {
      logger.error('Error closing Redis connection:', error.message);
    }
  }

  /**
   * Check if Redis is available
   * @returns {boolean}
   */
  isRedisAvailable() {
    return this.isAvailable;
  }
}

// Export singleton instance
module.exports = new RedisClient();
