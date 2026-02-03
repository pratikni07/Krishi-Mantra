const mongoose = require('mongoose');
const { DB_CONFIG } = require('../utils/constants');

/**
 * Database singleton class optimized for 10k concurrent connections
 */
class Database {
  constructor() {
    this.mongoURI = process.env.MONGODB_URI || 'mongodb://localhost:27017/farmer-chat';
    this.isConnected = false;
  }

  /**
   * MongoDB connection configuration optimized for high concurrency
   */
  get connectionOptions() {
    return {
      maxPoolSize: DB_CONFIG.MAX_POOL_SIZE,
      minPoolSize: DB_CONFIG.MIN_POOL_SIZE,
      socketTimeoutMS: DB_CONFIG.SOCKET_TIMEOUT_MS,
      serverSelectionTimeoutMS: DB_CONFIG.SERVER_SELECTION_TIMEOUT_MS,
      heartbeatFrequencyMS: DB_CONFIG.HEARTBEAT_FREQUENCY_MS,
      maxIdleTimeMS: DB_CONFIG.MAX_IDLE_TIME_MS,
      retryWrites: true,
      retryReads: true,
    };
  }

  async connect() {
    try {
      await mongoose.connect(this.mongoURI, this.connectionOptions);
      this.isConnected = true;

      mongoose.connection.on('connected', () => {
        console.log('MongoDB connected successfully');
        console.log(`Connection pool size: ${DB_CONFIG.MAX_POOL_SIZE}`);
      });

      mongoose.connection.on('error', (err) => {
        console.error('MongoDB connection error:', err);
        this.isConnected = false;
      });

      mongoose.connection.on('disconnected', () => {
        console.warn('MongoDB disconnected');
        this.isConnected = false;
      });

      mongoose.connection.on('reconnected', () => {
        console.log('MongoDB reconnected');
        this.isConnected = true;
      });

    } catch (error) {
      console.error('MongoDB connection failed:', error);
      throw error;
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

  /**
   * Close connection gracefully
   */
  async disconnect() {
    try {
      await mongoose.connection.close();
      console.log('MongoDB connection closed');
      this.isConnected = false;
    } catch (err) {
      console.error('Error closing MongoDB connection:', err);
    }
  }
}

module.exports = new Database();
