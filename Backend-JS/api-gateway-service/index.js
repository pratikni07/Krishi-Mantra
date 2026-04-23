const express = require("express");
const { createProxyMiddleware } = require("http-proxy-middleware");
const cors = require("cors");
const rateLimit = require("express-rate-limit");
const cookieParser = require("cookie-parser");
require("dotenv").config();
const uploadRoutes = require("./routes/uploadRoutes");
const { gatewayAuth } = require("./middlewares/auth");
const mongoSanitize = require("./middlewares/mongoSanitize");
const { createBreaker } = require("./middlewares/circuitBreaker");

const app = express();
const PORT = process.env.PORT || 3001;

// The gateway always sits behind an ingress/load-balancer, so express
// should take the real client IP from the X-Forwarded-For chain. Without
// this, every request appears to come from the proxy's IP and the rate
// limiter collapses all users into one bucket.
app.set("trust proxy", Number(process.env.TRUST_PROXY_HOPS || 1));

const toInt = (v, fallback) => {
  const n = parseInt(v, 10);
  return Number.isFinite(n) && n > 0 ? n : fallback;
};

// Global per-IP limiter — acts as a last-resort circuit breaker. Set
// generously because mobile carriers frequently share a public IP across
// many real users (CGNAT). Per-user limits (below) do the real work.
const globalLimiter = rateLimit({
  windowMs: toInt(process.env.RATE_LIMIT_WINDOW_MS, 15 * 60 * 1000),
  max: toInt(process.env.RATE_LIMIT_MAX_REQUESTS, 1000),
  message: "Too many requests from this IP, please try again later.",
  standardHeaders: true,
  legacyHeaders: false,
});

// Strict limiter on unauthenticated auth endpoints — this is where
// credential-stuffing and OTP brute-force attacks land. Applied per-IP
// before the body is parsed so the attacker pays the cost.
const authLimiter = rateLimit({
  windowMs: toInt(process.env.AUTH_RATE_LIMIT_WINDOW_MS, 15 * 60 * 1000),
  max: toInt(process.env.AUTH_RATE_LIMIT_MAX, 20),
  message: "Too many auth attempts from this IP. Please wait and retry.",
  standardHeaders: true,
  legacyHeaders: false,
  skipSuccessfulRequests: false,
});

// Per-user limiter for authenticated traffic. Keyed on the verified
// JWT subject so a single compromised IP can't exhaust the whole bucket
// and one abusive account can't drown out the rest.
const userLimiter = rateLimit({
  windowMs: toInt(process.env.USER_RATE_LIMIT_WINDOW_MS, 60 * 1000),
  max: toInt(process.env.USER_RATE_LIMIT_MAX, 120),
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: (req) => req.trustedUserId || req.ip,
  skip: (req) => !req.trustedUserId, // only applies once gatewayAuth has run
  message: "Too many requests. Please slow down.",
});

// Middleware
app.use(globalLimiter);
app.use(
  [
    "/api/main/auth/initiate-auth",
    "/api/main/auth/verify-otp",
    "/api/main/auth/signup-with-phone",
    "/api/main/auth/admin/login",
    "/api/main/auth/refresh-token",
  ],
  authLimiter
);
app.use(cookieParser());
app.use(express.json({ limit: "10mb" }));
app.use(express.urlencoded({ extended: true, limit: "10mb" }));

