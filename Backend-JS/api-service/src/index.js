import express from "express";
import cors from "cors";
import helmet from "helmet";
import rateLimit from "express-rate-limit";
import { createProxyMiddleware } from "http-proxy-middleware";
import expressStatusMonitor from "express-status-monitor";
import dotenv from "dotenv";
import winston from "winston";
import path from "path";
import fs from "fs";

dotenv.config();

// Ensure logs directory exists
const logsDir = path.join(process.cwd(), "logs");
if (!fs.existsSync(logsDir)) {
  fs.mkdirSync(logsDir);
}

// Enhanced Logger Configuration
const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || "info",
  format: winston.format.combine(
    winston.format.timestamp({
      format: "YYYY-MM-DD HH:mm:ss",
    }),
    winston.format.errors({ stack: true }),
    winston.format.splat(),
    winston.format.json()
  ),
  defaultMeta: { service: "api-gateway" },
  transports: [
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.printf(
          ({ level, message, timestamp, stack }) =>
            `${timestamp} ${level}: ${message} ${stack ? "\n" + stack : ""}`
        )
      ),
    }),
    new winston.transports.File({
      filename: path.join(logsDir, "error.log"),
      level: "error",
    }),
    new winston.transports.File({
      filename: path.join(logsDir, "combined.log"),
    }),
  ],
});

// Create Express App
const app = express();

// Enhanced Middleware Setup
const setupMiddleware = () => {
  // Basic Middleware
  app.use(express.json({ limit: "10mb" }));
  app.use(express.urlencoded({ extended: true, limit: "10mb" }));

  // Status Monitoring with Authentication
  app.use(
    expressStatusMonitor({
      title: "Microservices Status",
      path: "/status",
      spans: [
        {
          interval: 1,
          retention: 60,
        },
        {
          interval: 5,
          retention: 60,
        },
      ],
      chartVisibility: {
        cpu: true,
        mem: true,
        load: true,
        responseTime: true,
        rps: true,
        statusCodes: true,
      },
      authentication: process.env.STATUS_AUTH !== "false",
      username: process.env.STATUS_USERNAME || "admin",
      password: process.env.STATUS_PASSWORD || "admin",
    })
  );

  // Enhanced CORS Configuration
  const corsOptions = {
    origin: (origin, callback) => {
      const allowedOrigins = (process.env.CORS_ORIGIN || "*").split(",");
      if (
        !origin ||
        allowedOrigins.includes("*") ||
        allowedOrigins.includes(origin)
      ) {
        callback(null, true);
      } else {
        callback(new Error("Not allowed by CORS"));
      }
    },
    methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH"],
    allowedHeaders: ["Content-Type", "Authorization"],
    credentials: true,
    maxAge: 86400,
  };
  app.use(cors(corsOptions));

  // Enhanced Security Configuration
  app.use(
    helmet({
      contentSecurityPolicy: process.env.NODE_ENV === "production",
      crossOriginEmbedderPolicy: process.env.NODE_ENV === "production",
    })
  );

  // Enhanced Rate Limiting
  const limiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    max: process.env.RATE_LIMIT || 100,
    standardHeaders: true,
    legacyHeaders: false,
    skip: (req) => {
      // Skip rate limiting for specific IPs or internal requests
      return req.ip === "127.0.0.1" || req.ip === "::1";
    },
    handler: (req, res) => {
      logger.warn(`Rate limit exceeded for IP: ${req.ip}`);
      res.status(429).json({
        error: "Too many requests",
        retryAfter: Math.ceil(limiter.windowMs / 1000),
      });
    },
  });
  app.use(limiter);

  // Request Logging Middleware
  app.use((req, res, next) => {
    const start = Date.now();
    res.on("finish", () => {
      const duration = Date.now() - start;
      logger.info({
        method: req.method,
        path: req.path,
        ip: req.ip,
        statusCode: res.statusCode,
        duration: `${duration}ms`,
        userAgent: req.get("user-agent"),
      });
    });
    next();
  });
};

