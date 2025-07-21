const express = require("express");
const dotenv = require("dotenv");
const cors = require("cors");
const cookieParser = require("cookie-parser");
const fileUpload = require("express-fileupload");
const helmet = require("helmet");
const path = require("path");
const compression = require("compression");
const cluster = require('cluster');
const os = require('os');

// Load environment variables based on NODE_ENV
require('./config/environment')();

// Import core modules
const connect = require("./config/database");
const { logger, requestLogger } = require("./utils/logger");
const redisService = require("./utils/redis");

// Routes
const userRoutes = require("./routes/User");
const companyRoutes = require("./routes/companyRoutes");
const productRoutes = require("./routes/productRoutes");
const newsRoutes = require("./routes/newsRoutes");
const adsRoutes = require("./routes/AdsRoutes");
const serviceRoutes = require("./routes/ServiceRoutes");
const userRoutesOne = require("./routes/UserRoutes");
const cropRoutes = require("./routes/cropCalendar");
const schemeRoutes = require("./routes/schemeRoutes");
const analyticsRoutes = require("./routes/AnalyticsRoutes");
const marketplaceRoutes = require("./routes/marketplaceRoutes");

// Determine if we should use clustering
const ENABLE_CLUSTERING = process.env.ENABLE_CLUSTERING === 'true' && process.env.NODE_ENV === 'production';
const numCPUs = os.cpus().length;

// Use clustering in production for better performance
if (ENABLE_CLUSTERING && cluster.isPrimary) {
  logger.info(`Primary ${process.pid} is running`);
  logger.info(`Setting up ${numCPUs} workers`);

  // Fork workers based on CPU count
  for (let i = 0; i < numCPUs; i++) {
    cluster.fork();
  }

  // Handle worker crashes
  cluster.on('exit', (worker, code, signal) => {
    logger.warn(`Worker ${worker.process.pid} died with code ${code} and signal ${signal}`);
    logger.info('Starting a new worker');
    cluster.fork();
  });
} else {
  // Worker process or single-process mode
  startServer();
}

function startServer() {
  const app = express();
  const PORT = process.env.PORT || 3002;

  // Apply security headers
  app.use(helmet({
    contentSecurityPolicy: process.env.NODE_ENV === 'production',
    crossOriginEmbedderPolicy: process.env.NODE_ENV === 'production',
  }));

  // Enable compression for responses
  app.use(compression());

  // Middleware setup
  app.use(express.json({ limit: "10mb" }));
  app.use(express.urlencoded({ extended: true, limit: "10mb" }));
  app.use(cookieParser());

  // Configure CORS
  app.use(
    cors({
      origin: function (origin, callback) {
        if (process.env.NODE_ENV === "development") {
          return callback(null, true);
        }
        const allowedOrigins = process.env.CORS_ORIGIN
          ? process.env.CORS_ORIGIN.split(",")
          : ["http://localhost:3000"];

        if (!origin || allowedOrigins.indexOf(origin) !== -1) {
          callback(null, true);
        } else {
          logger.warn(`Blocked by CORS in main-service: ${origin}`);
          callback(new Error('Not allowed by CORS'));
        }
      },
      methods: ["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
      allowedHeaders: ["Content-Type", "Authorization"],
      credentials: true,
      maxAge: 86400,
    })
  );

  // Request logging
  app.use(requestLogger);

  // File upload configuration
  app.use(
    fileUpload({
      useTempFiles: true,
      tempFileDir: path.join(__dirname, "temp"),
      limits: { fileSize: 10 * 1024 * 1024 }, // 10MB limit
      abortOnLimit: true,
    })
  );

  // Connect to database
  connect()
    .then(() => {
      logger.info('Database connected successfully');
    })
    .catch((err) => {
      logger.error('Database connection failed:', err);
      process.exit(1);
    });

  // Health check endpoint
  app.get("/health", (req, res) => {
    const healthData = {
      status: "OK",
      timestamp: new Date().toISOString(),
      service: "main",
      version: process.env.npm_package_version || '1.0.0',
      environment: process.env.NODE_ENV || "development",
      uptime: process.uptime(),
      pid: process.pid,
      memory: process.memoryUsage(),
      redis: redisService.isConnected ? 'connected' : 'disconnected',
    };

    res.status(200).json(healthData);
  });

  // API Routes
  app.get("/", (req, res) => {
    res.status(200).json({
      message: "Krishi Mantra API - Main Service",
      version: process.env.npm_package_version || '1.0.0',
      environment: process.env.NODE_ENV || "development"
    });
  });

  app.use("/auth", userRoutes);
  app.use("/companies", companyRoutes);
  app.use("/products", productRoutes);
  app.use("/ads", adsRoutes);
  app.use("/news", newsRoutes);
  app.use("/service", serviceRoutes);
  app.use("/user", userRoutesOne);
  app.use("/crop-calendar", cropRoutes);
  app.use("/schemes", schemeRoutes);
  app.use("/analytics", analyticsRoutes);
  app.use("/marketplace", marketplaceRoutes);

  // 404 handler
  app.use((req, res) => {
    res.status(404).json({
      error: "Not Found",
      message: `Route ${req.method} ${req.path} not found`
    });
  });

  // Global error handler
  app.use((err, req, res, next) => {
    logger.error("Error:", {
      message: err.message,
      stack: err.stack,
      path: req.path,
      method: req.method,
    });

    res.status(err.status || 500).json({
      error: process.env.NODE_ENV === 'production' ? 'Internal Server Error' : err.message,
      requestId: req.headers['x-trace-id']
    });
  });

  // Start server
  const server = app.listen(PORT, () => {
    logger.info(`Server running on port ${PORT} (${process.env.NODE_ENV} mode, PID: ${process.pid})`);
    logger.info(`Main database: ${process.env.MONGODB_URL}`);
  });

  // Handle graceful shutdown
  process.on('SIGTERM', () => {
    logger.info('SIGTERM signal received. Shutting down gracefully...');
    
    server.close(async () => {
      logger.info('HTTP server closed');
      
      // Close database connection
      try {
        const mongoose = require('mongoose');
        await mongoose.disconnect();
        logger.info('MongoDB connection closed');
      } catch (err) {
        logger.error('Error during MongoDB disconnect:', err);
      }
      
      // Close Redis connection if available
      try {
        await redisService.close();
        logger.info('Redis connection closed');
      } catch (err) {
        logger.error('Error during Redis disconnect:', err);
      }
      
      process.exit(0);
    });
  });

  // Handle uncaught exceptions
  process.on('uncaughtException', (error) => {
    logger.error('Uncaught Exception:', error);
    
    // In production, we might want to attempt a graceful restart
    if (process.env.NODE_ENV === 'production') {
      logger.error('Process will exit due to uncaught exception');
      process.exit(1);
    }
  });

  // Handle unhandled promise rejections
  process.on('unhandledRejection', (reason, promise) => {
    logger.error('Unhandled Promise Rejection:', reason);
  });
}

module.exports = { app: express() }; // For testing
