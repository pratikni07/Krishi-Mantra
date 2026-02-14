const nodemailer = require('nodemailer');
const Notification = require('../models/notification.model');
const UserNotificationPreferences = require('../models/user.model');
const pushService = require('../services/push.service');
const websocketService = require('../services/websocket.service');
const redisClient = require('../config/redis');
const logger = require('../utils/logger');
const { NOTIFICATION_STATUS } = require('../utils/constants');

const emailTransporter = nodemailer.createTransport({
  host: process.env.SMTP_HOST || 'smtp.example.com',
  port: parseInt(process.env.SMTP_PORT || '587', 10),
  secure: process.env.SMTP_SECURE === 'true',
  auth: {
    user: process.env.SMTP_USER || 'user@example.com',
    pass: process.env.SMTP_PASS || 'password',
  },
});

class NotificationProcessor {
  async processNotification(notification) {
    try {
      if (!notification || !notification.userId) {
        logger.error('Invalid notification received:', notification);
        return false;
      }

      const preferences = await this._getUserPreferences(notification.userId);

      if (!preferences.enabled) {
        await this._updateNotificationStatus(notification._id, NOTIFICATION_STATUS.SKIPPED, 'Notifications disabled by user');
        return true;
      }

      if (notification.category && preferences.categories?.[notification.category] === false) {
        await this._updateNotificationStatus(notification._id, NOTIFICATION_STATUS.SKIPPED, `Category ${notification.category} disabled by user`);
        return true;
      }

      if (this._isInQuietHours(preferences)) {
        const rescheduleTime = this._getTimeAfterQuietHours(preferences);
        await this._rescheduleNotification(notification._id, rescheduleTime);
        await this._updateNotificationStatus(notification._id, NOTIFICATION_STATUS.DEFERRED, 'Deferred due to quiet hours');
        return true;
      }

      const deliveryOrder = [notification.type, ...(notification.fallbackChannels || [])];
      const seenChannels = new Set();
      let deliveredChannel = null;

      for (const channel of deliveryOrder) {
        if (seenChannels.has(channel)) continue;
        seenChannels.add(channel);

        const result = await this._sendByChannel(channel, notification, preferences);
        if (result) {
          deliveredChannel = channel;
          break;
        }
      }

      if (deliveredChannel) {
        await this._markDeliverySuccess(notification._id, deliveredChannel);
        return true;
      }

      await this._updateNotificationStatus(notification._id, NOTIFICATION_STATUS.FAILED, 'Delivery failed across all channels');
      return false;
    } catch (error) {
      logger.error('Error processing notification:', error);
      await this._updateNotificationStatus(notification._id, NOTIFICATION_STATUS.FAILED, error.message);
      return false;
    }
  }

  async _sendByChannel(channel, notification, preferences) {
    switch (channel) {
      case 'push':
        return this._sendPushNotification(notification, preferences);
      case 'email':
        return this._sendEmailNotification(notification, preferences);
      case 'sms':
        return this._sendSmsNotification(notification, preferences);
      case 'in_app':
        return this._sendInAppNotification(notification);
      default:
        logger.warn(`Unknown notification type: ${channel}`);
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
    if (!preferences.channels?.push?.enabled || !preferences.channels?.push?.token) {
      return false;
    }

    try {
      const recipient = {
        userId: notification.userId,
        token: preferences.channels.push.token,
      };

      return await pushService.sendPush(notification, recipient);
    } catch (error) {
      logger.error('Error sending push notification:', error);
      return false;
    }
  }

  async _sendEmailNotification(notification, preferences) {
    if (!preferences.channels?.email?.enabled || !preferences.channels?.email?.address) {
      return false;
    }

    try {
      const info = await emailTransporter.sendMail({
        from: '"Farming App" <notifications@farmingapp.com>',
        to: preferences.channels.email.address,
        subject: notification.title,
        text: notification.body,
      });

      logger.debug(`Email sent: ${info.messageId}`);
      return true;
    } catch (error) {
      logger.error('Error sending email notification:', error);
      return false;
    }
  }

  async _sendSmsNotification(notification, preferences) {
    if (!preferences.channels?.sms?.enabled || !preferences.channels?.sms?.phoneNumber) {
      return false;
    }

    logger.debug(`Would send SMS to ${preferences.channels.sms.phoneNumber}: ${notification.title} - ${notification.body}`);
    return true;
  }

  async _sendInAppNotification(notification) {
    websocketService.sendNotification(notification.userId, {
      _id: notification._id,
      type: notification.type,
      title: notification.title,
      body: notification.body,
      category: notification.category,
      priority: notification.priority,
      data: notification.data,
      createdAt: notification.createdAt,
    });

    return true;
  }

  async _markDeliverySuccess(notificationId, channel) {
    await Notification.findByIdAndUpdate(notificationId, {
      status: NOTIFICATION_STATUS.DELIVERED,
      deliveredAt: new Date(),
      $push: { channelTrail: channel },
      updatedAt: new Date(),
    });
  }

  async _updateNotificationStatus(notificationId, status, message = null) {
    try {
      await Notification.findByIdAndUpdate(notificationId, {
        status,
        ...(message ? { 'data.statusMessage': message } : {}),
        updatedAt: new Date(),
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
        updatedAt: new Date(),
      });
      return true;
    } catch (error) {
      logger.error('Error rescheduling notification:', error);
      return false;
    }
  }

  _isInQuietHours(preferences) {
    if (!preferences.quietHours?.enabled) return false;

    const now = new Date();
    const currentTime = now.getHours() * 60 + now.getMinutes();

    const [startHour, startMinute] = preferences.quietHours.start.split(':').map(Number);
    const [endHour, endMinute] = preferences.quietHours.end.split(':').map(Number);

    const startTime = startHour * 60 + startMinute;
    const endTime = endHour * 60 + endMinute;

    if (startTime > endTime) {
      return currentTime >= startTime || currentTime <= endTime;
    }

    return currentTime >= startTime && currentTime <= endTime;
  }

  _getTimeAfterQuietHours(preferences) {
    const [endHour, endMinute] = preferences.quietHours.end.split(':').map(Number);

    const now = new Date();
    const afterQuietHours = new Date(now);
    afterQuietHours.setHours(endHour, endMinute, 0, 0);

    if (afterQuietHours < now) {
      afterQuietHours.setDate(afterQuietHours.getDate() + 1);
    }

    return afterQuietHours;
  }
}

module.exports = new NotificationProcessor();
