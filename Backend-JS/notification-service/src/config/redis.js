const Redis = require('ioredis');
const config = require('./index');
const logger = require('../utils/logger');

const redisClient = new Redis({
  host: config.redis.host,
  port: config.redis.port,
  maxRetriesPerRequest: 3,
  retryStrategy: (times) => {
    const delay = Math.min(times * 50, 2000);
    return delay;
  }
});

redisClient.on('connect', () => {
  logger.info('Redis connected successfully');
});

redisClient.on('error', (error) => {
  logger.error('Redis connection error:', error);
});

module.exports = redisClient; 