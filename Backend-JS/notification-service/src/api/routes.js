const express = require('express');
const router = express.Router();
const notificationController = require('./controllers/notification.controller');
// const auth = require('../middlewares/auth');

// Notification routes
router.post('/notifications', notificationController.createNotification);
router.post('/notifications/bulk', notificationController.createBulkNotifications);
router.get('/users/:userId/notifications', notificationController.getUserNotifications);
router.patch('/users/:userId/notifications/:notificationId/read', notificationController.markAsRead);

// User preferences routes
router.get('/users/:userId/preferences', notificationController.getUserPreferences);
router.put('/users/:userId/preferences', notificationController.updateUserPreferences);

// Health check
router.get('/health', (req, res) => {
  res.status(200).json({
    status: 'ok',
    service: 'notification-service',
    timestamp: new Date().toISOString()
  });
});

module.exports = router; 