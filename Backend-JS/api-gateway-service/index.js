const express = require("express");
const { createProxyMiddleware } = require("http-proxy-middleware");
const cors = require("cors");
const rateLimit = require("express-rate-limit");
const helmet = require("helmet");
const jwt = require("jsonwebtoken");
const Redis = require("ioredis");
const winston = require("winston");
const compression = require("compression");
require("dotenv").config();
const uploadRoutes = require("./routes/uploadRoutes");

// Initialize Redis client
let redisClient;
try {
  redisClient = new Redis({
    host: process.env.REDIS_HOST || 'localhost',
    port: process.env.REDIS_PORT || 6379,
    password: process.env.REDIS_PASSWORD || '',
    retryStrategy: (times) => Math.min(times * 50, 2000),
  });
  
  redisClient.on("error", (err) => {
    console.error("Redis error:", err);
  });
  
  redisClient.on("connect", () => {
    console.log("Connected to Redis");
  });
} catch (error) {
  console.error("Redis initialization error:", error);
}

// Setup logger
const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  defaultMeta: { service: 'api-gateway' },
  transports: [
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.simple()
      )
    }),
    new winston.transports.File({ 
      filename: 'logs/error.log', 
      level: 'error' 
    }),
    new winston.transports.File({ 
      filename: 'logs/combined.log' 
    })
  ],
});

const app = express();
const PORT = process.env.PORT || 3001;

// Rate limiting configuration
const limiter = rateLimit({
  windowMs: process.env.RATE_LIMIT_WINDOW_MS || 900000,
  max: process.env.RATE_LIMIT_MAX_REQUESTS || 100,
  standardHeaders: true,
  legacyHeaders: false,
  skipSuccessfulRequests: false,
});

// Middleware
app.use(helmet());
app.use(limiter);
app.use(compression()); // Compress responses
app.use(express.json({ limit: "10mb" }));
app.use(express.urlencoded({ extended: true, limit: "10mb" }));

// CORS configuration with fallback
const allowedOrigins = process.env.ALLOWED_ORIGINS
  ? process.env.ALLOWED_ORIGINS.split(",")
  : ["http://localhost:3000"];

console.log("Configured CORS allowed origins:", allowedOrigins);

app.use(
  cors({
    origin: function (origin, callback) {
      if (!origin || allowedOrigins.indexOf(origin) !== -1 || process.env.NODE_ENV === "development") {
        callback(null, true);
      } else {
        logger.warn(`Blocked by CORS: ${origin}`);
        callback(null, false);
      }
    },
    credentials: true,
    methods: ["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization"],
  })
);

// JWT Authentication middleware
const authenticateJWT = async (req, res, next) => {
  // Skip auth for health check endpoints
  if (req.path === '/health' || req.path === '/api/health') {
    return next();
  }
  
  try {
    const authHeader = req.headers.authorization;
    
    if (authHeader) {
      const token = authHeader.split(' ')[1];
      
      // Check Redis cache first for blacklisted tokens
      if (redisClient) {
        const isBlacklisted = await redisClient.get(`bl_${token}`);
        if (isBlacklisted) {
          return res.status(401).json({ error: 'Token has been revoked' });
        }
      }

      jwt.verify(token, process.env.JWT_SECRET, (err, user) => {
        if (err) {
          return res.status(403).json({ error: 'Invalid or expired token' });
        }

        // Add user info to request for downstream services
        req.user = user;
        
        // Add user ID to headers for microservices
        req.headers['x-user-id'] = user.id;
        req.headers['x-user-role'] = user.accountType;
        
        // Cache user info in Redis for faster access
        if (redisClient) {
          redisClient.setex(`user:${user.id}`, 3600, JSON.stringify({
            id: user.id,
            accountType: user.accountType
          }));
        }
        
        next();
      });
    } else {
      // Allow public routes to pass through
      // Services should implement their own auth checks
      if (req.path.startsWith('/api/main/auth/') ||
          req.path === '/api/main/health') {
        next();
      } else {
        return res.status(401).json({ error: 'Authorization required' });
      }
    }
  } catch (error) {
    logger.error('Auth error:', error);
    return res.status(500).json({ error: 'Authentication error' });
  }
};

app.use(authenticateJWT);

// Request logging middleware
app.use((req, res, next) => {
  logger.info(`${req.method} ${req.url}`, {
    ip: req.ip,
    userAgent: req.headers['user-agent'],
    userId: req.user?.id || 'anonymous'
  });
  next();
});

