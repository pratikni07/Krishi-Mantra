require('dotenv').config();
const express = require('express');
const http = require('http');
const helmet = require('helmet');
const compression = require('compression');
const cors = require('cors');
const rateLimit = require('express-rate-limit');

const SocketService = require('./services/socket.service');
const Database = require('./config/database');
const Redis = require('./config/redis');
const Rabbitmq = require('./config/rabbitmq');
const { errorHandler, notFoundHandler } = require('./middlewares/errorHandler');
const { RATE_LIMITS, SOCKET_CONFIG, HTTP_STATUS } = require('./utils/constants');

class App {
  constructor() {
    this.app = express();
    this.server = http.createServer(this.app);
    this.PORT = process.env.PORT || 3000;
    this.socketService = null;

    this.setupMiddlewares();
    this.setupRoutes();
    this.setupErrorHandlers();
  }

  setupMiddlewares() {
    // Trust proxy for rate limiting behind reverse proxy
    this.app.set('trust proxy', 1);

    // Security headers
    this.app.use(
      helmet({
        contentSecurityPolicy: false,
        crossOriginEmbedderPolicy: false,
      })
    );

    // CORS configuration
    const corsOptions = {
      origin: (origin, callback) => {
        if (!origin) return callback(null, true);
        const allowedOrigins = process.env.ALLOWED_ORIGINS?.split(',') || ['*'];
        if (allowedOrigins.includes('*') || allowedOrigins.includes(origin)) {
          callback(null, true);
        } else {
          callback(null, true); // Allow all in development
        }
      },
      methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
      allowedHeaders: ['Content-Type', 'Authorization', 'x-user-id'],
      credentials: true,
      maxAge: 86400,
    };
    this.app.use(cors(corsOptions));

    // Body parsing
    this.app.use(express.json({ limit: '20mb' }));
    this.app.use(express.urlencoded({ extended: true, limit: '20mb' }));

    // Compression
    this.app.use(compression());

    // Rate limiting - optimized for 10k users
    const generalLimiter = rateLimit({
      windowMs: RATE_LIMITS.WINDOW_MS,
      max: RATE_LIMITS.MAX_REQUESTS,
      standardHeaders: true,
      legacyHeaders: false,
      skip: (req) => req.path === '/health',
      message: {
        success: false,
        message: 'Too many requests, please try again later',
      },
    });
    this.app.use(generalLimiter);

    // Request logging (simplified for production)
    if (process.env.NODE_ENV !== 'production') {
      this.app.use((req, res, next) => {
        console.log(`${new Date().toISOString()} - ${req.method} ${req.url}`);
        next();
      });
    }
  }

  setupRoutes() {
    // Health check endpoint
    this.app.get('/health', (req, res) => {
      res.status(HTTP_STATUS.OK).json({
        success: true,
        status: 'OK',
        timestamp: new Date().toISOString(),
        database: Database.getStatus() ? 'connected' : 'disconnected',
        redis: Redis.isFallback() ? 'fallback' : 'connected',
        sockets: this.socketService?.getStats() || { connections: 0 },
      });
    });

    // API routes
    this.app.use('/api/chat', require('./routes/chat.routes'));
    this.app.use('/api/group', require('./routes/group.routes'));
    this.app.use('/api/message', require('./routes/message.routes'));
    this.app.use('/api/ai', require('./routes/ai.routes'));

    // 404 handler
    this.app.use(notFoundHandler);
  }

  setupErrorHandlers() {
    // Global error handler
    this.app.use(errorHandler);
  }

  async start() {
    try {
      // Connect to MongoDB
      await Database.connect();

      // Connect to RabbitMQ for notifications
      try {
        await Rabbitmq.connect();
        console.log('✅ RabbitMQ connected for notifications');
      } catch (rabbitError) {
        console.warn('⚠️  RabbitMQ unavailable, notifications will be disabled');
      }

      // Initialize Socket.IO service
      this.socketService = new SocketService(this.server);

      // Start HTTP server
      this.server.listen(this.PORT, () => {
        console.log(`🚀 Message service running on port ${this.PORT}`);
        console.log(`📊 Environment: ${process.env.NODE_ENV || 'development'}`);
        console.log(`⚡ Rate limit: ${RATE_LIMITS.MAX_REQUESTS} req/${RATE_LIMITS.WINDOW_MS / 1000}s`);
      });

      // Server timeouts optimized for WebSocket
      this.server.timeout = 120000; // 2 minutes
      this.server.keepAliveTimeout = SOCKET_CONFIG.PING_TIMEOUT;
      this.server.headersTimeout = 65000;

      // Check Redis status
      setTimeout(() => {
        if (Redis.isFallback()) {
          console.log('⚠️  Using in-memory cache (Redis unavailable)');
        } else {
          console.log('✅ Redis connected');
        }
      }, 3000);

      // Graceful shutdown
      this.setupGracefulShutdown();

    } catch (error) {
      console.error('Failed to start server:', error);
      process.exit(1);
    }
  }

  setupGracefulShutdown() {
    const gracefulShutdown = async (signal) => {
      console.log(`\n${signal} received. Starting graceful shutdown...`);

      // Close HTTP server first
      this.server.close(async () => {
        console.log('HTTP server closed');

        try {
          // Close Socket.IO connections
          if (this.socketService?.io) {
            this.socketService.io.close();
            console.log('Socket.IO server closed');
          }

          // Close database, Redis, and RabbitMQ
          await Database.disconnect();
          await Redis.disconnect();
          await Rabbitmq.disconnect();

          console.log('All connections closed');
          process.exit(0);
        } catch (error) {
          console.error('Error during shutdown:', error);
          process.exit(1);
        }
      });

      // Force shutdown after 30 seconds
      setTimeout(() => {
        console.error('Forced shutdown after timeout');
        process.exit(1);
      }, 30000);
    };

    process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
    process.on('SIGINT', () => gracefulShutdown('SIGINT'));

    // Handle uncaught exceptions
    process.on('uncaughtException', (err) => {
      console.error('CRITICAL - Uncaught Exception:', {
        message: err.message,
        stack: err.stack,
        time: new Date().toISOString(),
      });
      gracefulShutdown('uncaughtException');
    });

    // Handle unhandled promise rejections
    process.on('unhandledRejection', (reason, promise) => {
      console.error('Unhandled Promise Rejection:', {
        reason: reason instanceof Error ? reason.message : reason,
        time: new Date().toISOString(),
      });
    });
  }
}

// Start the application
const app = new App();
app.start();

module.exports = app;