// Enhanced Proxy Routes Setup
const setupProxyRoutes = () => {
  // Health Check Route with Service Status
  app.get("/health", async (req, res) => {
    try {
      const services = {
        main: process.env.MAIN_SERVICE_URL,
        notifications: process.env.NOTIFICATION_SERVICE_URL,
        feed: process.env.FEED_SERVICE_URL,
      };

      const serviceStatus = {};

      for (const [service, url] of Object.entries(services)) {
        try {
          const response = await fetch(`${url}/health`, { timeout: 5000 });
          serviceStatus[service] = response.ok ? "healthy" : "unhealthy";
        } catch (error) {
          serviceStatus[service] = "unavailable";
        }
      }

      res.status(200).json({
        status: "healthy",
        timestamp: new Date().toISOString(),
        services: serviceStatus,
        uptime: process.uptime(),
      });
    } catch (error) {
      logger.error("Health check failed:", error);
      res.status(500).json({ status: "error", message: "Health check failed" });
    }
  });

  // Common Proxy Options
  const createProxyOptions = (serviceName, serviceUrl) => ({
    target: serviceUrl,
    changeOrigin: true,
    pathRewrite: {
      [`^/api/${serviceName}`]: "",
    },
    onProxyReq: (proxyReq, req, res) => {
      proxyReq.setHeader("x-forwarded-for", req.ip);

      if (["POST", "PUT", "PATCH"].includes(req.method) && req.body) {
        const bodyData = JSON.stringify(req.body);
        proxyReq.removeHeader("content-length");
        proxyReq.setHeader("Content-Type", "application/json");
        proxyReq.setHeader("Content-Length", Buffer.byteLength(bodyData));
        proxyReq.write(bodyData);
      }
    },
    onProxyRes: (proxyRes, req, res) => {
      proxyRes.headers["x-proxy-service"] = serviceName;
    },
    bodyParser: {
      enabled: true,
      json: {
        limit: "10mb",
      },
    },
    methods: ["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
    onError: (err, req, res) => {
      logger.error(`Proxy error for ${serviceName}:`, {
        error: err.message,
        path: req.path,
        method: req.method,
      });
      
      if (!res.headersSent) {
        res.status(502).json({
          error: "Bad Gateway",
          service: serviceName,
          message: process.env.NODE_ENV === "development" ? err.message : "Service unavailable",
        });
      }
    },
  });

  const setupServiceProxy = (serviceName, serviceUrl) => {
    if (!serviceUrl) {
      logger.warn(`${serviceName} service URL not configured`);
      return;
    }

    app.use(`/api/${serviceName}`, express.json({ limit: "10mb" }));
    app.use(`/api/${serviceName}`, express.urlencoded({ extended: true, limit: "10mb" }));
    app.use(
      `/api/${serviceName}`,
      createProxyMiddleware(createProxyOptions(serviceName, serviceUrl))
    );
  };

  // Setup all service proxies
  setupServiceProxy(
    "main",
    process.env.MAIN_SERVICE_URL || "http://localhost:3002"
  );
  setupServiceProxy(
    "notifications",
    process.env.NOTIFICATION_SERVICE_URL || "http://localhost:4001"
  );
  setupServiceProxy(
    "feed",
    process.env.FEED_SERVICE_URL || "http://localhost:3003"
  );
};

// Enhanced Error Handling Setup
const setupErrorHandling = () => {
  // 404 Handler
  app.use((req, res) => {
    logger.warn("404 Not Found:", {
      path: req.path,
      method: req.method,
      ip: req.ip,
    });
    res.status(404).json({
      error: "Not Found",
      path: req.path,
      method: req.method,
      timestamp: new Date().toISOString(),
    });
  });

  // Global Error Handler
  app.use((err, req, res, next) => {
    const errorResponse = {
      error: err.name || "Internal Server Error",
      message: err.message || "An unexpected error occurred",
      timestamp: new Date().toISOString(),
      path: req.path,
      method: req.method,
    };

    if (process.env.NODE_ENV === "development") {
      errorResponse.stack = err.stack;
    }

    const statusCode = err.statusCode || 500;
    logger.error("Unhandled Error:", {
      ...errorResponse,
      stack: err.stack,
    });

    res.status(statusCode).json(errorResponse);
  });
};

// Enhanced Server Start Function
const startServer = () => {
  const PORT = parseInt(process.env.PORT || "3000", 10);

  const server = app.listen(PORT, () => {
    logger.info(`🚀 API Gateway running on port ${PORT}`);
    logger.info(`🌐 Environment: ${process.env.NODE_ENV || "development"}`);
    logger.info(`📝 Logging level: ${logger.level}`);
  });

  // Enhanced Graceful Shutdown
  const gracefulShutdown = (signal) => {
    logger.info(`${signal} signal received. Starting graceful shutdown...`);

    server.close((err) => {
      if (err) {
        logger.error("Error during server shutdown:", err);
        process.exit(1);
      }

      logger.info("HTTP server closed successfully");
      process.exit(0);
    });

    // Force shutdown after timeout
    setTimeout(() => {
      logger.error("Forced shutdown after timeout");
      process.exit(1);
    }, 30000);
  };

  process.on("SIGTERM", () => gracefulShutdown("SIGTERM"));
  process.on("SIGINT", () => gracefulShutdown("SIGINT"));

  // Handle uncaught exceptions
  process.on("uncaughtException", (err) => {
    logger.error("Uncaught Exception:", err);
    gracefulShutdown("UNCAUGHT_EXCEPTION");
  });

  // Handle unhandled promise rejections
  process.on("unhandledRejection", (reason, promise) => {
    logger.error("Unhandled Promise Rejection:", reason);
    gracefulShutdown("UNHANDLED_REJECTION");
  });

  return server;
};

// Initialize Application
const initializeApp = () => {
  setupMiddleware();
  setupProxyRoutes();
  setupErrorHandling();
  return startServer();
};

initializeApp();

export default app;
export { logger };
