const winston = require('winston');

// Scrub secret-looking keys before log meta hits any transport.
const REDACT_KEY_PATTERNS = [
  /password/i, /passwd/i, /secret/i, /token/i, /otp/i,
  /authorization/i, /cookie/i, /api[_-]?key/i, /credential/i, /session[_-]?id/i,
];
const redactValue = (value, depth = 0) => {
  if (depth > 8) return value;
  if (value === null || value === undefined) return value;
  if (Array.isArray(value)) return value.map((v) => redactValue(v, depth + 1));
  if (typeof value !== 'object') return value;
  const out = {};
  for (const [k, v] of Object.entries(value)) {
    if (REDACT_KEY_PATTERNS.some((re) => re.test(k))) out[k] = '[REDACTED]';
    else out[k] = redactValue(v, depth + 1);
  }
  return out;
};
const redactFormat = winston.format((info) => {
  for (const key of Object.keys(info)) {
    if (key === 'level' || key === 'message' || key === 'timestamp' || key === 'stack') continue;
    if (REDACT_KEY_PATTERNS.some((re) => re.test(key))) info[key] = '[REDACTED]';
    else info[key] = redactValue(info[key]);
  }
  return info;
})();

const logFormat = winston.format.combine(
  winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
  winston.format.errors({ stack: true }),
  redactFormat,
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
