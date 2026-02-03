const express = require("express");
const { createProxyMiddleware } = require("http-proxy-middleware");
const cors = require("cors");
const rateLimit = require("express-rate-limit");
require("dotenv").config();
const uploadRoutes = require("./routes/uploadRoutes");

const app = express();
const PORT = process.env.PORT || 3001;

// Rate limiting configuration
const limiter = rateLimit({
  windowMs: process.env.RATE_LIMIT_WINDOW_MS || 900000, // 15 minutes
  max: process.env.RATE_LIMIT_MAX_REQUESTS || 100,
  message: "Too many requests from this IP, please try again later.",
  standardHeaders: true,
  legacyHeaders: false,
});

// Middleware
app.use(limiter);
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
      // Allow requests with no origin (like mobile apps or curl requests)
      if (!origin) return callback(null, true);

      if (
        allowedOrigins.indexOf(origin) !== -1 ||
        process.env.NODE_ENV === "development"
      ) {
        callback(null, true);
      } else {
        console.log("Blocked by CORS:", origin);
        callback(new Error("Not allowed by CORS"), false);
      }
    },
    credentials: true,
    methods: ["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization"],
  })
);

// Request logging middleware
app.use((req, res, next) => {
  if (process.env.LOG_LEVEL === 'debug') {
    console.log(`[${new Date().toISOString()}] ${req.method} ${req.url}`);
  }
  next();
});

// Log environment variables only in debug mode
if (process.env.LOG_LEVEL === 'debug') {
  console.log("Environment Variables:", {
    MAIN_SERVICE_URL: process.env.MAIN_SERVICE_URL,
    MESSAGE_SERVICE_URL: process.env.MESSAGE_SERVICE_URL,
    FEED_SERVICE_URL: process.env.FEED_SERVICE_URL,
    REEL_SERVICE_URL: process.env.REEL_SERVICE_URL,
    ENGAGEMENT_SERVICE_URL: process.env.ENGAGEMENT_SERVICE_URL,
    ALLOWED_ORIGINS: process.env.ALLOWED_ORIGINS,
  });
}

const createServiceProxy = (serviceName, serviceUrl, pathRewrite) => {
  console.log(
    "Creating service proxy for:",
    serviceName,
    serviceUrl,
    pathRewrite
  );
  if (!serviceUrl) {
    throw new Error(
      `${serviceName} URL is not configured. Please check your .env file.`
    );
  }

  return createProxyMiddleware({
    target: serviceUrl.trim(),
    changeOrigin: true,
    pathRewrite: pathRewrite,
    // Don't parse body for multipart requests - let them pass through as-is
    selfHandleResponse: false,
    on: {
      proxyReq: (proxyReq, req, res) => {
        console.log("--------------------------------");
        console.log(`[${serviceName}] Request:`, req.method, req.url);
        console.log(`[${serviceName}] Content-Type:`, req.headers['content-type']);

        // Check if this is a multipart request - don't modify these
        const contentType = req.headers['content-type'] || '';
        const isMultipart = contentType.includes('multipart/form-data');

        if (isMultipart) {
          // For multipart requests, just set forwarding headers and let it pass through
          console.log(`[${serviceName}] Multipart request detected - passing through unchanged`);
          proxyReq.setHeader("x-forwarded-for", req.ip);
          proxyReq.setHeader("x-forwarded-host", req.headers.host);
          proxyReq.setHeader("x-forwarded-proto", req.protocol);
          // Don't modify body or content-type for multipart
        } else if (["POST", "PUT", "PATCH"].includes(req.method) && req.body && Object.keys(req.body).length > 0) {
          const bodyData = JSON.stringify(req.body);
          console.log(`[${serviceName}] JSON body:`, bodyData.substring(0, 200));
          proxyReq.setHeader("Content-Type", "application/json");
          proxyReq.setHeader("Content-Length", Buffer.byteLength(bodyData));
          proxyReq.setHeader("x-forwarded-for", req.ip);
          proxyReq.setHeader("x-forwarded-host", req.headers.host);
          proxyReq.setHeader("x-forwarded-proto", req.protocol);
          proxyReq.write(bodyData);
        } else {
          proxyReq.setHeader("x-forwarded-for", req.ip);
          proxyReq.setHeader("x-forwarded-host", req.headers.host);
          proxyReq.setHeader("x-forwarded-proto", req.protocol);
        }
      },
      proxyRes: (proxyRes, req, res) => {
        console.log(
          `[${serviceName}] Proxy response status: ${proxyRes.statusCode}`
        );
      },
      error: (err, req, res) => {
        console.error(`Proxy Error (${serviceName}): ${err.message}`);
        res.status(502).json({
          status: "error",
          message: `${serviceName} unavailable`,
          error:
            process.env.NODE_ENV === "development" ? err.message : undefined,
        });
      },
    },
  });
};

