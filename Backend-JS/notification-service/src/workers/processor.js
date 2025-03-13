const nodemailer = require('nodemailer');
const Notification = require('../models/notification.model');
const UserNotificationPreferences = require('../models/user.model');
const pushService = require('../services/push.service');
const redisClient = require('../config/redis');
const logger = require('../utils/logger');

// Simple email transporter - replace with your SMTP settings
const emailTransporter = nodemailer.createTransport({
  host: process.env.SMTP_HOST || 'smtp.example.com',
  port: parseInt(process.env.SMTP_PORT || '587'),
  secure: process.env.SMTP_SECURE === 'true',
  auth: {
    user: process.env.SMTP_USER || 'user@example.com',
    pass: process.env.SMTP_PASS || 'password'
  }
});

class NotificationProcessor {
  async processNotification(notification) {
    try {
      // Check if this is a valid notification
      if (!notification || !notification.userId) {
        logger.error('Invalid notification received:', notification);
        return false;
      }
      
      // Get user preferences
      const preferences = await this._getUserPreferences(notification.userId);
      
      // Skip if notifications are disabled globally for this user
      if (!preferences.enabled) {
        await this._updateNotificationStatus(notification._id, 'skipped', 'Notifications disabled by user');
        return true;
      }
      
      // Skip if this category is disabled
      if (notification.category && !preferences.categories[notification.category]) {
        await this._updateNotificationStatus(notification._id, 'skipped', `Category ${notification.category} disabled by user`);
        return true;
      }
      
      // Skip if in quiet hours
      if (this._isInQuietHours(preferences)) {
        // Reschedule for after quiet hours
        const rescheduleTime = this._getTimeAfterQuietHours(preferences);
        await this._rescheduleNotification(notification._id, rescheduleTime);
        return true;
      }
      
      // Process based on notification type
      let result = false;
      switch (notification.type) {
        case 'push':
          result = await this._sendPushNotification(notification, preferences);
          break;
        case 'email':
          result = await this._sendEmailNotification(notification, preferences);
          break;
        case 'sms':
          result = await this._sendSmsNotification(notification, preferences);
          break;
        case 'in_app':
          result = await this._sendInAppNotification(notification);
          break;
        default:
          logger.warn(`Unknown notification type: ${notification.type}`);
          result = false;
      }
      
      // Update notification status based on result
      if (result) {
        await this._updateNotificationStatus(notification._id, 'delivered');
      } else {
        await this._updateNotificationStatus(notification._id, 'failed', 'Delivery failed');
      }
      
      return result;
    } catch (error) {
      logger.error('Error processing notification:', error);
      await this._updateNotificationStatus(notification._id, 'failed', error.message);
      return false;
    }
  }

  async _getUserPreferences(userId) {
    const cacheKey = `user_prefs:${userId}`;
    const cachedPrefs = await redisClient.get(cacheKey);
    
    if (cachedPrefs) {
      return JSON.parse(cachedPrefs);
    }
    
    let preferences = await UserNotificationPreferences.findOne({ userId });
    
    if (!preferences) {
      preferences = await UserNotificationPreferences.create({ userId });
    }
    
    await redisClient.set(cacheKey, JSON.stringify(preferences), 'EX', 3600);
    
    return preferences;
  }

  async _sendPushNotification(notification, preferences) {
    if (!preferences.channels.push.enabled || !preferences.channels.push.token) {
      logger.debug(`Push notifications disabled for user ${notification.userId}`);
      return false;
    }
    
    try {
      // Prepare recipient data
      const recipient = {
        userId: notification.userId,
        token: preferences.channels.push.token
      };
      
      // Use the custom push service
      const result = await pushService.sendPush(notification, recipient);
      
      if (result) {
        logger.debug(`Successfully sent push notification to user ${notification.userId}`);
      }
      
      return result;
    } catch (error) {
      logger.error('Error sending push notification:', error);
      return false;
    }
  }

