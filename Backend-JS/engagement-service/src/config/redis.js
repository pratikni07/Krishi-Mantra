const Redis = require('ioredis');
const config = require('./index');
const logger = require('../utils/logger');

let redisClient = null;
let isConnected = false;
let isFallback = false;

// In-memory LRU cache as fallback
const memoryCache = new Map();
const MAX_CACHE_SIZE = 50000; // Increased for 100k users
const cacheTimestamps = new Map();

/**
 * Redis Client Manager with in-memory fallback
 * Optimized for 100k+ concurrent users
 */
class RedisManager {
  static async connect() {
    try {
      redisClient = new Redis({
        host: config.redis.host,
        port: config.redis.port,
        password: config.redis.password || undefined,
        keyPrefix: config.redis.keyPrefix,
        maxRetriesPerRequest: config.redis.maxRetriesPerRequest,
        enableReadyCheck: config.redis.enableReadyCheck,
        lazyConnect: config.redis.lazyConnect,
        retryDelayOnFailover: 100,
        retryDelayOnClusterDown: 100,
        connectTimeout: 10000,
      });

      redisClient.on('connect', () => {
        logger.info('Redis client connected');
      });

      redisClient.on('ready', () => {
        isConnected = true;
        isFallback = false;
        logger.info('Redis client ready');
      });

      redisClient.on('error', (err) => {
        logger.error('Redis client error:', err.message);
        isConnected = false;
        isFallback = true;
      });

      redisClient.on('close', () => {
        logger.warn('Redis connection closed');
        isConnected = false;
      });

      await redisClient.connect();
    } catch (error) {
      logger.warn('Redis connection failed, using in-memory cache:', error.message);
      isFallback = true;
      isConnected = false;
    }
  }

  static async disconnect() {
    if (redisClient) {
      await redisClient.quit();
      redisClient = null;
      isConnected = false;
      logger.info('Redis disconnected');
    }
  }

  static getClient() {
    return redisClient;
  }

  static isConnected() {
    return isConnected;
  }

  static isFallback() {
    return isFallback;
  }

  // Cache operations with fallback
  static async get(key) {
    try {
      if (isConnected && redisClient) {
        return await redisClient.get(key);
      }
      return this._memoryGet(key);
    } catch (error) {
      logger.error('Redis get error:', error.message);
      return this._memoryGet(key);
    }
  }

  static async set(key, value, ttl = config.redis.ttl) {
    try {
      if (isConnected && redisClient) {
        if (ttl) {
          return await redisClient.setex(key, ttl, value);
        }
        return await redisClient.set(key, value);
      }
      return this._memorySet(key, value, ttl);
    } catch (error) {
      logger.error('Redis set error:', error.message);
      return this._memorySet(key, value, ttl);
    }
  }

  static async del(key) {
    try {
      if (isConnected && redisClient) {
        return await redisClient.del(key);
      }
      memoryCache.delete(key);
      cacheTimestamps.delete(key);
      return 1;
    } catch (error) {
      logger.error('Redis del error:', error.message);
      memoryCache.delete(key);
      return 0;
    }
  }

  static async incr(key) {
    try {
      if (isConnected && redisClient) {
        return await redisClient.incr(key);
      }
      const current = parseInt(this._memoryGet(key) || '0', 10);
      this._memorySet(key, (current + 1).toString());
      return current + 1;
    } catch (error) {
      logger.error('Redis incr error:', error.message);
      return 0;
    }
  }

  static async incrby(key, increment) {
    try {
      if (isConnected && redisClient) {
        return await redisClient.incrby(key, increment);
      }
      const current = parseInt(this._memoryGet(key) || '0', 10);
      this._memorySet(key, (current + increment).toString());
      return current + increment;
    } catch (error) {
      logger.error('Redis incrby error:', error.message);
      return 0;
    }
  }

  static async hset(key, field, value) {
    try {
      if (isConnected && redisClient) {
        return await redisClient.hset(key, field, value);
      }
      const hash = JSON.parse(this._memoryGet(key) || '{}');
      hash[field] = value;
      this._memorySet(key, JSON.stringify(hash));
      return 1;
    } catch (error) {
      logger.error('Redis hset error:', error.message);
      return 0;
    }
  }

  static async hget(key, field) {
    try {
      if (isConnected && redisClient) {
        return await redisClient.hget(key, field);
      }
      const hash = JSON.parse(this._memoryGet(key) || '{}');
      return hash[field];
    } catch (error) {
      logger.error('Redis hget error:', error.message);
      return null;
    }
  }

