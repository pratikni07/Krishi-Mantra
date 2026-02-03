const mongoose = require('mongoose');
const logger = require('../utils/logger');
const { DB_CONFIG } = require('../utils/constants');

/**
 * MongoDB connection configuration
 * Optimized for 10k concurrent users
 */
const dbConfig = {
  maxPoolSize: DB_CONFIG.MAX_POOL_SIZE,
  minPoolSize: DB_CONFIG.MIN_POOL_SIZE,
  socketTimeoutMS: DB_CONFIG.SOCKET_TIMEOUT_MS,
  serverSelectionTimeoutMS: DB_CONFIG.SERVER_SELECTION_TIMEOUT_MS,
  heartbeatFrequencyMS: DB_CONFIG.HEARTBEAT_FREQUENCY_MS,
  maxIdleTimeMS: DB_CONFIG.MAX_IDLE_TIME_MS,
  retryWrites: true,
};

/**
 * Connect to MongoDB
 * @returns {Promise<void>}
 */
const connect = async () => {
  try {
    const mongoUrl = process.env.MONGODB_URL;

    if (!mongoUrl) {
      throw new Error('MONGODB_URL environment variable is not set');
    }

    await mongoose.connect(mongoUrl, dbConfig);
    logger.info('MongoDB connected successfully');

    // Connection event handlers
    mongoose.connection.on('error', (err) => {
      logger.error('MongoDB connection error:', err);
    });

    mongoose.connection.on('disconnected', () => {
      logger.warn('MongoDB disconnected. Attempting to reconnect...');
    });

    mongoose.connection.on('reconnected', () => {
      logger.info('MongoDB reconnected successfully');
    });

  } catch (error) {
    logger.error('MongoDB connection failed:', error.message);
    process.exit(1);
  }
};

/**
 * Close MongoDB connection gracefully
 * @returns {Promise<void>}
 */
const disconnect = async () => {
  try {
    await mongoose.connection.close();
    logger.info('MongoDB connection closed');
  } catch (error) {
    logger.error('Error closing MongoDB connection:', error.message);
  }
};

/**
 * Get connection status
 * @returns {boolean}
 */
const isConnected = () => {
  return mongoose.connection.readyState === 1;
};

module.exports = {
  connect,
  disconnect,
  isConnected,
};
