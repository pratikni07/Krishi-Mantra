const jwt = require("jsonwebtoken");
const Redis = require("../config/redis");

// Defense-in-depth: even though the gateway verifies the JWT and emits a
// trusted x-user-id header, message-svc must not accept that header at face
// value — if a pod in the same cluster is compromised it could set any
// x-user-id. So we re-verify the bearer token here and derive userId from
// the token's subject, falling back to the Redis user cache only as an
// attribute lookup (never as an auth decision).
module.exports = async (req, res, next) => {
  try {
    const token = req.headers.authorization?.split(" ")[1];
    if (!token) {
      return res.status(401).json({ error: "No token provided" });
    }

    const secret = process.env.JWT_SECRET;
    if (!secret) {
      console.error("JWT_SECRET not configured in message-svc");
      return res.status(500).json({ error: "Auth not configured" });
    }

    let decoded;
    try {
      decoded = jwt.verify(token, secret);
    } catch (err) {
      return res.status(401).json({
        error: err.name === "TokenExpiredError" ? "Token expired" : "Invalid token",
      });
    }

    const userId = decoded._id || decoded.id || decoded.userId;
    if (!userId) {
      return res.status(401).json({ error: "Token missing subject" });
    }

    // Warm the Redis user cache but don't gate on it — cache misses are
    // expected after eviction and shouldn't force re-login.
    try {
      await Redis.get(`user:${userId}`);
    } catch (_) {
      // Redis unavailability must not break auth.
    }

    req.user = { userId, accountType: decoded.accountType };
    next();
  } catch (error) {
    console.error("Auth middleware error:", error);
    return res.status(500).json({ error: "Internal server error" });
  }
};
