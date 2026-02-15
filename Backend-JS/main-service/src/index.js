const express = require('express');
const cors = require('cors');
const cookieParser = require('cookie-parser');
const fileUpload = require('express-fileupload');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const path = require('path');
const statusMonitor = require('express-status-monitor');

// Load environment configuration
const setupEnvironment = require('./config/environment');
setupEnvironment();

// Import utilities
const logger = require('./utils/logger');
const { RATE_LIMIT, HTTP_STATUS } = require('./utils/constants');

// Import database and redis
const { connect: connectDB, disconnect: disconnectDB } = require('./config/database');
const redis = require('./config/redis');

// Import middlewares
const { errorHandler, notFoundHandler, requestLogger } = require('./middlewares/errorHandler');

// Import routes
const userRoutes = require('./routes/User');
const companyRoutes = require('./routes/companyRoutes');
const productRoutes = require('./routes/productRoutes');
const newsRoutes = require('./routes/newsRoutes');
const adsRoutes = require('./routes/AdsRoutes');
const serviceRoutes = require('./routes/ServiceRoutes');
const userRoutesOne = require('./routes/UserRoutes');
const cropRoutes = require('./routes/cropCalendar');
const schemeRoutes = require('./routes/schemeRoutes');
const analyticsRoutes = require('./routes/AnalyticsRoutes');
const marketplaceRoutes = require('./routes/marketplaceRoutes');
const subscriptionRoutes = require('./routes/subscriptionRoutes');
const iotDeviceRoutes = require('./routes/iotDeviceRoutes');
const deviceRegistrationRoutes = require('./routes/deviceRegistrationRoutes');

// Initialize express app
const app = express();
const PORT = process.env.PORT || 3002;

// Trust proxy for rate limiting behind reverse proxy (API Gateway)
app.set('trust proxy', 1);

/**
 * Security middleware
 */
app.use(helmet({
  crossOriginResourcePolicy: { policy: 'cross-origin' },
}));

/**
 * Request parsing middleware
 */
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));
app.use(cookieParser());

/**
 * Rate limiting
 */
const limiter = rateLimit({
  windowMs: RATE_LIMIT.WINDOW_MS,
  max: RATE_LIMIT.MAX_REQUESTS,
  standardHeaders: true,
  legacyHeaders: false,
  skipFailedRequests: true,
  handler: (req, res) => {
    res.status(HTTP_STATUS.TOO_MANY_REQUESTS).json({
      success: false,
      message: 'Too many requests, please try again later.',
    });
  },
});

// Apply rate limiting to all routes
app.use(limiter);

/**
 * CORS configuration
 */
const corsOptions = {
  origin: (origin, callback) => {
    // Allow requests with no origin (mobile apps, curl, etc.)
    if (!origin) {
      return callback(null, true);
    }

    // In development, allow all origins
    if (process.env.NODE_ENV === 'development') {
      return callback(null, true);
    }

    // In production, check against allowed origins
    const allowedOrigins = process.env.CORS_ORIGIN
      ? process.env.CORS_ORIGIN.split(',').map((o) => o.trim())
      : [];

    if (allowedOrigins.includes(origin)) {
      callback(null, true);
    } else {
      logger.warn(`CORS blocked request from: ${origin}`);
      callback(new Error('Not allowed by CORS'));
    }
  },
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  credentials: true,
  maxAge: 86400,
};

app.use(cors(corsOptions));

/**
 * File upload configuration
 */
app.use(fileUpload({
  useTempFiles: true,
  tempFileDir: path.join(__dirname, 'temp'),
  limits: { fileSize: 10 * 1024 * 1024 }, // 10MB limit
  abortOnLimit: true,
}));

/**
 * Status monitor (development only)
 */
if (process.env.NODE_ENV !== 'production') {
  app.use(statusMonitor({
    path: '/status',
    spans: [
      { interval: 1, retention: 60 },
      { interval: 5, retention: 60 },
      { interval: 15, retention: 60 },
    ],
    chartVisibility: {
      cpu: true,
      mem: true,
      load: true,
      eventLoop: true,
      heap: true,
      responseTime: true,
      rps: true,
      statusCodes: true,
    },
  }));
}

/**
 * Request logging
 */
app.use(requestLogger);

/**
 * Health check endpoints
 */
app.get('/', (req, res) => {
  res.status(HTTP_STATUS.OK).json({
    success: true,
    message: 'Welcome to Krishi Mantra API',
    version: '1.0.0',
  });
});

app.get('/health', (req, res) => {
  res.status(HTTP_STATUS.OK).json({
    success: true,
    status: 'OK',
    timestamp: new Date().toISOString(),
    service: 'main-service',
    port: PORT,
    environment: process.env.NODE_ENV || 'development',
    redis: redis.isRedisAvailable() ? 'connected' : 'disconnected',
  });
});

/**
 * API Routes
 */
app.use('/auth', userRoutes);
app.use('/companies', companyRoutes);
app.use('/products', productRoutes);
app.use('/ads', adsRoutes);
app.use('/news', newsRoutes);
app.use('/service', serviceRoutes);
app.use('/user', userRoutesOne);
app.use('/crop-calendar', cropRoutes);
app.use('/schemes', schemeRoutes);
app.use('/analytics', analyticsRoutes);
app.use('/marketplace', marketplaceRoutes);
app.use('/subscription', subscriptionRoutes);
app.use('/api/v1/iot', iotDeviceRoutes);
app.use('/api/device-registration', deviceRegistrationRoutes);

/**
 * 404 Handler
 */
app.use(notFoundHandler);

/**
 * Global Error Handler
 */
app.use(errorHandler);

/**
 * Graceful shutdown handler
 */
const gracefulShutdown = async (signal) => {
  logger.info(`${signal} received. Starting graceful shutdown...`);

  try {
    // Close database connection
    await disconnectDB();

    // Close Redis connection
    await redis.disconnect();

    logger.info('Graceful shutdown completed');
    process.exit(0);
  } catch (error) {
    logger.error('Error during graceful shutdown:', error);
    process.exit(1);
  }
};

process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));

// Handle uncaught exceptions
process.on('uncaughtException', (error) => {
  logger.error('Uncaught Exception:', error);
  process.exit(1);
});

// Handle unhandled promise rejections
process.on('unhandledRejection', (reason, promise) => {
  logger.error('Unhandled Rejection at:', promise, 'reason:', reason);
  process.exit(1);
});

/**
 * Start server
 */
const startServer = async () => {
  try {
    // Connect to database
    await connectDB();

    // Start listening
    app.listen(PORT, () => {
      logger.info(`Server running on port ${PORT} in ${process.env.NODE_ENV || 'development'} mode`);
    });
  } catch (error) {
    logger.error('Failed to start server:', error);
    process.exit(1);
  }
};

startServer();

module.exports = app;