  static async hgetall(key) {
    try {
      if (isConnected && redisClient) {
        return await redisClient.hgetall(key);
      }
      return JSON.parse(this._memoryGet(key) || '{}');
    } catch (error) {
      logger.error('Redis hgetall error:', error.message);
      return {};
    }
  }

  static async hincrby(key, field, increment) {
    try {
      if (isConnected && redisClient) {
        return await redisClient.hincrby(key, field, increment);
      }
      const hash = JSON.parse(this._memoryGet(key) || '{}');
      hash[field] = (parseInt(hash[field] || '0', 10) + increment).toString();
      this._memorySet(key, JSON.stringify(hash));
      return parseInt(hash[field], 10);
    } catch (error) {
      logger.error('Redis hincrby error:', error.message);
      return 0;
    }
  }

  static async zadd(key, score, member) {
    try {
      if (isConnected && redisClient) {
        return await redisClient.zadd(key, score, member);
      }
      // Simplified fallback for sorted sets
      const set = JSON.parse(this._memoryGet(key) || '[]');
      const existing = set.findIndex((item) => item.member === member);
      if (existing >= 0) {
        set[existing].score = score;
      } else {
        set.push({ member, score });
      }
      set.sort((a, b) => b.score - a.score);
      this._memorySet(key, JSON.stringify(set));
      return 1;
    } catch (error) {
      logger.error('Redis zadd error:', error.message);
      return 0;
    }
  }

  static async zrevrange(key, start, stop, withScores = false) {
    try {
      if (isConnected && redisClient) {
        if (withScores) {
          return await redisClient.zrevrange(key, start, stop, 'WITHSCORES');
        }
        return await redisClient.zrevrange(key, start, stop);
      }
      const set = JSON.parse(this._memoryGet(key) || '[]');
      const slice = set.slice(start, stop + 1);
      if (withScores) {
        return slice.flatMap((item) => [item.member, item.score.toString()]);
      }
      return slice.map((item) => item.member);
    } catch (error) {
      logger.error('Redis zrevrange error:', error.message);
      return [];
    }
  }

  static async expire(key, seconds) {
    try {
      if (isConnected && redisClient) {
        return await redisClient.expire(key, seconds);
      }
      // Update expiry in memory cache
      const timestamp = cacheTimestamps.get(key);
      if (timestamp) {
        cacheTimestamps.set(key, Date.now() + seconds * 1000);
      }
      return 1;
    } catch (error) {
      logger.error('Redis expire error:', error.message);
      return 0;
    }
  }

  static async pipeline() {
    if (isConnected && redisClient) {
      return redisClient.pipeline();
    }
    // Return mock pipeline for fallback
    return {
      commands: [],
      incr(key) {
        this.commands.push({ op: 'incr', key });
        return this;
      },
      hincrby(key, field, value) {
        this.commands.push({ op: 'hincrby', key, field, value });
        return this;
      },
      zadd(key, score, member) {
        this.commands.push({ op: 'zadd', key, score, member });
        return this;
      },
      expire(key, ttl) {
        this.commands.push({ op: 'expire', key, ttl });
        return this;
      },
      async exec() {
        for (const cmd of this.commands) {
          switch (cmd.op) {
            case 'incr':
              await RedisManager.incr(cmd.key);
              break;
            case 'hincrby':
              await RedisManager.hincrby(cmd.key, cmd.field, cmd.value);
              break;
            case 'zadd':
              await RedisManager.zadd(cmd.key, cmd.score, cmd.member);
              break;
            case 'expire':
              await RedisManager.expire(cmd.key, cmd.ttl);
              break;
          }
        }
        return this.commands.map(() => [null, 'OK']);
      },
    };
  }

  // Private memory cache helpers
  static _memoryGet(key) {
    const timestamp = cacheTimestamps.get(key);
    if (timestamp && Date.now() > timestamp) {
      memoryCache.delete(key);
      cacheTimestamps.delete(key);
      return null;
    }
    return memoryCache.get(key);
  }

  static _memorySet(key, value, ttl = config.redis.ttl) {
    // Evict oldest entries if cache is full
    if (memoryCache.size >= MAX_CACHE_SIZE) {
      const oldestKey = memoryCache.keys().next().value;
      memoryCache.delete(oldestKey);
      cacheTimestamps.delete(oldestKey);
    }
    memoryCache.set(key, value);
    if (ttl) {
      cacheTimestamps.set(key, Date.now() + ttl * 1000);
    }
    return 'OK';
  }
}

module.exports = RedisManager;
