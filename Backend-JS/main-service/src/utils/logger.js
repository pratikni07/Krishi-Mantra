const winston = require('winston');
const path = require('path');

// Keys whose values must never hit the log pipeline. Matched case-insensitively
// and by substring so `xApiKey`, `refresh_token`, `otpCode` all get caught.
const REDACT_KEY_PATTERNS = [
  /password/i,
  /passwd/i,
  /secret/i,
  /token/i,
  /otp/i,
  /authorization/i,
  /cookie/i,
  /api[_-]?key/i,
  /credential/i,
  /session[_-]?id/i,
];

const redactValue = (value, depth = 0) => {
  if (depth > 8) return value;
  if (value === null || value === undefined) return value;
  if (Array.isArray(value)) return value.map((v) => redactValue(v, depth + 1));
  if (typeof value !== 'object') return value;

  const out = {};
  for (const [k, v] of Object.entries(value)) {
    if (REDACT_KEY_PATTERNS.some((re) => re.test(k))) {
      out[k] = '[REDACTED]';
    } else {
      out[k] = redactValue(v, depth + 1);
    }
  }
  return out;
};

const redactFormat = winston.format((info) => {
  for (const key of Object.keys(info)) {
    if (key === 'level' || key === 'message' || key === 'timestamp' || key === 'stack') continue;
    if (REDACT_KEY_PATTERNS.some((re) => re.test(key))) {
      info[key] = '[REDACTED]';
    } else {
      info[key] = redactValue(info[key]);
    }
  }
  return info;
})();

// Define log format
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

// Console format with colors
const consoleFormat = winston.format.combine(
  winston.format.colorize({ all: true }),
  winston.format.timestamp({ format: 'HH:mm:ss' }),
  winston.format.printf(({ level, message, timestamp }) => {
    return `${timestamp} ${level}: ${message}`;
  })
);

// Create logger instance
const logger = winston.createLogger({
  level: process.env.NODE_ENV === 'production' ? 'info' : 'debug',
  format: logFormat,
  defaultMeta: { service: 'main-service' },
  transports: [
    // Console transport
    new winston.transports.Console({
      format: consoleFormat,
    }),
  ],
});

// Add file transports in production
if (process.env.NODE_ENV === 'production') {
  const logsDir = path.join(process.cwd(), 'logs');

  logger.add(
    new winston.transports.File({
      filename: path.join(logsDir, 'error.log'),
      level: 'error',
      maxsize: 5242880, // 5MB
      maxFiles: 5,
    })
  );

  logger.add(
    new winston.transports.File({
      filename: path.join(logsDir, 'combined.log'),
      maxsize: 5242880, // 5MB
      maxFiles: 5,
    })
  );
}

// Stream for Morgan HTTP logging
logger.stream = {
  write: (message) => {
    logger.info(message.trim());
  },
};

module.exports = logger;
