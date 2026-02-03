const logger = require('../utils/logger');
const ApiError = require('../utils/ApiError');

/**
 * Convert non-ApiError errors to ApiError
 * @param {Error} err - Error object
 * @returns {ApiError} - ApiError instance
 */
const convertError = (err) => {
  if (err instanceof ApiError) {
    return err;
  }

  // Handle Mongoose validation errors
  if (err.name === 'ValidationError') {
    const message = Object.values(err.errors)
      .map((e) => e.message)
      .join(', ');
    return ApiError.badRequest(message);
  }

  // Handle Mongoose CastError (invalid ObjectId)
  if (err.name === 'CastError') {
    return ApiError.badRequest(`Invalid ${err.path}: ${err.value}`);
  }

  // Handle Mongoose duplicate key error
  if (err.code === 11000) {
    const field = Object.keys(err.keyValue)[0];
    return ApiError.conflict(`${field} already exists`);
  }

  // Handle JWT errors
  if (err.name === 'JsonWebTokenError') {
    return ApiError.unauthorized('Invalid token');
  }

  if (err.name === 'TokenExpiredError') {
    return ApiError.unauthorized('Token expired');
  }

  // Default to internal server error
  return ApiError.internal(err.message);
};

/**
 * Global error handler middleware
 */
const errorHandler = (err, req, res, next) => {
  const error = convertError(err);

  // Log error
  if (error.statusCode >= 500) {
    logger.error('Server Error:', {
      message: error.message,
      stack: err.stack,
      path: req.path,
      method: req.method,
    });
  } else {
    logger.warn('Client Error:', {
      message: error.message,
      path: req.path,
      method: req.method,
    });
  }

  // Send response
  res.status(error.statusCode).json({
    success: false,
    message: error.message,
    ...(process.env.NODE_ENV === 'development' && {
      stack: err.stack,
    }),
  });
};

/**
 * 404 Not Found handler
 */
const notFoundHandler = (req, res, next) => {
  res.status(404).json({
    success: false,
    message: `Route ${req.originalUrl} not found`,
  });
};

/**
 * Request logging middleware
 */
const requestLogger = (req, res, next) => {
  const start = Date.now();

  res.on('finish', () => {
    const duration = Date.now() - start;
    const message = `${req.method} ${req.originalUrl} ${res.statusCode} ${duration}ms`;

    if (res.statusCode >= 400) {
      logger.warn(message);
    } else {
      logger.info(message);
    }
  });

  next();
};

module.exports = {
  errorHandler,
  notFoundHandler,
  requestLogger,
};
