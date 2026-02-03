const mongoose = require('mongoose');
const { DB_CONFIG } = require('../utils/constants');

/**
 * Database connection manager optimized for 10k concurrent users
 */
class Database {
  constructor() {
    this.isConnected = false;
    this.connectionAttempts = 0;
    this.maxRetries = 5;
  }

  get connectionOptions() {
    return {
      // Connection pool settings for high concurrency
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

  async connect() {
    if (this.isConnected) {
      console.log('MongoDB already connected');
      return;
    }

    const uri = process.env.MONGODB_URI;
    if (!uri) {
      throw new Error('MONGODB_URI environment variable is not set');
    }

    try {
      await mongoose.connect(uri, this.connectionOptions);
      this.isConnected = true;
      this.connectionAttempts = 0;
      console.log('MongoDB Connected Successfully');
      console.log(`  Pool size: ${DB_CONFIG.MIN_POOL_SIZE}-${DB_CONFIG.MAX_POOL_SIZE}`);

      this.setupEventListeners();
    } catch (error) {
      this.connectionAttempts++;
      console.error(`MongoDB connection failed (attempt ${this.connectionAttempts}):`, error.message);

      if (this.connectionAttempts < this.maxRetries) {
        const delay = Math.min(1000 * Math.pow(2, this.connectionAttempts), 30000);
        console.log(`Retrying in ${delay / 1000} seconds...`);
        await new Promise(resolve => setTimeout(resolve, delay));
        return this.connect();
      }

      throw error;
    }
  }

  setupEventListeners() {
    mongoose.connection.on('connected', () => {
      this.isConnected = true;
      console.log('MongoDB connection established');
    });

    mongoose.connection.on('error', (err) => {
      console.error('MongoDB connection error:', err.message);
    });

    mongoose.connection.on('disconnected', () => {
      this.isConnected = false;
      console.warn('MongoDB disconnected');
    });

    mongoose.connection.on('reconnected', () => {
      this.isConnected = true;
      console.log('MongoDB reconnected');
    });
  }

  async disconnect() {
    if (!this.isConnected) return;

    try {
      await mongoose.connection.close();
      this.isConnected = false;
      console.log('MongoDB connection closed');
    } catch (error) {
      console.error('Error closing MongoDB connection:', error.message);
    }
  }

  getStatus() {
    return this.isConnected;
  }
}

const database = new Database();

// Export the connect function for backward compatibility
const connectDB = () => database.connect();

module.exports = connectDB;
module.exports.Database = database;
