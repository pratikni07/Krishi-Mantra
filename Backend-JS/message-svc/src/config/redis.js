const Redis = require("redis");
const { promisify } = require("util");

class RedisClient {
  constructor() {
    this.client = Redis.createClient({
      host: process.env.REDIS_HOST || "localhost",
      port: process.env.REDIS_PORT || 6379,
      // password: process.env.REDIS_PASSWORD,
      retryStrategy: (times) => {
        const delay = Math.min(times * 50, 2000);
        return delay;
      },
      maxRetriesPerRequest: 3,
    });

    this.client.on("connect", () => {
      console.log("Redis client connected");
    });

    this.client.on("error", (err) => {
      console.error("Redis client error:", err);
    });

    this.client.on("reconnecting", () => {
      console.log("Redis client reconnecting");
    });

    this.connect().catch((err) => {
      console.error("Failed to connect to Redis:", err);
    });

    // Graceful shutdown
    process.on("SIGINT", async () => {
      try {
        await this.client.quit();
        console.log("Redis connection closed through app termination");
      } catch (err) {
        console.error("Error during Redis disconnect:", err);
      }
    });
  }

  async connect() {
    if (!this.client.isOpen) {
      await this.client.connect();
    }
  }

  async get(key) {
    try {
      await this.connect();
      return await this.client.get(key);
    } catch (error) {
      console.error("Redis get error:", error);
      throw error;
    }
  }

  async set(key, value, options = {}) {
    try {
      await this.connect();
      return await this.client.set(key, value, options);
    } catch (error) {
      console.error("Redis set error:", error);
      throw error;
    }
  }

  async setex(key, seconds, value) {
    try {
      await this.connect();
      return await this.client.setEx(key, seconds, value);
    } catch (error) {
      console.error("Redis setex error:", error);
      throw error;
    }
  }

  async del(key) {
    try {
      await this.connect();
      return await this.client.del(key);
    } catch (error) {
      console.error("Redis del error:", error);
      throw error;
    }
  }

  async hset(key, field, value) {
    try {
      await this.connect();
      return await this.client.hSet(key, field, value);
    } catch (error) {
      console.error("Redis hset error:", error);
      throw error;
    }
  }

  async hget(key, field) {
    try {
      await this.connect();
      return await this.client.hGet(key, field);
    } catch (error) {
      console.error("Redis hget error:", error);
      throw error;
    }
  }

  async publish(channel, message) {
    try {
      await this.connect();
      return await this.client.publish(channel, message);
    } catch (error) {
      console.error("Redis publish error:", error);
      throw error;
    }
  }

  async subscribe(channel, callback) {
    try {
      await this.connect();
      return await this.client.subscribe(channel, callback);
    } catch (error) {
      console.error("Redis subscribe error:", error);
      throw error;
    }
  }
  async hDel(key, field) {
    try {
      await this.connect();
      return await this.client.hDel(key, field);
    } catch (error) {
      console.error("Redis hdel error:", error);
      throw error;
    }
  }
}

module.exports = new RedisClient();
