const Redis = require("redis");

class RedisClient {
    constructor() {
        this.client = Redis.createClient({
            host: process.env.REDIS_HOST || 'localhost',
            port: process.env.REDIS_PORT || 6379,
            // password: process.env.REDIS_PASSWORD,
        });

        this.client.on('connect', () => {
            console.log('Redis client connected');
        });

        this.client.on('error', (err) => {
            console.error('Redis client error:', err);
        });

        this.client.connect().catch((err) => {
            console.error('Failed to connect to Redis:', err);
        });
    }

    async get(key) {
        if (!this.client.isOpen) {
            await this.client.connect();
        }
        return this.client.get(key);
    }

    async set(key, value) {
        if (!this.client.isOpen) {
            await this.client.connect();
        }
        return this.client.set(key, value);
    }

    async setex(key, seconds, value) {
        if (!this.client.isOpen) {
            await this.client.connect();
        }
        return this.client.setEx(key, seconds, value);
    }

    async del(key) {
        if (!this.client.isOpen) {
            await this.client.connect();
        }
        return this.client.del(key);
    }
}

module.exports = new RedisClient();
