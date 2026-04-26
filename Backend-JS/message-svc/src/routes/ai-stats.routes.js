const express = require('express');
const router = express.Router();
const authMiddleware = require('../middlewares/auth.middleware');
const StatsController = require('../controllers/ai-stats.controller');

// Admin-only — auth middleware re-verifies JWT; admin role is enforced at the
// gateway via accountType, but we double-check here.
router.use(authMiddleware, (req, res, next) => {
  const role = req.user?.accountType || req.user?.role;
  if (role !== 'admin') {
    return res.status(403).json({ error: 'Admin access required' });
  }
  next();
});

router.get('/summary', StatsController.summary);
router.get('/models', StatsController.modelBreakdown);

module.exports = router;
