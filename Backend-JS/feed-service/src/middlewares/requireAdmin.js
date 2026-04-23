// Admin gate for routes proxied by api-gateway. The gateway strips any
// client-supplied x-user-accounttype header before forwarding, then re-emits
// it from the verified JWT, so this header is trusted at this layer.
module.exports = function requireAdmin(req, res, next) {
  const accountType = req.header('x-user-accounttype');
  if (accountType !== 'admin') {
    return res.status(403).json({
      status: 'error',
      message: 'Admin access required.',
    });
  }
  next();
};
