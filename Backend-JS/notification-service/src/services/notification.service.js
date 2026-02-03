const Notification = require('../models/notification.model');
const UserNotificationPreferences = require('../models/user.model');
const queueService = require('./queue.service');
const redis = require('../config/redis');
const logger = require('../utils/logger');
const { CACHE_TTL, CACHE_KEYS, PAGINATION } = require('../utils/constants');

/**
 * Notification Service
 * Handles notification CRUD operations with caching
 */
class NotificationService {
  /**
   * Create a single notification
   * @param {Object} data - Notification data
   * @returns {Promise<Object>} Created notification
   */
  async createNotification(data) {
    try {
      const notification = new Notification(data);
      await notification.save();

      // Send to queue for processing
      await queueService.sendToNotificationQueue(notification);

      // Invalidate user notifications cache
      await redis.del(`${CACHE_KEYS.USER_NOTIFICATIONS}${data.userId}`);

      return notification;
    } catch (error) {
      logger.error('Error creating notification:', error.message);
      throw error;
    }
  }

  /**
   * Create bulk notifications
   * @param {Array} notifications - Array of notification data
   * @returns {Promise<Array>} Created notifications
   */
  async createBulkNotifications(notifications) {
    try {
      const createdNotifications = await Notification.insertMany(notifications);

      // Send to batch processing
      await queueService.sendToBatchQueue(createdNotifications);

      // Invalidate caches for affected users
      const userIds = [...new Set(notifications.map((n) => n.userId))];
      await Promise.all(
        userIds.map((userId) => redis.del(`${CACHE_KEYS.USER_NOTIFICATIONS}${userId}`))
      );

      return createdNotifications;
    } catch (error) {
      logger.error('Error creating bulk notifications:', error.message);
      throw error;
    }
  }

  /**
   * Get notifications for a user with pagination
   * @param {string} userId - User ID
   * @param {number} limit - Number of items per page
   * @param {number} page - Page number
   * @returns {Promise<Object>} Notifications and pagination info
   */
  async getNotificationsForUser(userId, limit = PAGINATION.DEFAULT_LIMIT, page = PAGINATION.DEFAULT_PAGE) {
    try {
      // Enforce max limit
      const effectiveLimit = Math.min(limit, PAGINATION.MAX_LIMIT);
      const skip = (page - 1) * effectiveLimit;

      // Try to get from cache for first page
      if (page === 1) {
        const cacheKey = `${CACHE_KEYS.USER_NOTIFICATIONS}${userId}`;
        const cached = await redis.get(cacheKey);
        if (cached) {
          return JSON.parse(cached);
        }
      }

      const [notifications, total] = await Promise.all([
        Notification.find({ userId })
          .sort({ createdAt: -1 })
          .skip(skip)
          .limit(effectiveLimit)
          .lean(),
        Notification.countDocuments({ userId }),
      ]);

      const result = {
        notifications,
        pagination: {
          total,
          page,
          limit: effectiveLimit,
          pages: Math.ceil(total / effectiveLimit),
        },
      };

      // Cache first page results
      if (page === 1) {
        const cacheKey = `${CACHE_KEYS.USER_NOTIFICATIONS}${userId}`;
        await redis.setex(cacheKey, CACHE_TTL.NOTIFICATION, JSON.stringify(result));
      }

      return result;
    } catch (error) {
      logger.error('Error fetching user notifications:', error.message);
      throw error;
    }
  }

  /**
   * Get user notification preferences
   * @param {string} userId - User ID
   * @returns {Promise<Object>} User preferences
   */
  async getUserPreferences(userId) {
    try {
      const cacheKey = `${CACHE_KEYS.USER_PREFS}${userId}`;

      // Try cache first
      return await redis.getOrSet(cacheKey, CACHE_TTL.USER_PREFS, async () => {
        let preferences = await UserNotificationPreferences.findOne({ userId });

        if (!preferences) {
          preferences = await UserNotificationPreferences.create({ userId });
        }

        return preferences.toObject();
      });
    } catch (error) {
      logger.error('Error fetching user preferences:', error.message);
      throw error;
    }
  }

  /**
   * Update user notification preferences
   * @param {string} userId - User ID
   * @param {Object} preferences - New preferences
   * @returns {Promise<Object>} Updated preferences
   */
  async updateUserPreferences(userId, preferences) {
    try {
      const updatedPreferences = await UserNotificationPreferences.findOneAndUpdate(
        { userId },
        { ...preferences, updatedAt: new Date() },
        { new: true, upsert: true }
      );

      // Update cache
      const cacheKey = `${CACHE_KEYS.USER_PREFS}${userId}`;
      await redis.setex(cacheKey, CACHE_TTL.USER_PREFS, JSON.stringify(updatedPreferences));

      return updatedPreferences;
    } catch (error) {
      logger.error('Error updating user preferences:', error.message);
      throw error;
    }
  }

  /**
   * Mark notification as read
   * @param {string} notificationId - Notification ID
   * @param {string} userId - User ID
   * @returns {Promise<Object>} Updated notification
   */
  async markAsRead(notificationId, userId) {
    try {
      const notification = await Notification.markSeen(notificationId, userId);

      if (notification) {
        // Invalidate user notifications cache
        await redis.del(`${CACHE_KEYS.USER_NOTIFICATIONS}${userId}`);
      }

      return notification;
    } catch (error) {
      logger.error('Error marking notification as read:', error.message);
      throw error;
    }
  }

  /**
   * Mark multiple notifications as read
   * @param {string} userId - User ID
   * @param {Array<string>} notificationIds - Array of notification IDs
   * @returns {Promise<Object>} Update result
   */
  async markMultipleAsRead(userId, notificationIds) {
    try {
      const result = await Notification.markMultipleSeen(userId, notificationIds);

      // Invalidate user notifications cache
      await redis.del(`${CACHE_KEYS.USER_NOTIFICATIONS}${userId}`);

      return result;
    } catch (error) {
      logger.error('Error marking multiple notifications as read:', error.message);
      throw error;
    }
  }

  /**
   * Get unread notification count for user
   * @param {string} userId - User ID
   * @returns {Promise<number>} Unread count
   */
  async getUnreadCount(userId) {
    try {
      const cacheKey = `${CACHE_KEYS.UNREAD_COUNT}${userId}`;

      return await redis.getOrSet(cacheKey, CACHE_TTL.SHORT, async () => {
        return await Notification.countUnread(userId);
      });
    } catch (error) {
      logger.error('Error getting unread count:', error.message);
      throw error;
    }
  }
}

module.exports = new NotificationService();