// Enhanced proxy creation with circuit breaker pattern
const createServiceProxy = (serviceName, serviceUrl, pathRewrite) => {
  logger.info(`Creating service proxy for: ${serviceName}, ${serviceUrl}`);
  
  if (!serviceUrl) {
    throw new Error(`${serviceName} URL is not configured. Please check your .env file.`);
  }

  // Track service health
  let serviceHealthy = true;
  let failureCount = 0;
  const failureThreshold = 5;
  const resetTimeout = 30000; // 30 seconds

  return createProxyMiddleware({
    target: serviceUrl.trim(),
    changeOrigin: true,
    pathRewrite: pathRewrite,
    on: {
      proxyReq: (proxyReq, req, res) => {
        // If circuit is open, don't forward the request
        if (!serviceHealthy) {
          res.status(503).json({
            status: "error",
            message: `${serviceName} is currently unavailable. Please try again later.`
          });
          return;
        }

        // Forward user context to services
        if (req.user) {
          proxyReq.setHeader('x-user-id', req.user.id);
          proxyReq.setHeader('x-user-role', req.user.accountType);
        }
        
        if (["POST", "PUT", "PATCH"].includes(req.method) && req.body) {
          const bodyData = JSON.stringify(req.body);
          proxyReq.setHeader("Content-Type", "application/json");
          proxyReq.setHeader("Content-Length", Buffer.byteLength(bodyData));
          proxyReq.write(bodyData);
        }
        
        // Forward important headers
        proxyReq.setHeader("x-forwarded-for", req.ip);
        proxyReq.setHeader("x-forwarded-host", req.headers.host);
        proxyReq.setHeader("x-forwarded-proto", req.protocol);
        
        // Add request tracing ID
        const traceId = req.headers['x-trace-id'] || `trace-${Date.now()}-${Math.random().toString(36).substring(2, 10)}`;
        proxyReq.setHeader('x-trace-id', traceId);
      },
      
      proxyRes: (proxyRes, req, res) => {
        // Reset failure count on success
        if (proxyRes.statusCode < 500) {
          failureCount = 0;
        }
        logger.info(`[${serviceName}] Response: ${proxyRes.statusCode}`);
      },
      
      error: (err, req, res) => {
        failureCount++;
        logger.error(`Proxy Error (${serviceName}): ${err.message}`);
        
        // Implement circuit breaker
        if (failureCount >= failureThreshold && serviceHealthy) {
          serviceHealthy = false;
          logger.warn(`Circuit opened for ${serviceName} after ${failureCount} failures`);
          
          // Reset circuit after timeout
          setTimeout(() => {
            serviceHealthy = true;
            failureCount = 0;
            logger.info(`Circuit reset for ${serviceName}`);
          }, resetTimeout);
        }
        
        res.status(502).json({
          status: "error",
          message: `${serviceName} unavailable`,
          error: process.env.NODE_ENV === "development" ? err.message : undefined
        });
      }
    }
  });
};

try {
  logger.info("Initializing service proxies...");
  
  const mainServiceProxy = createServiceProxy(
    "Main Service",
    process.env.MAIN_SERVICE_URL,
    { "^/api/main": "" }
  );

  const messageServiceProxy = createServiceProxy(
    "Message Service",
    process.env.MESSAGE_SERVICE_URL,
    { "^/api/messages": "" }
  );

  const feedServiceProxy = createServiceProxy(
    "Feed Service",
    process.env.FEED_SERVICE_URL,
    { "^/api/feed": "" }
  );

  const reelServiceProxy = createServiceProxy(
    "Reel Service",
    process.env.REEL_SERVICE_URL,
    { "^/api/reels": "" }
  );
  
  const notificationServiceProxy = createServiceProxy(
    "Notification Service",
    process.env.NOTIFICATION_SERVICE_URL,
    { "^/api/notification": "" }
  );

  // Routes
  app.use("/api/main", mainServiceProxy);
  app.use("/api/messages", messageServiceProxy);
  app.use("/api/feed", feedServiceProxy);
  app.use("/api/reels", reelServiceProxy);
  app.use("/api/notification", notificationServiceProxy);
  app.use("/api/upload", uploadRoutes);
  
  // User logout - blacklist token
  app.post('/api/logout', async (req, res) => {
    try {
      const authHeader = req.headers.authorization;
      if (authHeader) {
        const token = authHeader.split(' ')[1];
        
        // Store token in Redis blacklist with an expiry matching the token's TTL
        if (redisClient) {
          const decoded = jwt.decode(token);
          if (decoded && decoded.exp) {
            const ttl = decoded.exp - Math.floor(Date.now() / 1000);
            await redisClient.setex(`bl_${token}`, ttl > 0 ? ttl : 3600, '1');
          }
        }
      }
      
      res.status(200).json({ success: true, message: 'Logged out successfully' });
    } catch (error) {
      logger.error('Logout error:', error);
      res.status(500).json({ error: 'Logout failed' });
    }
  });
  
} catch (error) {
  logger.error("Error setting up proxies:", error);
  process.exit(1);
}

// Health check endpoint
app.get("/health", (req, res) => {
  const healthData = {
    status: "healthy",
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    memory: process.memoryUsage(),
  };
  
  // Add Redis status if available
  if (redisClient) {
    healthData.redis = redisClient.status || "unknown";
  }
  
  res.status(200).json(healthData);
});

// Global error handler
app.use((err, req, res, next) => {
  logger.error("Global error:", {
    error: err.message,
    stack: err.stack,
    path: req.path,
    method: req.method,
    userId: req.user?.id || 'anonymous'
  });
  
  res.status(500).json({
    status: "error",
    message: "Internal server error",
    error: process.env.NODE_ENV === "development" ? err.message : undefined
  });
});

const server = app.listen(PORT, () => {
  logger.info(`API Gateway running on port ${PORT}`);
  logger.info(`Environment: ${process.env.NODE_ENV}`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  logger.info('SIGTERM received, shutting down...');
  server.close(() => {
    logger.info('Server closed');
    if (redisClient) {
      redisClient.quit();
    }
    process.exit(0);
  });
});

module.exports = app;

