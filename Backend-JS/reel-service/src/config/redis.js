// Modify redis.js to handle connection failures gracefully
const Redis = require("ioredis");

let redisClient;

try {
  redisClient = new Redis({
    host: process.env.REDIS_HOST || "localhost",
    port: process.env.REDIS_PORT || 6379,
    retryStrategy(times) {
      const delay = Math.min(times * 50, 2000);
      return delay;
    },
    maxRetriesPerRequest: 3,
  });

  redisClient.on("error", (err) => {
    console.error("Redis Client Error:", err);
  });

  redisClient.on("connect", () => {
    console.log("Redis Client Connected");
  });
} catch (error) {
  console.error("Redis Connection Error:", error);
  // Fallback to a dummy cache if Redis is unavailable
  redisClient = {
    get: async () => null,
    set: async () => null,
    setex: async () => null,
    del: async () => null,
  };
}

module.exports = redisClient;
