const jwt = require('jsonwebtoken');
const { ACCOUNT_TYPES, HTTP_STATUS } = require('../utils/constants');

/**
 * Extract token from request
 * @param {Request} req - Express request object
 * @returns {string|null} - JWT token or null
 */
const extractToken = (req) => {
  // Check Authorization header first (preferred method)
  const authHeader = req.header('Authorization');
  if (authHeader && authHeader.startsWith('Bearer ')) {
    return authHeader.substring(7);
  }

  // Fallback to cookie
  if (req.cookies && req.cookies.token) {
    return req.cookies.token;
  }

  return null;
};

/**
 * Authentication middleware
 * Verifies JWT token and attaches user to request
 */
const auth = async (req, res, next) => {
  try {
    const token = extractToken(req);

    if (!token) {
      return res.status(HTTP_STATUS.UNAUTHORIZED).json({
        success: false,
        message: 'Authentication required. Please provide a valid token.',
      });
    }

    try {
      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      req.user = decoded;
      next();
    } catch (err) {
      if (err.name === 'TokenExpiredError') {
        return res.status(HTTP_STATUS.UNAUTHORIZED).json({
          success: false,
          message: 'Token has expired. Please login again.',
        });
      }

      if (err.name === 'JsonWebTokenError') {
        return res.status(HTTP_STATUS.UNAUTHORIZED).json({
          success: false,
          message: 'Invalid token. Please login again.',
        });
      }

      return res.status(HTTP_STATUS.UNAUTHORIZED).json({
        success: false,
        message: 'Token validation failed.',
      });
    }
  } catch (error) {
    return res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({
      success: false,
      message: 'Authentication error. Please try again.',
    });
  }
};

/**
 * Role-based authorization middleware factory
 * @param {...string} allowedRoles - Roles allowed to access the route
 * @returns {Function} - Express middleware
 */
const authorize = (...allowedRoles) => {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(HTTP_STATUS.UNAUTHORIZED).json({
        success: false,
        message: 'Authentication required.',
      });
    }

    if (!allowedRoles.includes(req.user.accountType)) {
      return res.status(HTTP_STATUS.FORBIDDEN).json({
        success: false,
        message: `Access denied. This route requires ${allowedRoles.join(' or ')} role.`,
      });
    }

    next();
  };
};

/**
 * Consultant role middleware
 */
const isConsultant = (req, res, next) => {
  if (!req.user) {
    return res.status(HTTP_STATUS.UNAUTHORIZED).json({
      success: false,
      message: 'Authentication required.',
    });
  }

  if (req.user.accountType !== ACCOUNT_TYPES.CONSULTANT) {
    return res.status(HTTP_STATUS.FORBIDDEN).json({
      success: false,
      message: 'This route is accessible to consultants only.',
    });
  }

  next();
};

/**
 * User role middleware
 */
const isUser = (req, res, next) => {
  if (!req.user) {
    return res.status(HTTP_STATUS.UNAUTHORIZED).json({
      success: false,
      message: 'Authentication required.',
    });
  }

  if (req.user.accountType !== ACCOUNT_TYPES.USER) {
    return res.status(HTTP_STATUS.FORBIDDEN).json({
      success: false,
      message: 'This route is accessible to users only.',
    });
  }

  next();
};

/**
 * Admin role middleware
 */
const isAdmin = (req, res, next) => {
  if (!req.user) {
    return res.status(HTTP_STATUS.UNAUTHORIZED).json({
      success: false,
      message: 'Authentication required.',
    });
  }

  if (req.user.accountType !== ACCOUNT_TYPES.ADMIN) {
    return res.status(HTTP_STATUS.FORBIDDEN).json({
      success: false,
      message: 'This route is accessible to administrators only.',
    });
  }

  next();
};

/**
 * Marketplace role middleware
 */
const isMarketplace = (req, res, next) => {
  if (!req.user) {
    return res.status(HTTP_STATUS.UNAUTHORIZED).json({
      success: false,
      message: 'Authentication required.',
    });
  }

  if (req.user.accountType !== ACCOUNT_TYPES.MARKETPLACE) {
    return res.status(HTTP_STATUS.FORBIDDEN).json({
      success: false,
      message: 'This route is accessible to marketplace users only.',
    });
  }

  next();
};

