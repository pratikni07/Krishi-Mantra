const winston = require('winston');
const path = require('path');

// Define log levels
const levels = {
  error: 0,
  warn: 1,
  info: 2,
  http: 3,
  debug: 4,
};

// Define colors for each level
const colors = {
  error: 'red',
  warn: 'yellow',
  info: 'green',
  http: 'magenta',
  debug: 'blue',
};

// Add colors to Winston
winston.addColors(colors);

// Create format for console output
const consoleFormat = winston.format.combine(
  winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss:ms' }),
  winston.format.colorize({ all: true }),
  winston.format.printf(
    (info) => `${info.timestamp} ${info.level}: ${info.message}`,
  ),
);

// Create format for file output
const fileFormat = winston.format.combine(
  winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss:ms' }),
  winston.format.json(),
);

// Define log directory
const logDir = path.join(process.cwd(), 'logs');

// Create the logger instance
const logger = winston.createLogger({
  level: process.env.NODE_ENV === 'production' ? 'info' : 'debug',
  levels,
  format: fileFormat,
  transports: [
    // Write logs with level 'error' and below to error.log
    new winston.transports.File({
      filename: path.join(logDir, 'error.log'),
      level: 'error',
    }),
    // Write all logs to combined.log
    new winston.transports.File({
      filename: path.join(logDir, 'combined.log'),
    }),
  ],
});

// If not in production, also log to console
if (process.env.NODE_ENV !== 'production') {
  logger.add(
    new winston.transports.Console({
      format: consoleFormat,
    })
  );
}

// HTTP request logger middleware for Express
const requestLogger = (req, res, next) => {
  const start = Date.now();
  
  // Log when the response finishes
  res.on('finish', () => {
    const duration = Date.now() - start;
    const message = `${req.method} ${req.url} ${res.statusCode} ${duration}ms`;
    
    // Log at different levels based on status code
    if (res.statusCode >= 500) {
      logger.error(message, { 
        ip: req.ip, 
        userId: req.user?.id || 'anonymous',
        statusCode: res.statusCode,
        duration,
        path: req.path,
        query: req.query,
        body: req.method === 'POST' || req.method === 'PUT' ? req.body : undefined
      });
    } else if (res.statusCode >= 400) {
      logger.warn(message, { 
        ip: req.ip, 
        userId: req.user?.id || 'anonymous',
        statusCode: res.statusCode,
        duration
      });
    } else {
      logger.info(message, { 
        ip: req.ip, 
        userId: req.user?.id || 'anonymous',
        statusCode: res.statusCode,
        duration
      });
    }
  });
  
  next();
};

module.exports = {
  logger,
  requestLogger,
}; 