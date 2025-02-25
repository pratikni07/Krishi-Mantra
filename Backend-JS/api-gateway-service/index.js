const express = require("express");
const { createProxyMiddleware } = require("http-proxy-middleware");
const cors = require("cors");
const rateLimit = require("express-rate-limit");
require("dotenv").config();

const app = express();
const PORT = process.env.PORT || 3001;

// Rate limiting configuration
const limiter = rateLimit({
  windowMs: process.env.RATE_LIMIT_WINDOW_MS || 900000,
  max: process.env.RATE_LIMIT_MAX_REQUESTS || 100,
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
    origin: allowedOrigins,
    credentials: true,
  })
);

// Request logging middleware
app.use((req, res, next) => {
  console.log("Inside request logging middleware");
  console.log("Request received:", req.method, req.url);
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.url}`);
  next();
});

// Add console.log to debug environment variables
console.log("Environment Variables:", {
  MAIN_SERVICE_URL: process.env.MAIN_SERVICE_URL,
  MESSAGE_SERVICE_URL: process.env.MESSAGE_SERVICE_URL,
  FEED_SERVICE_URL: process.env.FEED_SERVICE_URL,
  REEL_SERVICE_URL: process.env.REEL_SERVICE_URL,
  ALLOWED_ORIGINS: process.env.ALLOWED_ORIGINS,
});

// Modify the service proxy creation to include default values and validation
// const createServiceProxy = (serviceName, serviceUrl, pathRewrite) => {
//   console.log('Creating service proxy for:', serviceName, serviceUrl, pathRewrite);
//   if (!serviceUrl) {
//     throw new Error(`${serviceName} URL is not configured. Please check your .env file.`);
//   }

//   return createProxyMiddleware({
//     target: serviceUrl.trim(),
//     changeOrigin: true,
//     pathRewrite: pathRewrite,
//     on: {
//       proxyReq: (proxyReq, req, res) => {
//         // Log the incoming request
//         console.log('--------------------------------');
//         console.log('Request received:', req.method, req.url, proxyReq);
//         // Handle POST/PUT/PATCH requests with body
//         if (['POST', 'PUT', 'PATCH'].includes(req.method) && req.body) {
//           const bodyData = JSON.stringify(req.body);
//           console.log('Body data:', bodyData);
//           // Remove content-length header if exists
//           proxyReq.removeHeader('Content-Length');
//           // Set new headers
//           proxyReq.setHeader('Content-Type', 'application/json');
//           proxyReq.setHeader('Content-Length', Buffer.byteLength(bodyData));
//           // Write body data
//           proxyReq.write(bodyData);
//         }

//         // Add forwarded headers
//         proxyReq.setHeader('x-forwarded-for', req.ip);
//         proxyReq.setHeader('x-forwarded-host', req.headers.host);
//         proxyReq.setHeader('x-forwarded-proto', req.protocol);
//       },
//       proxyRes: (proxyRes, req, res) => {
//         // Log the proxy response
//         console.log(`[${serviceName}] Proxy response status: ${proxyRes.statusCode}`);
//       },
//       error: (err, req, res) => {
//         console.error(`Proxy Error (${serviceName}): ${err.message}`);
//         res.status(502).json({
//           status: "error",
//           message: `${serviceName} unavailable`,
//           error: process.env.NODE_ENV === "development" ? err.message : undefined
//         });
//       },
//     },

//     // onError: (err, req, res) => {
//     //   console.error(`Proxy Error (${serviceName}): ${err.message}`);
//     //   res.status(502).json({
//     //     status: "error",
//     //     message: `${serviceName} unavailable`,
//     //     error: process.env.NODE_ENV === "development" ? err.message : undefined
//     //   });
//     // },
//     // onProxyRes: (proxyRes, req, res) => {
//     //   // Log the proxy response
//     //   console.log(`[${serviceName}] Proxy response status: ${proxyRes.statusCode}`);
//     // }
//   });
// };

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
    on: {
      proxyReq: (proxyReq, req, res) => {
        // Log the incoming request
        console.log("--------------------------------");
        console.log("Request received:", req.method, req.url);

        // Handle POST/PUT/PATCH requests with body
        if (["POST", "PUT", "PATCH"].includes(req.method) && req.body) {
          const bodyData = JSON.stringify(req.body);
          console.log("Body data:", bodyData);

          // Set headers before writing body
          proxyReq.setHeader("Content-Type", "application/json");
          proxyReq.setHeader("Content-Length", Buffer.byteLength(bodyData));

          // Add forwarded headers
          proxyReq.setHeader("x-forwarded-for", req.ip);
          proxyReq.setHeader("x-forwarded-host", req.headers.host);
          proxyReq.setHeader("x-forwarded-proto", req.protocol);

          // Write body data
          proxyReq.write(bodyData);
        } else {
          // For non-body requests, just set forwarded headers
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

  const reelServiceProxy = createServiceProxy(
    "Reel Service",
    process.env.REEL_SERVICE_URL,
    { "^/api/reels": "" }
  );

  // Routes
  app.use("/api/main", mainServiceProxy);
  app.use("/api/messages", messageServiceProxy);
  app.use("/api/feed", feedServiceProxy);
  app.use("/api/reels", reelServiceProxy);
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

// Global error handler
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
