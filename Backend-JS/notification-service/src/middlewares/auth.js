const jwt = require('jsonwebtoken');

// Defense-in-depth auth for notification-service. The gateway already
// verifies the JWT and forwards x-user-id, but if a pod in the same cluster
// is compromised it could set that header freely. Re-verify here so identity
// comes from the signed token, not the header.
const requireAuth = (req, res, next) => {
  const token = (req.headers.authorization || '').replace(/^Bearer\s+/i, '');
  if (!token) {
    return res.status(401).json({ error: 'No token provided' });
  }

  const secret = process.env.JWT_SECRET;
  if (!secret) {
    console.error('JWT_SECRET not configured in notification-service');
    return res.status(500).json({ error: 'Auth not configured' });
  }

  try {
    const decoded = jwt.verify(token, secret);
    req.user = {
      id: decoded._id || decoded.id || decoded.userId,
      accountType: decoded.accountType,
    };
    if (!req.user.id) {
      return res.status(401).json({ error: 'Token missing subject' });
    }
    next();
  } catch (err) {
    return res.status(401).json({
      error: err.name === 'TokenExpiredError' ? 'Token expired' : 'Invalid token',
    });
  }
};

// For routes shaped like /users/:userId/... — require the caller to be that
// user, or an admin. Prevents one user from muting another's notifications
// or enumerating someone else's preferences.
const requireSelfOrAdmin = (req, res, next) => {
  if (!req.user) return res.status(401).json({ error: 'Not authenticated' });
  const pathUserId = req.params.userId;
  if (req.user.accountType === 'admin') return next();
  if (pathUserId && String(pathUserId) === String(req.user.id)) return next();
  return res.status(403).json({ error: 'Cannot act on another user' });
};

// For cross-user routes (createNotification, bulk, events) — these are
// service-to-service or admin-only. Refuse regular users.
const requireAdminOrInternal = (req, res, next) => {
  if (!req.user) return res.status(401).json({ error: 'Not authenticated' });
  if (req.user.accountType === 'admin') return next();
  return res.status(403).json({ error: 'Admin or service access required' });
};

module.exports = { requireAuth, requireSelfOrAdmin, requireAdminOrInternal };
