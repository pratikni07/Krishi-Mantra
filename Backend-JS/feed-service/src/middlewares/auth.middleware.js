const axios = require('axios');
const Redis = require('../config/redis');
const { logger } = require('../utils/logger');

/**
 * Authentication middleware that validates user tokens via headers from API Gateway
 * or directly validates tokens in standalone mode
 */
const authMiddleware = async (req, res, next) => {
  try {
    // Get user ID from header (set by API Gateway)
    const userId = req.headers['x-user-id'];
    const userRole = req.headers['x-user-role'];
    const token = req.headers.authorization?.split(' ')[1];

    // If we have user ID from API Gateway, we can trust it
    if (userId) {
      // Check if user exists in cache
      const cachedUser = await Redis.get(`user:${userId}`);
      
      if (cachedUser) {
        req.user = JSON.parse(cachedUser);
      } else {
        // Create basic user object from headers
        req.user = { 
          id: userId,
          accountType: userRole || 'user'
        };
        
        // Cache for future requests
        await Redis.set(`user:${userId}`, JSON.stringify(req.user), 3600);
      }
      
      next();
      return;
    }
    
    // No userId in header but we have a token - validate directly with main service
    // This is used when feed service is accessed directly without going through API Gateway
    if (token) {
      try {
        // Check if token is blacklisted
        const isBlacklisted = await Redis.get(`bl_${token}`);
        if (isBlacklisted) {
          return res.status(401).json({ error: 'Token has been revoked' });
        }
        
        // Validate token with main service
        const mainServiceUrl = process.env.MAIN_SERVICE_URL || 'http://localhost:3002';
        const response = await axios.get(`${mainServiceUrl}/auth/validate-token`, {
          headers: {
            'Authorization': `Bearer ${token}`
          }
        });
        
        if (response.data.success) {
          req.user = response.data.user;
          
          // Cache user for future requests
          await Redis.set(`user:${req.user.id}`, JSON.stringify(req.user), 3600);
          
          next();
          return;
        }
      } catch (error) {
        logger.error('Token validation error:', error.message);
        return res.status(401).json({ error: 'Invalid or expired token' });
      }
    }
    
    // If we reach here, we don't have authentication
    // Check if the route is public or needs authentication
    const publicRoutes = ['/health', '/feeds/public', '/feeds/featured'];
    const isPublicRoute = publicRoutes.some(route => req.path.startsWith(route));
    
    if (isPublicRoute) {
      // Allow access to public routes
      next();
    } else {
      // Require authentication for all other routes
      return res.status(401).json({ error: 'Authentication required' });
    }
  } catch (error) {
    logger.error('Auth middleware error:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
};

/**
 * Role-based access control middleware
 * @param {Array<String>} allowedRoles - Array of role names that are allowed
 */
const roleCheck = (allowedRoles) => {
  return (req, res, next) => {
    try {
      // Public endpoints don't need role checking
      if (!req.user) {
        return res.status(401).json({ error: 'Authentication required' });
      }
      
      const userRole = req.user.accountType || 'user';
      
      if (allowedRoles.includes(userRole)) {
        next();
      } else {
        logger.warn(`Role check failed: User ${req.user.id} with role ${userRole} tried to access ${req.method} ${req.path}`);
        return res.status(403).json({ error: 'Insufficient permissions' });
      }
    } catch (error) {
      logger.error('Role check error:', error);
      return res.status(500).json({ error: 'Internal server error' });
    }
  };
};

module.exports = {
  auth: authMiddleware,
  isAdmin: roleCheck(['admin']),
  isUser: roleCheck(['user', 'admin']),
  isConsultant: roleCheck(['consultant', 'admin']),
  isMarketplace: roleCheck(['marketplace', 'admin']),
  hasAnyRole: (roles) => roleCheck(roles)
}; 