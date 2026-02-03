const winston = require('winston');

const logFormat = winston.format.combine(
  winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
  winston.format.errors({ stack: true }),
  winston.format.printf(({ level, message, timestamp, stack, ...meta }) => {
    let log = `${timestamp} [${level.toUpperCase()}]: ${message}`;

    if (Object.keys(meta).length > 0) {
      log += ` ${JSON.stringify(meta)}`;
    }

    if (stack) {
      log += `\n${stack}`;
    }

    return log;
  })
);

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: logFormat,
  transports: [
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        logFormat
      ),
    }),
  ],
  // Don't exit on uncaught errors
  exitOnError: false,
});

// Add file transport in production
if (process.env.NODE_ENV === 'production') {
  logger.add(new winston.transports.File({
    filename: 'logs/error.log',
    level: 'error',
    maxsize: 5242880, // 5MB
    maxFiles: 5,
  }));

  logger.add(new winston.transports.File({
    filename: 'logs/combined.log',
    maxsize: 5242880, // 5MB
    maxFiles: 5,
  }));
}

// Socket-specific logging helpers
logger.socket = {
  connect: (userId, socketId) => {
    logger.info('Socket connected', { userId, socketId });
  },
  disconnect: (userId, socketId, reason) => {
    logger.info('Socket disconnected', { userId, socketId, reason });
  },
  event: (event, userId, data) => {
    logger.debug('Socket event', { event, userId, dataSize: JSON.stringify(data).length });
  },
  error: (userId, error) => {
    logger.error('Socket error', { userId, error: error.message });
  },
};

// AI-specific logging helpers
logger.ai = {
  request: (chatId, type) => {
    logger.info('AI request', { chatId, type });
  },
  response: (chatId, duration) => {
    logger.info('AI response', { chatId, duration: `${duration}ms` });
  },
  error: (chatId, error) => {
    logger.error('AI error', { chatId, error: error.message });
  },
  circuitBreaker: (state) => {
    logger.warn('AI circuit breaker', { state });
  },
};

module.exports = logger;
