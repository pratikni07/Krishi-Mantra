const winston = require('winston');
const path = require('path');
const config = require('../config');

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

// Custom format for structured logging
const structuredFormat = winston.format.combine(
  winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss.SSS' }),
  winston.format.errors({ stack: true }),
  redactFormat,
  winston.format.printf(({ timestamp, level, message, ...meta }) => {
    const metaStr = Object.keys(meta).length ? JSON.stringify(meta) : '';
    return `${timestamp} [${level.toUpperCase()}] ${message} ${metaStr}`;
  })
);

// JSON format for production (easier to parse by log aggregators)
const jsonFormat = winston.format.combine(
  winston.format.timestamp(),
  winston.format.errors({ stack: true }),
  redactFormat,
  winston.format.json()
);

// Create logger instance
const logger = winston.createLogger({
  level: config.logLevel || 'info',
  format: config.nodeEnv === 'production' ? jsonFormat : structuredFormat,
  defaultMeta: { service: 'engagement-service' },
  transports: [
    // Console transport
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        structuredFormat
      ),
    }),
  ],
});

// Add file transports in production
if (config.nodeEnv === 'production') {
  const logsDir = path.join(__dirname, '../../logs');

  logger.add(
    new winston.transports.File({
      filename: path.join(logsDir, 'error.log'),
      level: 'error',
      maxsize: 50 * 1024 * 1024, // 50MB
      maxFiles: 10,
      tailable: true,
    })
  );

  logger.add(
    new winston.transports.File({
      filename: path.join(logsDir, 'combined.log'),
      maxsize: 100 * 1024 * 1024, // 100MB
      maxFiles: 20,
      tailable: true,
    })
  );
}

// Performance logging helper
logger.performance = (operation, startTime, meta = {}) => {
  const duration = Date.now() - startTime;
  logger.info(`Performance: ${operation}`, { duration, ...meta });
};

// Metric logging helper
logger.metric = (name, value, tags = {}) => {
  logger.info(`Metric: ${name}`, { value, tags });
};

module.exports = logger;
