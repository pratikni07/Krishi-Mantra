/**
 * Routes Index
 * Combines all route modules
 */

const express = require('express');
const router = express.Router();

const eventRoutes = require('./eventRoutes');
const analyticsRoutes = require('./analyticsRoutes');

// Mount routes
router.use('/', eventRoutes);
router.use('/analytics', analyticsRoutes);

// Health check
router.get('/health', (req, res) => {
  res.status(200).json({
    success: true,
    service: 'engagement-service',
    status: 'healthy',
    timestamp: new Date().toISOString(),
  });
});

module.exports = router;
