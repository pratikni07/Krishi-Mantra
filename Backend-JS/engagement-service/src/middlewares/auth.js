/**
 * Engagement-Service Auth
 *
 * Engagement-service sits behind the api-gateway. The gateway:
 *   1. Strips any client-supplied `x-user-id` / `x-user-accounttype` headers.
 *   2. Verifies the JWT (Authorization: Bearer ...).
 *   3. Re-injects trusted `x-user-id` and `x-user-accounttype` headers on the
 *      proxied request.
 *
 * So the only safe source of truth for the calling user inside this service
 * is the `x-user-id` header. We REFUSE to read userId from the request body —
 * doing so would let any authenticated user pollute another user's analytics
 * by passing a different userId.
 *
 * Usage:
 *   const { requireAuthedUser, optionalAuthedUser, requireInternalService }
 *     = require('../middlewares/auth');
 *   router.post('/events', requireAuthedUser, EventController.trackEvent);
 *
 * After requireAuthedUser, `req.user = { id, accountType }` is guaranteed.
 */

const HTTP_STATUS = {
  UNAUTHORIZED: 401,
  FORBIDDEN: 403,
};

/**
 * Require the request to come from an authenticated end-user via the gateway.
 * Rejects with 401 if no `x-user-id` header is present.
 */
const requireAuthedUser = (req, res, next) => {
  const userId = req.header('x-user-id');
  if (!userId) {
    return res.status(HTTP_STATUS.UNAUTHORIZED).json({
      success: false,
      error: 'UNAUTHORIZED',
      message: 'Missing trusted user context. This endpoint must be called via the api-gateway.',
    });
  }

  req.user = {
    id: userId,
    accountType: req.header('x-user-accounttype') || 'user',
  };
  next();
};

/**
 * Like requireAuthedUser, but doesn't reject. Use for endpoints that work
 * for both authed users and internal services.
 */
const optionalAuthedUser = (req, res, next) => {
  const userId = req.header('x-user-id');
  if (userId) {
    req.user = {
      id: userId,
      accountType: req.header('x-user-accounttype') || 'user',
    };
  }
  next();
};

/**
 * Require an internal-service-to-service call. Used for events emitted by
 * other backend services (e.g. main-service emitting `subscription_purchase`
 * server-side). Validates the service token against
 * `process.env.INTERNAL_SERVICE_SECRET`.
 *
 * Sender side (other services) must pass `X-Service-Token: $secret` along
 * with the userId they want to attribute the event to in the body. Trust here
 * is service-to-service; userId in body is acceptable because the gateway
 * isn't in the path.
 */
const requireInternalService = (req, res, next) => {
  const secret = process.env.INTERNAL_SERVICE_SECRET;
  if (!secret) {
    // Fail closed: if the env isn't configured we refuse all internal
    // calls rather than accept everything.
    return res.status(HTTP_STATUS.FORBIDDEN).json({
      success: false,
      error: 'INTERNAL_AUTH_NOT_CONFIGURED',
      message: 'Server missing INTERNAL_SERVICE_SECRET; refusing internal request.',
    });
  }

  const provided = req.header('x-service-token');
  if (!provided || provided !== secret) {
    return res.status(HTTP_STATUS.FORBIDDEN).json({
      success: false,
      error: 'FORBIDDEN',
      message: 'Invalid or missing X-Service-Token.',
    });
  }

  // For internal calls, userId comes from the body (the calling service is
  // attributing the event to a specific user it has authenticated itself).
  req.internalCaller = true;
  next();
};

/**
 * Require admin account type. For analytics endpoints that expose data
 * across users (dashboards, leaderboards, per-user drill-down).
 */
const requireAdmin = (req, res, next) => {
  if (!req.user) {
    return res.status(HTTP_STATUS.UNAUTHORIZED).json({
      success: false,
      error: 'UNAUTHORIZED',
      message: 'Authentication required.',
    });
  }
  if (req.user.accountType !== 'admin') {
    return res.status(HTTP_STATUS.FORBIDDEN).json({
      success: false,
      error: 'FORBIDDEN',
      message: 'Admin access required.',
    });
  }
  next();
};

module.exports = {
  requireAuthedUser,
  optionalAuthedUser,
  requireInternalService,
  requireAdmin,
};
