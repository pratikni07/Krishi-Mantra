const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const compression = require('compression');

// Load environment configuration first
const config = require('./config/environment');

// Import database and redis
const database = require('./config/database');
const redis = require('./config/redis');
const rabbitmq = require('./config/rabbitmq');

// Import routes
const feedRoutes = require('./routes/feed');
const commentRoutes = require('./routes/comment');
const likeRoutes = require('./routes/like');
const analyticsRoutes = require('./routes/analytics');

// Import middlewares
const { errorHandler, notFoundHandler } = require('./middlewares/errorHandler');
const mongoSanitize = require('./middlewares/mongoSanitize');

// Import constants
const { RATE_LIMITS, HTTP_STATUS } = require('./utils/constants');

// Import auto post scheduler
const autoPostScheduler = require('./utils/autoPostScheduler');

const app = express();

// Trust proxy for rate limiting behind reverse proxy
app.set('trust proxy', 1);

// Security Middleware
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      imgSrc: ["'self'", 'data:', 'https:'],
    },
  },
  crossOriginEmbedderPolicy: false,
}));

// Compression for responses
app.use(compression());

// CORS — fail-closed. Without explicit ALLOWED_ORIGINS, only localhost dev
// origins are accepted; no cross-origin browser requests from anywhere else.
const allowedOrigins = process.env.ALLOWED_ORIGINS
  ? process.env.ALLOWED_ORIGINS.split(',').map((o) => o.trim()).filter(Boolean)
  : ['http://localhost:3000', 'http://localhost:8080'];
if (!process.env.ALLOWED_ORIGINS) {
  console.warn(
    '[feed-service] ALLOWED_ORIGINS not set — only localhost dev origins accepted.'
  );
}
const corsOptions = {
  origin: (origin, callback) => {
    if (!origin) return callback(null, true);
    if (allowedOrigins.includes(origin)) return callback(null, true);
    return callback(new Error(`Origin ${origin} not allowed by CORS`));
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With'],
};
app.use(cors(corsOptions));

// Rate Limiting - Optimized for 10k concurrent users
const generalLimiter = rateLimit({
  windowMs: RATE_LIMITS.WINDOW_MS,
  max: RATE_LIMITS.MAX_REQUESTS,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    success: false,
    message: 'Too many requests, please try again later',
  },
  skip: (req) => {
    // Skip rate limiting for health checks
    return req.path === '/health';
  },
});

// Stricter rate limit for write operations
const writeLimiter = rateLimit({
  windowMs: RATE_LIMITS.WINDOW_MS,
  max: RATE_LIMITS.FEED_CREATE_MAX,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    success: false,
    message: 'Too many write operations, please try again later',
  },
});

app.use(generalLimiter);

// Body parsing middleware
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Strip Mongo operator keys ($-prefixed / dotted) from req input. Runs
// after body parsing so req.body/query/params are all populated.
app.use(mongoSanitize);

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(HTTP_STATUS.OK).json({
    success: true,
    message: 'Feed service is healthy',
    timestamp: new Date().toISOString(),
    redis: redis.isDummyClient() ? 'fallback' : 'connected',
    database: database.isConnected() ? 'connected' : 'disconnected',
  });
});

// Routes
app.use('/feeds', feedRoutes);
app.use('/comments', commentRoutes);
app.use('/likes', likeRoutes);
app.use('/analytics', analyticsRoutes);

// 404 handler
app.use(notFoundHandler);

// Global error handler
app.use(errorHandler);

// Database connection and server start
const startServer = async () => {
  try {
    // Connect to MongoDB
    await database.connect();

    // Connect to RabbitMQ for notifications
    try {
      await rabbitmq.connect();
      console.log('✅ RabbitMQ connected for notifications');
    } catch (rabbitError) {
      console.warn('⚠️  RabbitMQ unavailable, notifications will be disabled');
    }

    // Check Redis status after delay
    setTimeout(() => {
      if (redis.isDummyClient()) {
        console.log('⚠️  Using in-memory cache (Redis unavailable)');
      } else {
        console.log('✅ Redis connected');
      }
    }, 3000);

    // Start auto post scheduler if enabled
    if (config.features.enableAutoPost) {
      autoPostScheduler.init();
      console.log('📅 Auto post scheduler initialized');
    }

    // Start server
    const server = app.listen(config.port, () => {
      console.log(`🚀 Feed service running on port ${config.port}`);
      console.log(`📊 Environment: ${config.env}`);
      console.log(`⚡ Rate limit: ${RATE_LIMITS.MAX_REQUESTS} requests/${RATE_LIMITS.WINDOW_MS / 1000}s`);
    });

    // Graceful shutdown
    const gracefulShutdown = async (signal) => {
      console.log(`\n${signal} received. Starting graceful shutdown...`);

      server.close(async () => {
        console.log('HTTP server closed');

        try {
          await database.disconnect();
          await redis.disconnect();
          await rabbitmq.disconnect();
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
    process.on('uncaughtException', (error) => {
      console.error('Uncaught Exception:', error);
      gracefulShutdown('uncaughtException');
    });

    process.on('unhandledRejection', (reason, promise) => {
      console.error('Unhandled Rejection at:', promise, 'reason:', reason);
    });

  } catch (error) {
    console.error('Failed to start server:', error);
    process.exit(1);
  }
};

startServer();

module.exports = app;
