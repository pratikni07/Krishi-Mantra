const express = require("express");
const dotenv = require("dotenv");
const cors = require("cors");
const cookieParser = require("cookie-parser");
const fileUpload = require("express-fileupload");
const helmet = require("helmet");
const connect = require("./config/database");
const winston = require("winston");
const Joi = require("joi");
const rateLimit = require("express-rate-limit");
const Redis = require("redis");
const path = require("path");
const { MemoryStore } = require("express-rate-limit");
const statusMonitor = require("express-status-monitor");

const userRoutes = require("./routes/User");
const companyRoutes = require("./routes/companyRoutes");
const productRoutes = require("./routes/productRoutes");
const newsRoutes = require("./routes/newsRoutes");
const adsRoutes = require("./routes/AdsRoutes");
const serviceRoutes = require("./routes/ServiceRoutes");
const userRoutesOne = require("./routes/UserRoutes");
const cropRoutes = require("./routes/cropCalendar");
const schemeRoutes = require("./routes/schemeRoutes");

// Load environment variables based on NODE_ENV
require('./config/environment')();

// Validate environment variables
const envSchema = Joi.object({
  NODE_ENV: Joi.string()
    .valid("development", "production")
    .default("development"),
  PORT: Joi.number().default(3002),
  MONGODB_URL: Joi.string().uri().required(),
  CORS_ORIGIN: Joi.string().uri().required(),
  JWT_SECRET: Joi.string().required(),
  REDIS_HOST: Joi.string().required(),
  REDIS_PORT: Joi.number().default(6379),
  REDIS_PASSWORD: Joi.string().allow(''),
});

const app = express();
const PORT = process.env.PORT || 3002;

// Initialize logger
const logger = winston.createLogger({
  level: "info",
  transports: [
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.simple()
      ),
    }),
    new winston.transports.File({
      filename: "logs/app.log",
      format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.json()
      ),
    }),
  ],
});

const { error } = envSchema.validate(process.env, { allowUnknown: true });
if (error) {
  logger.error(`Config validation error: ${error.message}`);
  process.exit(1);
}

// Connect to database
connect();

// Apply security headers
app.use(helmet());

// Middleware setup
app.use(express.json({ limit: "10mb" }));
app.use(express.urlencoded({ extended: true, limit: "10mb" }));
app.use(cookieParser());

// Redis client configuration with proper error handling
let redisClient = null;
try {
  redisClient = Redis.createClient({
    host: process.env.REDIS_HOST,
    port: process.env.REDIS_PORT,
    password: process.env.REDIS_PASSWORD,
    // Add TLS configuration for production
    ...(process.env.NODE_ENV === "production" && {
      tls: {},
      socket: {
        servername: process.env.REDIS_HOST,
      },
    }),
  });

  redisClient.on("error", (err) => {
    console.warn("Redis client error:", err.message);
    console.warn("Application will continue without Redis rate limiting");
  });

  // Only connect if the connection is needed
  if (process.env.NODE_ENV === 'production') {
    redisClient.connect().catch(err => {
      console.warn("Redis connection failed:", err.message);
    });
  }
} catch (error) {
  console.warn("Redis client initialization error:", error.message);
  console.warn("Application will continue without Redis rate limiting");
}

// Configure rate limiting with memory store
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // Limit each IP to 100 requests per windowMs
  standardHeaders: true,
  legacyHeaders: false,
  store: new MemoryStore(),
  skipFailedRequests: true,
  handler: (req, res) => {
    res.status(429).json({
      error: "Too many requests, please try again later.",
    });
  },
});

app.use(
  statusMonitor({
    path: "/status",
    spans: [
      { interval: 1, retention: 60 },
      { interval: 5, retention: 60 },
      { interval: 15, retention: 60 },
    ],
    chartVisibility: {
      cpu: true,
      mem: true,
      load: true,
      eventLoop: true,
      heap: true,
      responseTime: true,
      rps: true,
      statusCodes: true,
    },
  })
);

console.log(process.env.MONGODB_URL);

// Configure CORS for production
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
        console.log("Blocked by CORS in main-service:", origin);
        callback(null, true);
      }
    },
    methods: ["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization"],
    credentials: true,
    maxAge: 86400,
  })
);

// File upload configuration
app.use(
  fileUpload({
    useTempFiles: true,
    tempFileDir: path.join(__dirname, "temp"),
  })
);

// Routes
app.get("/", (req, res) => {
  res.status(200).json({
    message: "Welcome to the API",
  });
});

app.get("/health", (req, res) => {
  try {
    logger.info("Health check received", {
      headers: req.headers,
      ip: req.ip,
    });

    res.setHeader("Content-Type", "application/json");
    res.status(200).json({
      status: "OK",
      timestamp: new Date().toISOString(),
      service: "main",
      port: PORT,
      environment: process.env.NODE_ENV || "development",
    });
  } catch (error) {
    logger.error("Health check error:", error);
    res.status(500).json({
      status: "ERROR",
      message: error.message,
    });
  }
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

app.use((req, res, next) => {
  logger.info({
    method: req.method,
    path: req.path,
    body: req.method === "POST" ? req.body : undefined,
    headers: req.headers,
  });
  next();
});

app.use((err, req, res, next) => {
  logger.error("Error:", {
    message: err.message,
    stack: err.stack,
    path: req.path,
    method: req.method,
  });

  res.status(err.status || 500).json({
    error: err.message || "Internal Server Error",
    status: err.status || 500,
  });
});

// Graceful shutdown
process.on("SIGINT", () => {
  logger.info("Server is shutting down...");
  process.exit();
});

// Start the server
app.listen(PORT, () => {
  logger.info(`Server is running on port ${PORT}`);
});
