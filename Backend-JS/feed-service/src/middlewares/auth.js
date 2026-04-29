const jwt = require("jsonwebtoken");

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

/**
 * Authentication middleware. Re-verifies the JWT inside the service so
 * direct service access can't bypass auth by spoofing gateway-injected
 * headers.
 */
const auth = (req, res, next) => {
  const token = extractToken(req);

  if (!token) {
    return res.status(401).json({
      status: "error",
      message: "Authentication required.",
    });
  }

  if (!process.env.JWT_SECRET) {
    console.error("[feed-service auth] JWT_SECRET not configured");
    return res.status(500).json({
      status: "error",
      message: "Auth not configured.",
    });
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded;
    return next();
  } catch (err) {
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

const optionalAuth = (req, res, next) => {
  const token = extractToken(req);
  if (!token || !process.env.JWT_SECRET) {
    req.user = null;
    return next();
  }
  try {
    req.user = jwt.verify(token, process.env.JWT_SECRET);
  } catch (_) {
    req.user = null;
  }
  return next();
};

module.exports = { auth, optionalAuth };
