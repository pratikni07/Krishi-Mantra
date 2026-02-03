require('dotenv').config();
const http = require('http');
const app = require('./app');
const config = require('./config');
const { connectDB, Database } = require('./config/mongodb');
const rabbitmq = require('./config/rabbitmq');
const redis = require('./config/redis');
const batchProcessor = require('./workers/batch-processor');
const websocketService = require('./services/websocket.service');
const logger = require('./utils/logger');
const { RATE_LIMITS } = require('./utils/constants');

/**
 * Notification service server
 * Optimized for 10k concurrent users
 */
class NotificationServer {
  constructor() {
    this.httpServer = null;
    this.isShuttingDown = false;
  }

  async start() {
    try {
      // Connect to MongoDB
      await connectDB();

      // Connect to RabbitMQ
      await rabbitmq.connect();

      // Create HTTP server
      this.httpServer = http.createServer(app);

      // Configure server timeouts for high concurrency
      this.httpServer.timeout = 120000; // 2 minutes
      this.httpServer.keepAliveTimeout = 65000;
      this.httpServer.headersTimeout = 70000;

      // Initialize WebSocket service
      websocketService.initialize(this.httpServer);

      // Start batch processor consumer
      await batchProcessor.startConsumer();

      // Schedule batch processing
      await batchProcessor.scheduleBatchProcessing();

      // Start HTTP server
      this.httpServer.listen(config.port, () => {
        logger.info(`Notification service running on port ${config.port}`);
        logger.info(`Environment: ${config.env}`);
        logger.info(`Rate limit: ${RATE_LIMITS.MAX_REQUESTS} req/${RATE_LIMITS.WINDOW_MS / 1000}s`);
      });

      // Check Redis status after delay
      setTimeout(() => {
        if (redis.isFallback()) {
          logger.warn('Using in-memory cache (Redis unavailable)');
        } else {
          logger.info('Redis connected');
        }
      }, 3000);

      // Setup graceful shutdown
      this.setupGracefulShutdown();

    } catch (error) {
      logger.error('Failed to start server:', error);
      process.exit(1);
    }
  }

  setupGracefulShutdown() {
    const gracefulShutdown = async (signal) => {
      if (this.isShuttingDown) return;
      this.isShuttingDown = true;

      logger.info(`${signal} received. Starting graceful shutdown...`);

      // Close HTTP server first (stop accepting new connections)
      this.httpServer.close(async () => {
        logger.info('HTTP server closed');

        try {
          // Close WebSocket connections
          if (websocketService.wss) {
            websocketService.wss.close();
            logger.info('WebSocket server closed');
          }

          // Disconnect from RabbitMQ
          await rabbitmq.disconnect();
          logger.info('RabbitMQ disconnected');

          // Disconnect from Redis
          await redis.disconnect();
          logger.info('Redis disconnected');

          // Disconnect from MongoDB
          await Database.disconnect();
          logger.info('MongoDB disconnected');

          logger.info('Graceful shutdown completed');
          process.exit(0);
        } catch (error) {
          logger.error('Error during graceful shutdown:', error);
          process.exit(1);
        }
      });

      // Force shutdown after 30 seconds
      setTimeout(() => {
        logger.error('Forced shutdown after timeout');
        process.exit(1);
      }, 30000);
    };

    // Handle shutdown signals
    process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
    process.on('SIGINT', () => gracefulShutdown('SIGINT'));

    // Handle uncaught exceptions
    process.on('uncaughtException', (err) => {
      logger.error('CRITICAL - Uncaught Exception:', {
        message: err.message,
        stack: err.stack,
        time: new Date().toISOString(),
      });
      gracefulShutdown('uncaughtException');
    });

    // Handle unhandled promise rejections
    process.on('unhandledRejection', (reason, promise) => {
      logger.error('Unhandled Promise Rejection:', {
        reason: reason instanceof Error ? reason.message : reason,
        time: new Date().toISOString(),
      });
    });
  }
}

// Start the server
const server = new NotificationServer();
server.start();

module.exports = server;
