const Redis = require("ioredis");

let redisClient;
let useDummyClient = false;

function createDummyRedisClient() {
  console.warn("Using dummy Redis client - caching disabled");

  const dummyCache = new Map(); // In-memory cache as fallback

  return {
    get: async (key) => {
      console.log(`[Dummy Redis] GET ${key}`);
      return dummyCache.get(key) || null;
    },
    set: async (key, value) => {
      console.log(`[Dummy Redis] SET ${key}`);
      dummyCache.set(key, value);
      return "OK";
    },
    setex: async (key, seconds, value) => {
      console.log(`[Dummy Redis] SETEX ${key} ${seconds}`);
      dummyCache.set(key, value);
      // For a production app, we would handle expiry too
      return "OK";
    },
    del: async (key) => {
      console.log(`[Dummy Redis] DEL ${key}`);
      if (typeof key === "string" && key.includes("*")) {
        // Handle wildcard deletion
        const prefix = key.replace("*", "");
        const keysToDelete = Array.from(dummyCache.keys()).filter((k) =>
          k.startsWith(prefix)
        );

        let count = 0;
        for (const k of keysToDelete) {
          if (dummyCache.delete(k)) count++;
        }
        return count;
      }
      return dummyCache.delete(key) ? 1 : 0;
    },
    keys: async (pattern) => {
      console.log(`[Dummy Redis] KEYS ${pattern}`);
      return Array.from(dummyCache.keys()).filter((k) =>
        pattern.includes("*")
          ? k.startsWith(pattern.replace("*", ""))
          : k === pattern
      );
    },
    disconnect: () => {
      console.log(`[Dummy Redis] Disconnected`);
    },
    info: async () => {
      return "dummy:redis";
    },
  };
}

// Function to switch to dummy client
function switchToDummyClient() {
  if (!useDummyClient) {
    console.warn("Redis authentication failed - switching to dummy client");
    useDummyClient = true;
    try {
      if (redisClient && typeof redisClient.disconnect === "function") {
        redisClient.disconnect();
      }
    } catch (e) {
      console.warn("Error disconnecting Redis client:", e.message);
    }
    redisClient = createDummyRedisClient();
  }
}

try {
  // Get Redis password from environment variables
  const redisPassword = process.env.REDIS_PASSWORD;

  // Create Redis client with or without password based on configuration
  const config = {
    host: process.env.REDIS_HOST || "localhost",
    port: process.env.REDIS_PORT || 6379,
    retryStrategy(times) {
      if (useDummyClient) return false; // Stop retrying if we're using dummy client
      const delay = Math.min(times * 50, 2000);
      return delay;
    },
    maxRetriesPerRequest: 2,
    connectTimeout: 5000,
    enableOfflineQueue: false,
  };

  // Only add password if it exists and is not empty
  if (redisPassword && redisPassword.trim() !== "") {
    config.password = redisPassword;
  }

  redisClient = new Redis(config);

  // Set a connection timeout
  let connectTimeout = setTimeout(() => {
    console.error("Redis connection timeout - falling back to dummy client");
    switchToDummyClient();
  }, 5000);

  redisClient.on("error", (err) => {
    console.error("Redis Client Error:", err);

    // If we get auth errors, switch to dummy client
    if (
      (err.message.includes("NOAUTH") || err.message.includes("AUTH")) &&
      !useDummyClient
    ) {
      switchToDummyClient();
    }
  });

  redisClient.on("connect", () => {
    console.log("Redis Client Connected");
    clearTimeout(connectTimeout);

    // Test authentication immediately after connection
    redisClient
      .info()
      .then(() => {
        console.log("Redis authentication successful");
      })
      .catch((error) => {
        if (
          error.message.includes("NOAUTH") ||
          error.message.includes("AUTH")
        ) {
          console.warn("Redis authentication failed during initial test");
          switchToDummyClient();
        }
      });
  });
} catch (error) {
  console.error("Redis Connection Error:", error);
  // Fallback to a dummy cache if Redis is unavailable
  switchToDummyClient();
}

// Wrap Redis operations with error handling
const redis = {
  async get(key) {
    try {
      return await redisClient.get(key);
    } catch (error) {
      console.warn(`Redis GET error for key ${key}:`, error.message);

      // Switch to dummy client if auth error
      if (
        (error.message.includes("NOAUTH") || error.message.includes("AUTH")) &&
        !useDummyClient
      ) {
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
      console.warn(`Redis SET error for key ${key}:`, error.message);

      // Switch to dummy client if auth error
      if (
        (error.message.includes("NOAUTH") || error.message.includes("AUTH")) &&
        !useDummyClient
      ) {
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
      console.warn(`Redis SETEX error for key ${key}:`, error.message);

      // Switch to dummy client if auth error
      if (
        (error.message.includes("NOAUTH") || error.message.includes("AUTH")) &&
        !useDummyClient
      ) {
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
      console.warn(`Redis DEL error for key ${key}:`, error.message);

      // Switch to dummy client if auth error
      if (
        (error.message.includes("NOAUTH") || error.message.includes("AUTH")) &&
        !useDummyClient
      ) {
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
      console.warn(`Redis KEYS error for pattern ${pattern}:`, error.message);

      // Switch to dummy client if auth error
      if (
        (error.message.includes("NOAUTH") || error.message.includes("AUTH")) &&
        !useDummyClient
      ) {
        switchToDummyClient();
        return redisClient.keys(pattern);
      }

      return [];
    }
  },

  // Add the raw client for any direct operations
  client: redisClient,

  // Add a helper to check if we're using the dummy client
  isDummyClient: () => useDummyClient,
};

module.exports = redis;
