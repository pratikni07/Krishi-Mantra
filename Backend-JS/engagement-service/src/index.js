/**
 * Engagement Service
 * Production-ready user activity tracking and analytics
 * Designed for 100k+ concurrent users
 */

const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const compression = require('compression');
const morgan = require('morgan');

const config = require('./config');
const Database = require('./config/database');
const Redis = require('./config/redis');
const RabbitMQ = require('./config/rabbitmq');
const routes = require('./routes');
const { notFoundHandler, errorHandler } = require('./middlewares/errorHandler');
const { eventRateLimiter, analyticsRateLimiter } = require('./middlewares/rateLimiter');
const EventService = require('./services/eventService');
const AggregationWorker = require('./workers/aggregationWorker');
const mongoSanitize = require('./middlewares/mongoSanitize');
const logger = require('./utils/logger');

const app = express();

// Trust proxy (for rate limiting behind load balancer)
app.set('trust proxy', 1);

// Security middleware
app.use(helmet());

// CORS
app.use(
  cors({
    origin: config.cors.origin,
    credentials: true,
  })
);

// Compression for responses
app.use(compression());

// Request logging
if (config.nodeEnv === 'development') {
  app.use(morgan('dev'));
} else {
  app.use(
    morgan('combined', {
      stream: { write: (message) => logger.info(message.trim()) },
    })
  );
}

// Body parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Strip Mongo operator keys ($-prefixed / dotted) from req input before any
// controller reaches into req.query/body. See middlewares/mongoSanitize.js.
app.use(mongoSanitize);

// Apply rate limiters
app.use('/api/engagement/events', eventRateLimiter);
app.use('/api/engagement/analytics', analyticsRateLimiter);

// Routes
app.use('/api/engagement', routes);

// Error handling
app.use(notFoundHandler);
app.use(errorHandler);

// Graceful shutdown handler
const gracefulShutdown = async (signal) => {
  logger.info(`Received ${signal}. Starting graceful shutdown...`);

  // Stop accepting new connections
  server.close(async () => {
    logger.info('HTTP server closed');

    try {
      // Stop pulling new messages from RabbitMQ and wait for in-flight
      // handlers to finish — they need MongoDB/Redis which we close below.
      await RabbitMQ.stopConsumers(15000);

      // Flush remaining in-memory events to persistence.
      await EventService.shutdown();
      logger.info('Event service shut down');

      // Stop aggregation worker
      AggregationWorker.stop();
      logger.info('Aggregation worker stopped');

      // Close RabbitMQ connection
      await RabbitMQ.disconnect();
      logger.info('RabbitMQ disconnected');

      // Close Redis connection
      await Redis.disconnect();
      logger.info('Redis disconnected');

      // Close MongoDB connection
      const mongoose = require('mongoose');
      await mongoose.connection.close();
      logger.info('MongoDB disconnected');

      logger.info('Graceful shutdown completed');
      process.exit(0);
    } catch (error) {
      logger.error('Error during shutdown:', error.message);
      process.exit(1);
    }
  });

  // Force shutdown after 30 seconds
  setTimeout(() => {
    logger.error('Forced shutdown after timeout');
    process.exit(1);
  }, 30000);
};

// Initialize and start server
let server;

const startServer = async () => {
  try {
    // Connect to MongoDB
    await Database.connect();
    logger.info('MongoDB connected');

    // Connect to Redis
    await Redis.connect();
    logger.info('Redis connected');

    // Connect to RabbitMQ
    await RabbitMQ.connect();
    logger.info('RabbitMQ connected');

    // Initialize event service
    await EventService.init();
    logger.info('Event service initialized');

    // Initialize aggregation worker
    AggregationWorker.init();
    logger.info('Aggregation worker initialized');

    // Start HTTP server
    server = app.listen(config.port, () => {
      logger.info(`Engagement service running on port ${config.port}`);
      logger.info(`Environment: ${config.nodeEnv}`);
      logger.info(`Batch size: ${config.batch.size}, interval: ${config.batch.intervalMs}ms`);
    });

    // Handle shutdown signals
    process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
    process.on('SIGINT', () => gracefulShutdown('SIGINT'));

    // Handle uncaught exceptions
    process.on('uncaughtException', (error) => {
      logger.error('Uncaught exception:', error);
      gracefulShutdown('uncaughtException');
    });

    process.on('unhandledRejection', (reason, promise) => {
      logger.error('Unhandled rejection at:', promise, 'reason:', reason);
    });
  } catch (error) {
    logger.error('Failed to start server:', error);
    process.exit(1);
  }
};

startServer();

module.exports = app;