  async _sendEmailNotification(notification, preferences) {
    if (!preferences.channels.email.enabled || !preferences.channels.email.address) {
      logger.debug(`Email notifications disabled for user ${notification.userId}`);
      return false;
    }
    
    try {
      const info = await emailTransporter.sendMail({
        from: '"Farming App" <notifications@farmingapp.com>',
        to: preferences.channels.email.address,
        subject: notification.title,
        text: notification.body,
        html: `<div style="font-family: Arial, sans-serif; max-width: 600px;">
                <h2>${notification.title}</h2>
                <p>${notification.body}</p>
                ${notification.data.actionUrl ? 
                  `<p><a href="${notification.data.actionUrl}" style="background-color: #4CAF50; color: white; padding: 10px 15px; text-decoration: none; border-radius: 4px;">View Details</a></p>` : 
                  ''}
                <p style="color: #666; font-size: 12px;">You received this email because you're subscribed to ${notification.category} notifications.</p>
              </div>`
      });
      
      logger.debug(`Email sent: ${info.messageId}`);
      return true;
    } catch (error) {
      logger.error('Error sending email notification:', error);
      return false;
    }
  }

  async _sendSmsNotification(notification, preferences) {
    if (!preferences.channels.sms.enabled || !preferences.channels.sms.phoneNumber) {
      logger.debug(`SMS notifications disabled for user ${notification.userId}`);
      return false;
    }
    
    // This is a placeholder. In a real application, you would integrate with an SMS provider
    // like Twilio, Nexmo, AWS SNS, etc.
    logger.debug(`Would send SMS to ${preferences.channels.sms.phoneNumber}: ${notification.title} - ${notification.body}`);
    return true;
  }

  async _sendInAppNotification(notification) {
    // In-app notifications are just stored in the database and retrieved by the client
    // No additional action needed here as the notification is already stored
    logger.debug(`In-app notification ready for user ${notification.userId}`);
    return true;
  }

  async _updateNotificationStatus(notificationId, status, message = null) {
    try {
      await Notification.findByIdAndUpdate(notificationId, {
        status,
        ...(message ? { 'data.statusMessage': message } : {}),
        updatedAt: new Date()
      });
      return true;
    } catch (error) {
      logger.error('Error updating notification status:', error);
      return false;
    }
  }

  async _rescheduleNotification(notificationId, scheduledFor) {
    try {
      await Notification.findByIdAndUpdate(notificationId, {
        scheduledFor,
        updatedAt: new Date()
      });
      return true;
    } catch (error) {
      logger.error('Error rescheduling notification:', error);
      return false;
    }
  }

  _isInQuietHours(preferences) {
    if (!preferences.quietHours.enabled) return false;
    
    const now = new Date();
    const currentHour = now.getHours();
    const currentMinute = now.getMinutes();
    
    const [startHour, startMinute] = preferences.quietHours.start.split(':').map(Number);
    const [endHour, endMinute] = preferences.quietHours.end.split(':').map(Number);
    
    const currentTime = currentHour * 60 + currentMinute;
    const startTime = startHour * 60 + startMinute;
    const endTime = endHour * 60 + endMinute;
    
    // Handle case where quiet hours cross midnight
    if (startTime > endTime) {
      return currentTime >= startTime || currentTime <= endTime;
    } else {
      return currentTime >= startTime && currentTime <= endTime;
    }
  }

  _getTimeAfterQuietHours(preferences) {
    const [endHour, endMinute] = preferences.quietHours.end.split(':').map(Number);
    
    const now = new Date();
    const afterQuietHours = new Date(now);
    
    afterQuietHours.setHours(endHour, endMinute, 0, 0);
    
    // If after quiet hours is earlier than now, add a day
    if (afterQuietHours < now) {
      afterQuietHours.setDate(afterQuietHours.getDate() + 1);
    }
    
    return afterQuietHours;
  }
}

module.exports = new NotificationProcessor(); 