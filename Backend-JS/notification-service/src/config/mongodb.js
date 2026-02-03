const mongoose = require('mongoose');
const config = require('./index');
const logger = require('../utils/logger');
const { DB_CONFIG } = require('../utils/constants');

/**
 * Database connection manager optimized for 10k concurrent users
 */
class Database {
  constructor() {
    this.isConnected = false;
    this.connectionAttempts = 0;
  }

  /**
   * MongoDB connection configuration optimized for high concurrency
   */
  get connectionOptions() {
    return {
      // Connection pool settings for 10k users
      maxPoolSize: DB_CONFIG.MAX_POOL_SIZE,
      minPoolSize: DB_CONFIG.MIN_POOL_SIZE,

      // Timeout settings
      socketTimeoutMS: DB_CONFIG.SOCKET_TIMEOUT_MS,
      serverSelectionTimeoutMS: DB_CONFIG.SERVER_SELECTION_TIMEOUT_MS,
      heartbeatFrequencyMS: DB_CONFIG.HEARTBEAT_FREQUENCY_MS,
      maxIdleTimeMS: DB_CONFIG.MAX_IDLE_TIME_MS,

      // Retry settings
      retryWrites: true,
      retryReads: true,
    };
  }

  /**
   * Connect to MongoDB with retry logic
   */
  async connect() {
    if (this.isConnected) {
      logger.info('MongoDB already connected');
      return;
    }

    const uri = config.mongodb.uri;
    if (!uri) {
      throw new Error('MONGODB_URI environment variable is not set');
    }

    try {
      await mongoose.connect(uri, this.connectionOptions);
      this.isConnected = true;
      this.connectionAttempts = 0;

      logger.info('MongoDB Connected Successfully');
      logger.info(`  Pool size: ${DB_CONFIG.MIN_POOL_SIZE}-${DB_CONFIG.MAX_POOL_SIZE}`);

      this.setupEventListeners();
    } catch (error) {
      this.connectionAttempts++;
      logger.error(`MongoDB connection failed (attempt ${this.connectionAttempts}):`, error.message);

      if (this.connectionAttempts < DB_CONFIG.MAX_RETRIES) {
        const delay = Math.min(1000 * Math.pow(2, this.connectionAttempts), 30000);
        logger.info(`Retrying in ${delay / 1000} seconds...`);
        await new Promise(resolve => setTimeout(resolve, delay));
        return this.connect();
      }

      throw error;
    }
  }

  /**
   * Setup MongoDB event listeners
   */
  setupEventListeners() {
    mongoose.connection.on('connected', () => {
      this.isConnected = true;
      logger.info('MongoDB connection established');
    });

    mongoose.connection.on('error', (err) => {
      logger.error('MongoDB connection error:', err.message);
    });

    mongoose.connection.on('disconnected', () => {
      this.isConnected = false;
      logger.warn('MongoDB disconnected');
    });

    mongoose.connection.on('reconnected', () => {
      this.isConnected = true;
      logger.info('MongoDB reconnected');
    });
  }

  /**
   * Close connection gracefully
   */
  async disconnect() {
    if (!this.isConnected) return;

    try {
      await mongoose.connection.close();
      this.isConnected = false;
      logger.info('MongoDB connection closed');
    } catch (error) {
      logger.error('Error closing MongoDB connection:', error.message);
    }
  }

  /**
   * Get connection status
   * @returns {boolean}
   */
  getStatus() {
    return mongoose.connection.readyState === 1;
  }

  /**
   * Get connection statistics
   * @returns {Object}
   */
  getStats() {
    const { connection } = mongoose;
    return {
      readyState: connection.readyState,
      host: connection.host,
      port: connection.port,
      name: connection.name,
      isConnected: this.isConnected,
    };
  }
}

const database = new Database();

// Export for backward compatibility
const connectDB = () => database.connect();

module.exports = {
  connectDB,
  Database: database,
};
