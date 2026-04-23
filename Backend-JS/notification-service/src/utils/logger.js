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

// Define log format
const logFormat = winston.format.combine(
  winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
  winston.format.errors({ stack: true }),
  winston.format.splat(),
  redactFormat,
  winston.format.json()
);

// Create logger instance
const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: logFormat,
  defaultMeta: { service: 'notification-service' },
  transports: [
    // Console transport
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.printf(
          ({ level, message, timestamp, ...meta }) => {
            return `${timestamp} ${level}: ${message} ${
              Object.keys(meta).length ? JSON.stringify(meta, null, 2) : ''
            }`;
          }
        )
      )
    }),
    // File transport for error logs
    new winston.transports.File({ 
      filename: 'logs/error.log', 
      level: 'error',
      maxsize: 5242880, // 5MB
      maxFiles: 5
    }),
    // File transport for all logs
    new winston.transports.File({ 
      filename: 'logs/combined.log',
      maxsize: 5242880, // 5MB
      maxFiles: 5 
    })
  ]
});

// Export logger
module.exports = logger; 