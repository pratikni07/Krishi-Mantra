const mongoose = require('mongoose');
const config = require('./index');
const logger = require('../utils/logger');

let isConnected = false;

/**
 * MongoDB Database Connection Manager
 * Optimized for 100k+ concurrent users with connection pooling
 */
class Database {
  static async connect() {
    if (isConnected) {
      logger.info('Using existing MongoDB connection');
      return;
    }

    try {
      mongoose.set('strictQuery', false);

      // Connection event handlers
      mongoose.connection.on('connected', () => {
        isConnected = true;
        logger.info('MongoDB Connected Successfully', {
          host: mongoose.connection.host,
          name: mongoose.connection.name,
        });
      });

      mongoose.connection.on('error', (err) => {
        logger.error('MongoDB connection error:', err);
        isConnected = false;
      });

      mongoose.connection.on('disconnected', () => {
        logger.warn('MongoDB disconnected. Attempting to reconnect...');
        isConnected = false;
      });

      mongoose.connection.on('reconnected', () => {
        logger.info('MongoDB reconnected');
        isConnected = true;
      });

      // Connect with optimized options
      await mongoose.connect(config.mongodb.uri, config.mongodb.options);

      logger.info(`MongoDB pool size: ${config.mongodb.options.minPoolSize}-${config.mongodb.options.maxPoolSize}`);

    } catch (error) {
      logger.error('MongoDB connection failed:', error);
      throw error;
    }
  }

  static async disconnect() {
    if (!isConnected) return;

    try {
      await mongoose.connection.close();
      isConnected = false;
      logger.info('MongoDB connection closed');
    } catch (error) {
      logger.error('Error closing MongoDB connection:', error);
      throw error;
    }
  }

  static getStatus() {
    return isConnected && mongoose.connection.readyState === 1;
  }

  static getConnection() {
    return mongoose.connection;
  }
}

module.exports = Database;
