const Redis = require("redis");

class RedisClient {
  constructor() {
    this.client = Redis.createClient({
      host: process.env.REDIS_HOST || "localhost",
      port: process.env.REDIS_PORT || 6379,
      // password: process.env.REDIS_PASSWORD,
    });

    this.isRedisAvailable = false;

    this.client.on("connect", () => {
      this.isRedisAvailable = true;
      console.log("Redis client connected");
    });

    this.client.on("error", (err) => {
      this.isRedisAvailable = false;
      console.warn("Redis client error:", err.message);
    });

    this.client.on("end", () => {
      this.isRedisAvailable = false;
      console.warn("Redis connection ended");
    });

    // Attempt to connect to Redis, but don't block application startup
    this.connect().catch(err => {
      console.warn("Redis initial connection failed:", err.message);
      console.warn("Application will continue without Redis caching");
    });
  }

  async connect() {
    try {
      if (!this.client.isOpen) {
        await this.client.connect();
      }
      return true;
    } catch (error) {
      this.isRedisAvailable = false;
      console.warn(`Redis connect error:`, error.message);
      return false;
    }
  }

  async get(key) {
    try {
      if (!this.isRedisAvailable) return null;
      if (!this.client.isOpen) {
        await this.client.connect();
      }
      return await this.client.get(key);
    } catch (error) {
      console.warn(`Redis get error for key ${key}:`, error.message);
      return null;
    }
  }

  async set(key, value, options = {}) {
    try {
      if (!this.isRedisAvailable) return false;
      if (!this.client.isOpen) {
        await this.client.connect();
      }
      if (options.EX) {
        return await this.client.set(key, value, { EX: options.EX });
      }
      return await this.client.set(key, value);
    } catch (error) {
      console.warn(`Redis set error for key ${key}:`, error.message);
      return false;
    }
  }

  async setex(key, seconds, value) {
    try {
      if (!this.isRedisAvailable) return false;
      if (!this.client.isOpen) {
        await this.client.connect();
      }
      return await this.client.setEx(key, seconds, value);
    } catch (error) {
      console.warn(`Redis setex error for key ${key}:`, error.message);
      return false;
    }
  }

  async del(key) {
    try {
      if (!this.isRedisAvailable) return false;
      if (!this.client.isOpen) {
        await this.client.connect();
      }
      return await this.client.del(key);
    } catch (error) {
      console.warn(`Redis del error for key ${key}:`, error.message);
      return false;
    }
  }
}

module.exports = new RedisClient();
