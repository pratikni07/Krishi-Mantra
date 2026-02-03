const mongoose = require('mongoose');
const { DB_CONFIG } = require('../utils/constants');

/**
 * MongoDB connection configuration optimized for 10k concurrent users
 */
const dbConfig = {
  maxPoolSize: DB_CONFIG.MAX_POOL_SIZE,
  minPoolSize: DB_CONFIG.MIN_POOL_SIZE,
  socketTimeoutMS: DB_CONFIG.SOCKET_TIMEOUT_MS,
  serverSelectionTimeoutMS: DB_CONFIG.SERVER_SELECTION_TIMEOUT_MS,
  heartbeatFrequencyMS: DB_CONFIG.HEARTBEAT_FREQUENCY_MS,
  maxIdleTimeMS: DB_CONFIG.MAX_IDLE_TIME_MS,
  retryWrites: true,
  retryReads: true,
};

/**
 * Connect to MongoDB with optimized settings
 * @returns {Promise<void>}
 */
const connect = async () => {
  const mongoUrl = process.env.MONGODB_URI;

  if (!mongoUrl) {
    throw new Error('MONGODB_URI environment variable is not set');
  }

  await mongoose.connect(mongoUrl, dbConfig);
  console.log('MongoDB connected successfully');

  // Connection event handlers
  mongoose.connection.on('error', (err) => {
    console.error('MongoDB connection error:', err);
  });

  mongoose.connection.on('disconnected', () => {
    console.warn('MongoDB disconnected. Attempting to reconnect...');
  });

  mongoose.connection.on('reconnected', () => {
    console.log('MongoDB reconnected successfully');
  });

  // Log pool statistics in development
  if (process.env.NODE_ENV !== 'production') {
    mongoose.connection.on('connected', () => {
      console.log(`MongoDB pool size: ${DB_CONFIG.MAX_POOL_SIZE}`);
    });
  }
};

/**
 * Close MongoDB connection gracefully
 * @returns {Promise<void>}
 */
const disconnect = async () => {
  await mongoose.connection.close();
  console.log('MongoDB connection closed');
};

/**
 * Get connection status
 * @returns {boolean}
 */
const isConnected = () => {
  return mongoose.connection.readyState === 1;
};

/**
 * Get connection statistics
 * @returns {Object}
 */
const getStats = () => {
  const { connection } = mongoose;
  return {
    readyState: connection.readyState,
    host: connection.host,
    port: connection.port,
    name: connection.name,
  };
};

module.exports = {
  connect,
  disconnect,
  isConnected,
  getStats,
  dbConfig,
};
