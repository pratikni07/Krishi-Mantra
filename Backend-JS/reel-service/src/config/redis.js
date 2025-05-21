// Modify redis.js to handle connection failures gracefully
const Redis = require("ioredis");

let redisClient;

try {
  // Get Redis password from environment variables
  const redisPassword = process.env.REDIS_PASSWORD;

  // Create Redis client with or without password based on configuration
  const config = {
    host: process.env.REDIS_HOST || "localhost",
    port: process.env.REDIS_PORT || 6379,
    retryStrategy(times) {
      const delay = Math.min(times * 50, 2000);
      return delay;
    },
    maxRetriesPerRequest: 3,
  };

  // Only add password if it exists and is not empty
  if (redisPassword && redisPassword.trim() !== "") {
    config.password = redisPassword;
  }

  redisClient = new Redis(config);

  redisClient.on("error", (err) => {
    console.error("Redis Client Error:", err);
  });

  redisClient.on("connect", () => {
    console.log("Redis Client Connected");
  });
} catch (error) {
  console.error("Redis Connection Error:", error);
  // Fallback to a dummy cache if Redis is unavailable
  redisClient = createDummyRedisClient();
}

// Create a dummy Redis client for fallback
function createDummyRedisClient() {
  console.warn("Using dummy Redis client - caching disabled");
  return {
    get: async () => null,
    set: async () => null,
    setex: async () => null,
    del: async () => null,
    keys: async () => [],
    // Add any other Redis methods used in your application
  };
}

// Wrap Redis operations with error handling
const redis = {
  async get(key) {
    try {
      return await redisClient.get(key);
    } catch (error) {
      console.warn(`Redis GET error for key ${key}:`, error.message);
      return null;
    }
  },

  async set(key, value) {
    try {
      return await redisClient.set(key, value);
    } catch (error) {
      console.warn(`Redis SET error for key ${key}:`, error.message);
      return null;
    }
  },

  async setex(key, seconds, value) {
    try {
      return await redisClient.setex(key, seconds, value);
    } catch (error) {
      console.warn(`Redis SETEX error for key ${key}:`, error.message);
      return null;
    }
  },

  async del(key) {
    try {
      return await redisClient.del(key);
    } catch (error) {
      console.warn(`Redis DEL error for key ${key}:`, error.message);
      return null;
    }
  },

  async keys(pattern) {
    try {
      return await redisClient.keys(pattern);
    } catch (error) {
      console.warn(`Redis KEYS error for pattern ${pattern}:`, error.message);
      return [];
    }
  },

  // Add the raw client for any direct operations
  client: redisClient,
};

module.exports = redis;