// Mongo operator injection defense. Runs after body parsers so req.body
// keys are available, before proxy hooks forward to downstream services.
app.use(mongoSanitize);

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

  const breaker = createBreaker(serviceName);

  const proxy = createProxyMiddleware({
    target: serviceUrl.trim(),
    changeOrigin: true,
    pathRewrite: pathRewrite,
    // Don't parse body for multipart requests - let them pass through as-is
    selfHandleResponse: false,
    proxyTimeout: 55000,
    timeout: 55000,
    on: {
      proxyReq: (proxyReq, req, res) => {
        console.log("--------------------------------");
        console.log(`[${serviceName}] Request:`, req.method, req.url);
        console.log(`[${serviceName}] Content-Type:`, req.headers['content-type']);

        // Re-emit trusted identity headers (derived from the JWT the gateway
        // just verified). Client-supplied copies were already stripped in
        // gatewayAuth. These are what downstream services should trust.
        if (req.trustedUserId) {
          proxyReq.setHeader("x-user-id", req.trustedUserId);
        }
        if (req.trustedAccountType) {
          proxyReq.setHeader("x-user-accounttype", req.trustedAccountType);
        }

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
        // 5xx from downstream counts as a failure for breaker purposes; 4xx
        // is the client's problem, not the service's.
        if (proxyRes.statusCode >= 500) breaker.recordFailure();
        else breaker.recordSuccess();
      },
      error: (err, req, res) => {
        console.error(`Proxy Error (${serviceName}): ${err.message}`);
        breaker.recordFailure();
        if (!res.headersSent) {
          res.status(502).json({
            status: "error",
            message: `${serviceName} unavailable`,
            error:
              process.env.NODE_ENV === "development" ? err.message : undefined,
          });
        }
      },
    },
  });

  // Compose breaker-gate in front of the proxy so open-circuit requests are
  // rejected before we dial the downstream socket.
  return [breaker.middleware, proxy];
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
  const reelBreaker = createBreaker("Reel Service");
  const reelProxy = createProxyMiddleware({
    target: process.env.REEL_SERVICE_URL.trim(),
    changeOrigin: true,
    proxyTimeout: 120000, // larger uploads
    timeout: 120000,
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

        if (req.trustedUserId) {
          proxyReq.setHeader("x-user-id", req.trustedUserId);
        }
        if (req.trustedAccountType) {
          proxyReq.setHeader("x-user-accounttype", req.trustedAccountType);
        }

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
        if (proxyRes.statusCode >= 500) reelBreaker.recordFailure();
        else reelBreaker.recordSuccess();
      },
      error: (err, req, res) => {
        console.error(`[Reel Service] Proxy Error: ${err.message}`);
        reelBreaker.recordFailure();
        if (!res.headersSent) {
          res.status(502).json({
            status: "error",
            message: "Reel Service unavailable",
            error: process.env.NODE_ENV === "development" ? err.message : undefined,
          });
        }
      },
    },
  });
  const reelServiceProxy = [reelBreaker.middleware, reelProxy];

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

  // Gateway-level JWT verification (bypasses PUBLIC_PATHS).
  // Must run AFTER body/cookie parsers and BEFORE the proxies so it can
  // strip client-supplied identity headers and attach trusted ones.
  app.use(gatewayAuth);

  // Per-user rate limiter. Mounted after gatewayAuth because its
  // keyGenerator reads req.trustedUserId (set by gatewayAuth on
  // authenticated requests).
  app.use(userLimiter);

  // Routes. createServiceProxy returns [breakerMiddleware, proxy]; spread it
  // so Express sees two ordered handlers.
  app.use("/api/main", ...mainServiceProxy);
  app.use("/api/messages", ...messageServiceProxy);
  app.use("/api/ai", ...aiServiceProxy);
  app.use("/api/feed", ...feedServiceProxy);
  app.use("/api/reels", ...reelServiceProxy);
  app.use("/api/notification", ...notificationServiceProxy);
  app.use("/api/engagement", ...engagementServiceProxy);
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

const server = app.listen(PORT, () => {
  console.log(`API Gateway running on port ${PORT}`);
  console.log(`Environment: ${process.env.NODE_ENV}`);
});

// Per-request timeouts. Without these, a slow downstream can hold a gateway
// connection open indefinitely and pin a socket pool slot. Values keep room
// for large uploads (60s) while killing truly stuck requests.
server.setTimeout(60000);
server.headersTimeout = 65000; // must exceed keepAliveTimeout per Node HTTP docs
server.keepAliveTimeout = 61000;
server.requestTimeout = 60000;
