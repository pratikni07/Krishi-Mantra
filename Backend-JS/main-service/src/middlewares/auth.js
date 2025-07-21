const jwt = require("jsonwebtoken");
const User = require("../model/User");
const Redis = require("ioredis");
const { logger } = require("../utils/logger");

// Initialize Redis client for caching and shared state
let redisClient = null;
try {
  redisClient = new Redis({
    host: process.env.REDIS_HOST || 'localhost',
    port: process.env.REDIS_PORT || 6379,
    password: process.env.REDIS_PASSWORD || '',
    retryStrategy: (times) => Math.min(times * 50, 2000),
  });
  
  redisClient.on("error", (err) => {
    logger.error("Redis auth client error:", err);
  });
  
  redisClient.on("connect", () => {
    logger.info("Connected to Redis for auth");
  });
} catch (error) {
  logger.error("Redis auth client initialization error:", error);
}

// Authentication middleware
exports.auth = async (req, res, next) => {
  try {
    // Get token from various sources
    const token = 
      req.headers.authorization?.replace("Bearer ", "") || 
      req.cookies?.token || 
      req.body?.token;
      
    if (!token) {
      return res.status(401).json({
        success: false,
        message: "Authentication token is missing",
      });
    }
    
    // Check if token is blacklisted in Redis
    if (redisClient) {
      const isBlacklisted = await redisClient.get(`bl_${token}`);
      if (isBlacklisted) {
        return res.status(401).json({
          success: false,
          message: "Token has been revoked",
        });
      }
    }
    
    // Verify the token
    try {
      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      
      // Get user from database or Redis cache
      let user = null;
      
      // Try to get from Redis cache first
      if (redisClient) {
        const cachedUser = await redisClient.get(`user_details:${decoded.id}`);
        if (cachedUser) {
          user = JSON.parse(cachedUser);
        }
      }
      
      // If not in cache, get from database and cache it
      if (!user) {
        user = await User.findById(decoded.id).select("-password");
        
        if (!user) {
          return res.status(401).json({
            success: false,
            message: "User not found",
          });
        }
        
        // Cache user in Redis for future requests
        if (redisClient) {
          await redisClient.setex(`user_details:${decoded.id}`, 3600, JSON.stringify(user));
        }
      }
      
      // Add user and token data to request object
      req.user = decoded;
      req.user.details = user;
      req.token = token;
      
      next();
    } catch (err) {
      logger.error("JWT verification error:", err);
      return res.status(401).json({
        success: false,
        message: "Invalid or expired token",
      });
    }
  } catch (error) {
    logger.error("Authentication error:", error);
    return res.status(500).json({
      success: false,
      message: "Something went wrong while authenticating",
    });
  }
};

// Role-based access control middleware generators
const createRoleMiddleware = (role) => {
  return async (req, res, next) => {
    try {
      if (req.user.accountType !== role) {
        return res.status(403).json({
          success: false,
          message: `This is a protected route for ${role} only`,
        });
      }
      next();
    } catch (error) {
      logger.error(`Role verification error (${role}):`, error);
      return res.status(500).json({
        success: false,
        message: "User role cannot be verified",
      });
    }
  };
};

// Role-specific middleware
exports.isConsultant = createRoleMiddleware("consultant");
exports.isUser = createRoleMiddleware("user");
exports.isAdmin = createRoleMiddleware("admin");
exports.isMarketplace = createRoleMiddleware("marketplace");

// Multiple roles middleware
exports.hasAnyRole = (roles = []) => {
  return async (req, res, next) => {
    try {
      if (!roles.includes(req.user.accountType)) {
        return res.status(403).json({
          success: false,
          message: `Access denied. Required roles: ${roles.join(', ')}`,
        });
      }
      next();
    } catch (error) {
      logger.error("Role verification error:", error);
      return res.status(500).json({
        success: false,
        message: "User role cannot be verified",
      });
    }
  };
};
