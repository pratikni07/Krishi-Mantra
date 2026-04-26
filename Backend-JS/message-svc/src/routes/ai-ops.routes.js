const express = require('express');
const router = express.Router();
const authMiddleware = require('../middlewares/auth.middleware');
const OpsController = require('../controllers/ai-ops.controller');

router.use(authMiddleware, (req, res, next) => {
  const role = req.user?.accountType || req.user?.role;
  if (role !== 'admin') {
    return res.status(403).json({ error: 'Admin access required' });
  }
  next();
});

router.get('/killswitch', OpsController.killswitchStatus);
router.put('/killswitch/:target', OpsController.setKillswitch);

router.get('/shadow/logs', OpsController.shadowLogs);
router.get('/shadow/summary', OpsController.shadowSummary);

module.exports = router;
