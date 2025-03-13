const Notification = require('../models/notification.model');
const UserNotificationPreferences = require('../models/user.model');
const queueService = require('./queue.service');
const redisClient = require('../config/redis');
const logger = require('../utils/logger');

class NotificationService {
  async createNotification(data) {
    try {
      // Create notification record
      const notification = new Notification(data);
      await notification.save();
      
      // Send to appropriate queue for processing
      await queueService.sendToNotificationQueue(notification);
      
      return notification;
    } catch (error) {
      logger.error('Error creating notification:', error);
      throw error;
    }
  }

  async createBulkNotifications(notifications) {
    try {
      // Insert all notifications
      const createdNotifications = await Notification.insertMany(notifications);
      
      // Send to batch processing
      await queueService.sendToBatchQueue(createdNotifications);
      
      return createdNotifications;
    } catch (error) {
      logger.error('Error creating bulk notifications:', error);
      throw error;
    }
  }

  async getNotificationsForUser(userId, limit = 20, page = 1) {
    try {
      const skip = (page - 1) * limit;
      
      const notifications = await Notification.find({ userId })
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit);
      
      const total = await Notification.countDocuments({ userId });
      
      return {
        notifications,
        pagination: {
          total,
          page,
          limit,
          pages: Math.ceil(total / limit)
        }
      };
    } catch (error) {
      logger.error('Error fetching user notifications:', error);
      throw error;
    }
  }

  async getUserPreferences(userId) {
    try {
      // Try to get from cache first
      const cacheKey = `user_prefs:${userId}`;
      const cachedPrefs = await redisClient.get(cacheKey);
      
      if (cachedPrefs) {
        return JSON.parse(cachedPrefs);
      }
      
      // Get from database if not in cache
      let preferences = await UserNotificationPreferences.findOne({ userId });
      
      // If no preferences exist, create default ones
      if (!preferences) {
        preferences = await UserNotificationPreferences.create({ userId });
      }
      
      // Cache the preferences
      await redisClient.set(cacheKey, JSON.stringify(preferences), 'EX', 3600); // 1 hour
      
      return preferences;
    } catch (error) {
      logger.error('Error fetching user preferences:', error);
      throw error;
    }
  }

  async updateUserPreferences(userId, preferences) {
    try {
      const updatedPreferences = await UserNotificationPreferences.findOneAndUpdate(
        { userId },
        { ...preferences, updatedAt: new Date() },
        { new: true, upsert: true }
      );
      
      // Update cache
      const cacheKey = `user_prefs:${userId}`;
      await redisClient.set(cacheKey, JSON.stringify(updatedPreferences), 'EX', 3600);
      
      return updatedPreferences;
    } catch (error) {
      logger.error('Error updating user preferences:', error);
      throw error;
    }
  }

  async markAsRead(notificationId, userId) {
    try {
      const notification = await Notification.findOneAndUpdate(
        { _id: notificationId, userId },
        { status: 'delivered', updatedAt: new Date() },
        { new: true }
      );
      
      return notification;
    } catch (error) {
      logger.error('Error marking notification as read:', error);
      throw error;
    }
  }
}

module.exports = new NotificationService(); 