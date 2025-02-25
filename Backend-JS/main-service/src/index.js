const express = require("express");
const dotenv = require("dotenv");
const cors = require("cors");
const cookieParser = require("cookie-parser");
const fileUpload = require("express-fileupload");
const helmet = require("helmet");
const { cloudnairyconnect } = require("./config/cloudinary");
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
// Load environment variables
dotenv.config();

// Validate environment variables
const envSchema = Joi.object({
  PORT: Joi.number().default(3002),
  MONGODB_URL: Joi.string().uri().required(),
  CORS_ORIGIN: Joi.string().uri().default("*"),
  // CLOUDINARY_URL: Joi.string().uri().required()
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
  process.exit(1); // Exit the process gracefully
}

// Connect to database
connect();

// Apply security headers
app.use(helmet());

// Middleware setup
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));
app.use(cookieParser());

// Rate limiting setup using Redis (Optional: You can configure your own Redis)
const redisClient = Redis.createClient();

app.use(
  statusMonitor({
    path: "/status", // URL path for the dashboard
    spans: [
      { interval: 1, retention: 60 }, // 1 second for 1 minute
      { interval: 5, retention: 60 }, // 5 seconds for 5 minutes
      { interval: 15, retention: 60 }, // 15 seconds for 15 minutes
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

const limiter = rateLimit({
  store: new MemoryStore(), // Correct usage
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per window
  message: "Too many requests from this IP, please try again later.",
});

app.use(limiter);

// Custom configuration for express-status-monitor

// Configure CORS for production
app.use(cors({
  origin: process.env.CORS_ORIGIN || "*",
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  credentials: true,
  maxAge: 86400
}));

// File upload configuration
app.use(
  fileUpload({
    useTempFiles: true,
    tempFileDir: path.join(__dirname, "temp"), // Use dynamic paths instead of hardcoded
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
    // Log the incoming request
    logger.info("Health check received", {
      headers: req.headers,
      ip: req.ip
    });

    res.setHeader('Content-Type', 'application/json');
    res.status(200).json({
      status: "OK",
      timestamp: new Date().toISOString(),
      service: "main",
      port: PORT,
      environment: process.env.NODE_ENV || 'development'
    });
  } catch (error) {
    logger.error("Health check error:", error);
    res.status(500).json({ 
      status: "ERROR", 
      message: error.message 
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

// Add request logging middleware for debugging
app.use((req, res, next) => {
  logger.info({
    method: req.method,
    path: req.path,
    body: req.method === 'POST' ? req.body : undefined,
    headers: req.headers
  });
  next();
});

// Error handling middleware
app.use((err, req, res, next) => {
  logger.error('Error:', {
    message: err.message,
    stack: err.stack,
    path: req.path,
    method: req.method
  });
  
  res.status(err.status || 500).json({
    error: err.message || 'Internal Server Error',
    status: err.status || 500
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
