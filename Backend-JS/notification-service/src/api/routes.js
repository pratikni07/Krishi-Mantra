const express = require('express');
const router = express.Router();
const notificationController = require('./controllers/notification.controller');
const {
  requireAuth,
  requireSelfOrAdmin,
  requireAdminOrInternal,
} = require('../middlewares/auth');

// Health check stays unauthenticated so k8s probes can reach it.
router.get('/health', (req, res) => {
  res.status(200).json({
    status: 'ok',
    service: 'notification-service',
    timestamp: new Date().toISOString(),
  });
});

// All other routes require a valid bearer token.
router.use(requireAuth);

// Publishing notifications is an admin/service action.
router.post('/notifications', requireAdminOrInternal, notificationController.createNotification);
router.post('/notifications/bulk', requireAdminOrInternal, notificationController.createBulkNotifications);
router.post('/events', requireAdminOrInternal, notificationController.processDomainEvent);

// Per-user routes: caller must be that user (or an admin).
router.get('/users/:userId/notifications', requireSelfOrAdmin, notificationController.getUserNotifications);
router.patch('/users/:userId/notifications/:notificationId/read', requireSelfOrAdmin, notificationController.markAsRead);
router.patch('/users/:userId/notifications/:notificationId/interaction', requireSelfOrAdmin, notificationController.trackInteraction);

router.get('/users/:userId/preferences', requireSelfOrAdmin, notificationController.getUserPreferences);
router.put('/users/:userId/preferences', requireSelfOrAdmin, notificationController.updateUserPreferences);
router.patch('/users/:userId/preferences/mute', requireSelfOrAdmin, notificationController.mute);
router.patch('/users/:userId/preferences/unmute', requireSelfOrAdmin, notificationController.unmute);
router.post('/users/:userId/notifications/test', requireSelfOrAdmin, notificationController.sendTestNotification);

module.exports = router;
