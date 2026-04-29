const notificationService = require('../../services/notification.service');
const logger = require('../../utils/logger');
const eventNotificationService = require('../../services/event-notification.service');
const Notification = require('../../models/notification.model');
const UserPrefs = require('../../models/user.model');

exports.createNotification = async (req, res) => {
  try {
    const notification = await notificationService.createNotification(req.body);
    res.status(201).json({ success: true, data: notification });
  } catch (error) {
    logger.error('Controller error - createNotification:', error);
    res.status(500).json({ success: false, message: 'Failed to create notification', error: error.message });
  }
};

exports.createBulkNotifications = async (req, res) => {
  try {
    if (!Array.isArray(req.body.notifications)) {
      return res.status(400).json({ success: false, message: 'Notifications must be an array' });
    }

    const notifications = await notificationService.createBulkNotifications(req.body.notifications);
    res.status(201).json({
      success: true,
      count: notifications.length,
      message: `Successfully queued ${notifications.length} notifications`,
    });
  } catch (error) {
    logger.error('Controller error - createBulkNotifications:', error);
    res.status(500).json({ success: false, message: 'Failed to create bulk notifications', error: error.message });
  }
};

exports.getUserNotifications = async (req, res) => {
  try {
    const { userId } = req.params;
    const limit = parseInt(req.query.limit, 10) || 20;
    const page = parseInt(req.query.page, 10) || 1;

    const result = await notificationService.getNotificationsForUser(userId, limit, page);
    res.status(200).json({ success: true, data: result.notifications, pagination: result.pagination });
  } catch (error) {
    logger.error('Controller error - getUserNotifications:', error);
    res.status(500).json({ success: false, message: 'Failed to fetch user notifications', error: error.message });
  }
};

exports.getUserPreferences = async (req, res) => {
  try {
    const { userId } = req.params;
    const preferences = await notificationService.getUserPreferences(userId);
    res.status(200).json({ success: true, data: preferences });
  } catch (error) {
    logger.error('Controller error - getUserPreferences:', error);
    res.status(500).json({ success: false, message: 'Failed to fetch user preferences', error: error.message });
  }
};

exports.updateUserPreferences = async (req, res) => {
  try {
    const { userId } = req.params;
    const preferences = await notificationService.updateUserPreferences(userId, req.body);
    res.status(200).json({ success: true, data: preferences });
  } catch (error) {
    logger.error('Controller error - updateUserPreferences:', error);
    res.status(500).json({ success: false, message: 'Failed to update user preferences', error: error.message });
  }
};

exports.markAsRead = async (req, res) => {
  try {
    const { userId, notificationId } = req.params;
    const notification = await notificationService.markAsRead(notificationId, userId);

    if (!notification) {
      return res.status(404).json({ success: false, message: 'Notification not found' });
    }

    res.status(200).json({ success: true, data: notification });
  } catch (error) {
    logger.error('Controller error - markAsRead:', error);
    res.status(500).json({ success: false, message: 'Failed to mark notification as read', error: error.message });
  }
};

exports.processDomainEvent = async (req, res) => {
  try {
    const result = await eventNotificationService.handleEvent(req.body);
    res.status(202).json({ success: true, data: result });
  } catch (error) {
    logger.error('Controller error - processDomainEvent:', error);
    res.status(400).json({ success: false, message: 'Failed to process domain event', error: error.message });
  }
};

exports.mute = async (req, res) => {
  try {
    const { userId } = req.params;
    const data = await notificationService.muteEntities(userId, req.body || {});
    res.status(200).json({ success: true, data });
  } catch (error) {
    logger.error('Controller error - mute:', error);
    res.status(500).json({ success: false, message: 'Failed to mute notification sources', error: error.message });
  }
};

exports.unmute = async (req, res) => {
  try {
    const { userId } = req.params;
    const data = await notificationService.unmuteEntities(userId, req.body || {});
    res.status(200).json({ success: true, data });
  } catch (error) {
    logger.error('Controller error - unmute:', error);
    res.status(500).json({ success: false, message: 'Failed to unmute notification sources', error: error.message });
  }
};