/**
 * Optional authentication middleware
 * Attaches user to request if valid token exists, but doesn't require it
 * Also supports X-User-Id header for internal service calls
 */
const optionalAuth = async (req, res, next) => {
  try {
    // Check for internal service request with X-User-Id header
    const internalUserId = req.header('X-User-Id');
    const isInternalRequest = req.header('X-Internal-Request') === 'true';

    if (isInternalRequest && internalUserId) {
      req.user = { _id: internalUserId };
      return next();
    }

    const token = extractToken(req);

    if (token) {
      try {
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        req.user = decoded;
      } catch (err) {
        // Token is invalid but we continue anyway
        req.user = null;
      }
    } else {
      req.user = null;
    }

    next();
  } catch (error) {
    req.user = null;
    next();
  }
};

/**
 * Admin authentication middleware (combines auth + isAdmin)
 * Verifies JWT token and checks for admin role
 */
const adminAuth = async (req, res, next) => {
  try {
    const token = extractToken(req);

    if (!token) {
      return res.status(HTTP_STATUS.UNAUTHORIZED).json({
        success: false,
        message: 'Authentication required. Please provide a valid token.',
      });
    }

    try {
      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      req.user = decoded;

      // Check for admin role
      if (decoded.accountType !== ACCOUNT_TYPES.ADMIN) {
        return res.status(HTTP_STATUS.FORBIDDEN).json({
          success: false,
          message: 'This route is accessible to administrators only.',
        });
      }

      next();
    } catch (err) {
      if (err.name === 'TokenExpiredError') {
        return res.status(HTTP_STATUS.UNAUTHORIZED).json({
          success: false,
          message: 'Token has expired. Please login again.',
        });
      }

      return res.status(HTTP_STATUS.UNAUTHORIZED).json({
        success: false,
        message: 'Invalid token. Please login again.',
      });
    }
  } catch (error) {
    return res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({
      success: false,
      message: 'Authentication error. Please try again.',
    });
  }
};

/**
 * IoT service authentication middleware
 * Validates requests from IoT microservice using API key
 * Expected headers: X-API-Key, X-Service
 */
const iotServiceAuth = async (req, res, next) => {
  try {
    const apiKey = req.header('X-API-Key');
    const serviceName = req.header('X-Service');

    // Validate service identifier
    if (serviceName !== 'iot-service') {
      return res.status(HTTP_STATUS.FORBIDDEN).json({
        success: false,
        message: 'Invalid service identifier.',
      });
    }

    // Validate API key
    const expectedApiKey = process.env.IOT_SERVICE_API_KEY;
    if (!expectedApiKey) {
      console.error('IOT_SERVICE_API_KEY not configured');
      return res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({
        success: false,
        message: 'IoT service authentication not configured.',
      });
    }

    if (apiKey !== expectedApiKey) {
      return res.status(HTTP_STATUS.UNAUTHORIZED).json({
        success: false,
        message: 'Invalid API key.',
      });
    }

    // Mark request as from IoT service
    req.isIotService = true;
    next();
  } catch (error) {
    return res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({
      success: false,
      message: 'IoT service authentication error.',
    });
  }
};

/**
 * Internal service authentication middleware
 * Validates requests from other microservices
 */
const internalAuth = async (req, res, next) => {
  try {
    const isInternalRequest = req.header('X-Internal-Request') === 'true';

    if (!isInternalRequest) {
      return res.status(HTTP_STATUS.FORBIDDEN).json({
        success: false,
        message: 'This endpoint is for internal service use only.',
      });
    }

    // For internal requests, we trust the X-User-Id header
    const userId = req.header('X-User-Id') || req.body?.userId;
    if (userId) {
      req.user = { _id: userId };
    }

    next();
  } catch (error) {
    return res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({
      success: false,
      message: 'Internal authentication error.',
    });
  }
};

module.exports = {
  auth,
  authorize,
  isConsultant,
  isUser,
  isAdmin,
  isMarketplace,
  optionalAuth,
  internalAuth,
  adminAuth,
  iotServiceAuth,
};