try {
  console.log("--------------------------------");
  console.log("Initializing service proxies...");
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

  // Reel service proxy with custom path handling for both reels and videos
  const reelServiceProxy = createProxyMiddleware({
    target: process.env.REEL_SERVICE_URL.trim(),
    changeOrigin: true,
    pathRewrite: (path, req) => {
      // Path is already stripped of /api/reels mount point
      // /videos/... -> /videos/... (keep as is for video tutorials)
      if (path.startsWith('/videos')) {
        console.log(`[Reel Service] Path rewrite: ${path} -> ${path}`);
        return path;
      }
      // Everything else: /... -> /reels/... (prepend /reels)
      const newPath = '/reels' + path;
      console.log(`[Reel Service] Path rewrite: ${path} -> ${newPath}`);
      return newPath;
    },
    on: {
      proxyReq: (proxyReq, req, res) => {
        console.log("--------------------------------");
        console.log("[Reel Service] Original URL:", req.originalUrl);
        console.log("[Reel Service] Proxied path:", proxyReq.path);

        if (["POST", "PUT", "PATCH"].includes(req.method) && req.body) {
          const bodyData = JSON.stringify(req.body);
          proxyReq.setHeader("Content-Type", "application/json");
          proxyReq.setHeader("Content-Length", Buffer.byteLength(bodyData));
          proxyReq.setHeader("x-forwarded-for", req.ip);
          proxyReq.setHeader("x-forwarded-host", req.headers.host);
          proxyReq.setHeader("x-forwarded-proto", req.protocol);
          proxyReq.write(bodyData);
        } else {
          proxyReq.setHeader("x-forwarded-for", req.ip);
          proxyReq.setHeader("x-forwarded-host", req.headers.host);
          proxyReq.setHeader("x-forwarded-proto", req.protocol);
        }
      },
      proxyRes: (proxyRes, req, res) => {
        console.log(`[Reel Service] Response status: ${proxyRes.statusCode}`);
      },
      error: (err, req, res) => {
        console.error(`[Reel Service] Proxy Error: ${err.message}`);
        res.status(502).json({
          status: "error",
          message: "Reel Service unavailable",
          error: process.env.NODE_ENV === "development" ? err.message : undefined,
        });
      },
    },
  });

  const notificationServiceProxy = createServiceProxy(
    "Notification Service",
    process.env.NOTIFICATION_SERVICE_URL,
    { "^/api/notification": "" }
  );

  // AI Service proxy - routes to message-svc which handles AI endpoints
  // Express strips /api/ai when mounted, so we need to add it back for message-svc
  const aiServiceProxy = createServiceProxy(
    "AI Service",
    process.env.MESSAGE_SERVICE_URL,
    { "^/": "/api/ai/" } // Prepend /api/ai to the path
  );

  // Engagement Service proxy - user activity tracking and analytics
  const engagementServiceProxy = createServiceProxy(
    "Engagement Service",
    process.env.ENGAGEMENT_SERVICE_URL,
    { "^/": "/api/engagement/" }
  );

  // Routes
  app.use("/api/main", mainServiceProxy);
  app.use("/api/messages", messageServiceProxy);
  app.use("/api/ai", aiServiceProxy);
  app.use("/api/feed", feedServiceProxy);
  app.use("/api/reels", reelServiceProxy);
  app.use("/api/notification", notificationServiceProxy);
  app.use("/api/engagement", engagementServiceProxy);
  app.use("/api/upload", uploadRoutes);
} catch (error) {
  console.error("Error setting up proxies:", error.message);
  process.exit(1);
}

// Health check endpoint
app.get("/health", (req, res) => {
  res.status(200).json({
    status: "healthy",
    timestamp: new Date().toISOString(),
  });
});

app.use((err, req, res, next) => {
  console.error("Global error:", err);
  res.status(500).json({
    status: "error",
    message: "Internal server error",
    error: process.env.NODE_ENV === "development" ? err.message : undefined,
  });
});

app.listen(PORT, () => {
  console.log(`API Gateway running on port ${PORT}`);
  console.log(`Environment: ${process.env.NODE_ENV}`);
});