exports.trackInteraction = async (req, res) => {
  try {
    const { userId, notificationId } = req.params;
    const action = req.body?.action || 'clicked';
    const data = await notificationService.trackNotificationInteraction(notificationId, userId, action);

    if (!data) {
      return res.status(404).json({ success: false, message: 'Notification not found' });
    }

    res.status(200).json({ success: true, data });
  } catch (error) {
    logger.error('Controller error - trackInteraction:', error);
    res.status(500).json({ success: false, message: 'Failed to track interaction', error: error.message });
  }
};

exports.sendTestNotification = async (req, res) => {
  try {
    const { userId } = req.params;
    const notification = await notificationService.sendTestNotification(userId, req.body || {});
    res.status(201).json({ success: true, data: notification });
  } catch (error) {
    logger.error('Controller error - sendTestNotification:', error);
    res.status(500).json({ success: false, message: 'Failed to send test notification', error: error.message });
  }
};

/**
 * Register or rotate a device's FCM/APNs token.
 *
 * Mobile clients call this on first launch (after notification permission
 * is granted) and on every cold start so we always have the latest token —
 * FCM rotates tokens after app updates, restore-from-backup, and "clear
 * data" actions, and a stale token silently drops every push for that
 * device. The endpoint is idempotent: re-registering the same token is
 * a no-op write.
 */
exports.registerPushToken = async (req, res) => {
  try {
    const { userId } = req.params;
    const { token, platform } = req.body || {};

    if (!token || typeof token !== 'string') {
      return res.status(400).json({
        success: false,
        message: 'token is required',
      });
    }
    if (!['android', 'ios', 'web'].includes(platform)) {
      return res.status(400).json({
        success: false,
        message: 'platform must be one of android, ios, web',
      });
    }

    const updated = await UserPrefs.updatePushToken(userId, token, platform);
    return res.status(200).json({ success: true, data: updated });
  } catch (error) {
    logger.error('Controller error - registerPushToken:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to register push token',
      error: error.message,
    });
  }
};

/**
 * Clear the registered push token (sign-out, "do not disturb").
 * The mobile client calls this on logout so a re-login on the same device
 * doesn't deliver pre-logout pushes to the next user.
 */
exports.unregisterPushToken = async (req, res) => {
  try {
    const { userId } = req.params;
    await UserPrefs.updateOne(
      { userId },
      {
        $set: {
          'channels.push.token': null,
          'channels.push.platform': null,
          'channels.push.enabled': false,
        },
      }
    );
    return res.status(200).json({ success: true });
  } catch (error) {
    logger.error('Controller error - unregisterPushToken:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to unregister push token',
      error: error.message,
    });
  }
};

/**
 * Mark every unread notification as read in one call. The previous flow
 * required the client to PATCH each id individually, which fanned out
 * to N writes for the unread badge to clear — slow over flaky networks
 * and a per-tap source of dropped writes.
 */
exports.markAllAsRead = async (req, res) => {
  try {
    const { userId } = req.params;
    const result = await Notification.updateMany(
      { userId, seenAt: null },
      { $set: { seenAt: new Date(), status: 'read' } }
    );
    return res.status(200).json({
      success: true,
      data: { modified: result.modifiedCount || 0 },
    });
  } catch (error) {
    logger.error('Controller error - markAllAsRead:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to mark notifications as read',
      error: error.message,
    });
  }
};

/**
 * Cheap unread-count probe for the badge. Used by the mobile client to
 * keep the bell icon's red dot in sync without re-fetching the full list.
 */
exports.getUnreadCount = async (req, res) => {
  try {
    const { userId } = req.params;
    const count = await Notification.countUnread(userId);
    return res.status(200).json({ success: true, data: { unread: count } });
  } catch (error) {
    logger.error('Controller error - getUnreadCount:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch unread count',
      error: error.message,
    });
  }
};
