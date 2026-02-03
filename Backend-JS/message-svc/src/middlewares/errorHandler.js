const ApiError = require('../utils/ApiError');
const logger = require('../utils/logger');
const { HTTP_STATUS } = require('../utils/constants');

/**
 * Global error handler middleware for message-svc
 */
const errorHandler = (err, req, res, next) => {
  // Log error
  logger.error('Request error', {
    url: req.url,
    method: req.method,
    error: err.message,
    stack: process.env.NODE_ENV !== 'production' ? err.stack : undefined,
  });

  // Handle ApiError instances
  if (err instanceof ApiError) {
    return res.status(err.statusCode).json({
      success: false,
      message: err.message,
      errors: err.errors,
    });
  }

  // Handle JSON parse errors
  if (err.type === 'entity.parse.failed') {
    return res.status(HTTP_STATUS.BAD_REQUEST).json({
      success: false,
      message: 'Invalid JSON',
    });
  }

  // Handle connection reset errors (common in real-time services)
  if (
    err.code === 'ECONNRESET' ||
    err.message?.includes('ECONNRESET') ||
    err.message?.includes('socket hang up') ||
    err.message?.includes('connection reset')
  ) {
    return res.status(HTTP_STATUS.BAD_GATEWAY).json({
      success: false,
      message: 'Service connection was reset. Please try again.',
      status: 'error',
    });
  }

  // Handle timeout errors
  if (err.message?.includes('timeout') || err.message?.includes('ETIMEDOUT')) {
    return res.status(HTTP_STATUS.GATEWAY_TIMEOUT).json({
      success: false,
      message: 'Request timed out. Please try again.',
      status: 'error',
    });
  }

  // Handle Mongoose validation errors
  if (err.name === 'ValidationError') {
    const errors = Object.values(err.errors).map((e) => ({
      field: e.path,
      message: e.message,
    }));
    return res.status(HTTP_STATUS.BAD_REQUEST).json({
      success: false,
      message: 'Validation error',
      errors,
    });
  }

  // Handle Mongoose cast errors
  if (err.name === 'CastError') {
    return res.status(HTTP_STATUS.BAD_REQUEST).json({
      success: false,
      message: `Invalid ${err.path}: ${err.value}`,
    });
  }

  // Handle duplicate key errors
  if (err.code === 11000) {
    const field = Object.keys(err.keyValue)[0];
    return res.status(HTTP_STATUS.CONFLICT).json({
      success: false,
      message: `${field} already exists`,
    });
  }

  // Default error response
  return res.status(err.status || HTTP_STATUS.INTERNAL_SERVER_ERROR).json({
    success: false,
    message: process.env.NODE_ENV === 'production'
      ? 'Internal server error'
      : err.message,
  });
};

/**
 * 404 handler for undefined routes
 */
const notFoundHandler = (req, res) => {
  return res.status(HTTP_STATUS.NOT_FOUND).json({
    success: false,
    message: `Route ${req.originalUrl} not found`,
  });
};

module.exports = { errorHandler, notFoundHandler };
