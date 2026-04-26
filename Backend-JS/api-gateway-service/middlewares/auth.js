const jwt = require("jsonwebtoken");

// Paths that bypass JWT verification. Matched with startsWith against req.path
// AFTER the gateway mount. Keep this list as small as possible.
const PUBLIC_PATHS = [
  "/health",
  "/api/main/auth/initiate-auth",
  "/api/main/auth/verify-otp",
  "/api/main/auth/signup-with-phone",
  "/api/main/auth/admin/login",
  // Refresh must be reachable without a valid access token — that's
  // the whole point of it. It authenticates via the body refresh token.
  "/api/main/auth/refresh-token",
  "/api/main/auth/logout",
  // Splash screen pre-fetches flags before login; the upstream handler
  // uses optionalAuth so identity is only used for cohort splits.
  "/api/feature-flags",
];

const isPublic = (path) => {
  for (const p of PUBLIC_PATHS) {
    if (path === p || path.startsWith(p + "/") || path.startsWith(p + "?")) {
      return true;
    }
  }
  return false;
};

const extractToken = (req) => {
  const authHeader = req.header("Authorization");
  if (authHeader && authHeader.startsWith("Bearer ")) {
    return authHeader.substring(7);
  }
  if (req.cookies && req.cookies.token) {
    return req.cookies.token;
  }
  return null;
};

// Defense-in-depth: strip any client-supplied identity headers before we
// forward. Downstream services' `internalAuth` trusts X-User-Id /
// X-Internal-Request blindly, so if the client sets them we'd hand over
// an auth bypass. Reset them here and re-emit only for verified requests.
const scrubIdentityHeaders = (req) => {
  delete req.headers["x-user-id"];
  delete req.headers["x-internal-request"];
  delete req.headers["x-user-role"];
  delete req.headers["x-user-accounttype"];
};

const gatewayAuth = (req, res, next) => {
  scrubIdentityHeaders(req);

  if (req.method === "OPTIONS" || isPublic(req.originalUrl)) {
    return next();
  }

  const token = extractToken(req);
  if (!token) {
    return res.status(401).json({
      status: "error",
      message: "Authentication required.",
    });
  }

  const secret = process.env.JWT_SECRET;
  if (!secret) {
    console.error("JWT_SECRET not configured on gateway");
    return res.status(500).json({
      status: "error",
      message: "Gateway auth not configured.",
    });
  }

  try {
    const decoded = jwt.verify(token, secret);
    req.user = decoded;

    // Re-emit trusted identity headers for downstream services. These
    // are overwritten later in the proxyReq hook so they reach the
    // upstream with values derived from the verified JWT only.
    req.trustedUserId = decoded._id || decoded.id || decoded.userId;
    req.trustedAccountType = decoded.accountType;
    next();
  } catch (err) {
    console.error("[gatewayAuth] JWT verify failed:", err.name, err.message, "path=", req.originalUrl);
    if (err.name === "TokenExpiredError") {
      return res.status(401).json({
        status: "error",
        message: "Token has expired.",
      });
    }
    return res.status(401).json({
      status: "error",
      message: "Invalid token.",
    });
  }
};

module.exports = { gatewayAuth, isPublic, PUBLIC_PATHS };
