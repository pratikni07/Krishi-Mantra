const express = require('express');
const router = express.Router();
const notificationController = require('./controllers/notification.controller');

router.post('/notifications', notificationController.createNotification);
router.post('/notifications/bulk', notificationController.createBulkNotifications);
router.post('/events', notificationController.processDomainEvent);
router.get('/users/:userId/notifications', notificationController.getUserNotifications);
router.patch('/users/:userId/notifications/:notificationId/read', notificationController.markAsRead);
router.patch('/users/:userId/notifications/:notificationId/interaction', notificationController.trackInteraction);

router.get('/users/:userId/preferences', notificationController.getUserPreferences);
router.put('/users/:userId/preferences', notificationController.updateUserPreferences);
router.patch('/users/:userId/preferences/mute', notificationController.mute);
router.patch('/users/:userId/preferences/unmute', notificationController.unmute);
router.post('/users/:userId/notifications/test', notificationController.sendTestNotification);

router.get('/health', (req, res) => {
  res.status(200).json({
    status: 'ok',
    service: 'notification-service',
    timestamp: new Date().toISOString(),
  });
});

module.exports = router;
