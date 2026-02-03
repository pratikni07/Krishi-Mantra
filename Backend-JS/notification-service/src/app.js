const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const compression = require('compression');
const rateLimit = require('express-rate-limit');

const routes = require('./api/routes');
const logger = require('./utils/logger');
const redis = require('./config/redis');
const { Database } = require('./config/mongodb');
const { RATE_LIMITS, HTTP_STATUS } = require('./utils/constants');
const { errorHandler, notFoundHandler, requestLogger } = require('./middlewares/errorHandler');

// Create Express app
const app = express();

// Trust proxy for rate limiting behind reverse proxy
app.set('trust proxy', 1);

// Security middleware
app.use(helmet({
  contentSecurityPolicy: false,
  crossOriginEmbedderPolicy: false,
}));

// Compression for responses
app.use(compression());

// CORS configuration
const corsOptions = {
  origin: (origin, callback) => {
    // Allow requests with no origin (mobile apps, curl, etc.)
    if (!origin) return callback(null, true);

    const allowedOrigins = process.env.ALLOWED_ORIGINS
      ? process.env.ALLOWED_ORIGINS.split(',')
      : ['*'];

    if (allowedOrigins.includes('*') || allowedOrigins.includes(origin)) {
      callback(null, true);
    } else {
      callback(null, true); // Allow all in development
    }
  },
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'x-user-id'],
  credentials: true,
  maxAge: 86400,
};
app.use(cors(corsOptions));

// Request parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Request logging
app.use(requestLogger);

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

// Stricter rate limit for notification creation
const createLimiter = rateLimit({
  windowMs: RATE_LIMITS.CREATE_WINDOW_MS,
  max: RATE_LIMITS.MAX_CREATE,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    success: false,
    message: 'Notification creation limit exceeded, please try again later',
  },
});

// Stricter rate limit for bulk operations
const bulkLimiter = rateLimit({
  windowMs: RATE_LIMITS.BULK_WINDOW_MS,
  max: RATE_LIMITS.MAX_BULK,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    success: false,
    message: 'Bulk operation limit exceeded, please try again later',
  },
});

// Apply general rate limiting to all routes
app.use(generalLimiter);

// Apply stricter limits to specific endpoints
app.use('/notifications', createLimiter);
app.use('/notifications/bulk', bulkLimiter);

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(HTTP_STATUS.OK).json({
    success: true,
    status: 'OK',
    timestamp: new Date().toISOString(),
    service: 'notification-service',
    database: Database.getStatus() ? 'connected' : 'disconnected',
    redis: redis.isFallback() ? 'fallback' : 'connected',
    uptime: process.uptime(),
  });
});

// API routes
app.use('/', routes);

// 404 handler
app.use(notFoundHandler);

// Global error handler
app.use(errorHandler);

module.exports = app;
