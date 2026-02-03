require('dotenv').config();
const express = require('express');
const http = require('http');
const cors = require('cors');
const morgan = require('morgan');
const helmet = require('helmet');
const compression = require('compression');
const rateLimit = require('express-rate-limit');

const connectDB = require('./config/database');
const { Database } = require('./config/database');
const redis = require('./config/redis');
const reelRoutes = require('./routes/reelRoutes');
const videoTutorialRoutes = require('./routes/videoTutorialRoutes');
const analyticsRoutes = require('./routes/analyticsRoutes');
const { errorHandler, notFoundHandler } = require('./middlewares/errorHandler');
const { RATE_LIMITS, HTTP_STATUS } = require('./utils/constants');

// Import auto-reel scheduler
const autoReelScheduler = require('./utils/autoReelScheduler');

/**
 * Application class optimized for 10k concurrent users
 */
class App {
  constructor() {
    this.app = express();
    this.server = http.createServer(this.app);
    this.PORT = process.env.PORT || 3000;

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

    // Body parsing - large limit for video uploads
    this.app.use(express.json({ limit: '50mb' }));
    this.app.use(express.urlencoded({ extended: true, limit: '50mb' }));

    // Compression
    this.app.use(compression());

    // Request logging (simplified for production)
    if (process.env.NODE_ENV !== 'production') {
      this.app.use(morgan('dev'));
    } else {
      this.app.use(morgan('combined'));
    }

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

    // Stricter rate limit for uploads only (POST to create new reels/videos)
    const uploadLimiter = rateLimit({
      windowMs: RATE_LIMITS.UPLOAD_WINDOW_MS,
      max: RATE_LIMITS.MAX_UPLOADS,
      message: {
        success: false,
        message: 'Upload limit exceeded, please try again later',
      },
      // Only apply to actual upload/create operations, skip common interactions
      skip: (req) => {
        // Skip rate limiting for GET requests (read operations)
        if (req.method === 'GET') return true;
        // Skip for interaction endpoints (likes, comments, interactions)
        if (req.path.includes('/like') ||
            req.path.includes('/comments') ||
            req.path.includes('/interaction') ||
            req.path.includes('/interests')) return true;
        return false;
      },
    });
    this.app.use('/reels', uploadLimiter);
    this.app.use('/videos', uploadLimiter);
  }

  setupRoutes() {
    // Health check endpoint
    this.app.get('/health', (req, res) => {
      res.status(HTTP_STATUS.OK).json({
        success: true,
        status: 'OK',
        timestamp: new Date().toISOString(),
        database: Database.getStatus() ? 'connected' : 'disconnected',
        redis: redis.isFallback() ? 'fallback' : 'connected',
        uptime: process.uptime(),
      });
    });

    // API routes
    this.app.use('/reels', reelRoutes);
    this.app.use('/videos', videoTutorialRoutes);
    this.app.use('/analytics', analyticsRoutes);

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
      await connectDB();

      // Start auto-reel scheduler after successful database connection
      if (process.env.ENABLE_AUTO_REELS !== 'false') {
        // autoReelScheduler.init();
      }

      // Start HTTP server
      this.server.listen(this.PORT, () => {
        console.log(`Reel service running on port ${this.PORT}`);
        console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
        console.log(`Rate limit: ${RATE_LIMITS.MAX_REQUESTS} req/${RATE_LIMITS.WINDOW_MS / 1000}s`);
      });

      // Server timeouts
      this.server.timeout = 120000; // 2 minutes
      this.server.keepAliveTimeout = 65000;
      this.server.headersTimeout = 70000;

      // Check Redis status
      setTimeout(() => {
        if (redis.isFallback()) {
          console.log('Using in-memory cache (Redis unavailable)');
        } else {
          console.log('Redis connected');
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
          // Close database and Redis
          await Database.disconnect();
          await redis.disconnect();

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
