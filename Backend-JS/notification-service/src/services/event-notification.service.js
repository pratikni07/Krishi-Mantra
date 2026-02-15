const Notification = require('../models/notification.model');
const UserNotificationPreferences = require('../models/user.model');
const queueService = require('./queue.service');
const eventTemplateService = require('./event-template.service');
const notificationPolicyService = require('./notification-policy.service');
const digestService = require('./digest.service');
const logger = require('../utils/logger');
const { NOTIFICATION_DELIVERY_MODE } = require('../utils/constants');

class EventNotificationService {
  async handleEvent(event) {
    if (!event || !event.type) {
      throw new Error('Invalid event payload. `type` is required.');
    }

    const template = eventTemplateService.getTemplate(event.type);
    if (!template) {
      throw new Error(`Unsupported notification event type: ${event.type}`);
    }

    const recipientIds = await this._resolveRecipients(event, template);
    if (!recipientIds.length) {
      logger.info(`No recipients found for event ${event.type}`);
      return { processed: 0, reason: 'NO_RECIPIENTS' };
    }

    const preferences = await UserNotificationPreferences.find({
      userId: { $in: recipientIds },
      enabled: true,
    }).lean();

    const preferenceByUser = new Map(preferences.map((pref) => [pref.userId, pref]));
    const notifications = [];
    let digestQueued = 0;

    for (const userId of recipientIds) {
      const userPreferences = preferenceByUser.get(userId);
      if (!userPreferences) continue;

      const category = event.category || template.category;
      if (category && userPreferences.categories?.[category] === false) {
        continue;
      }

      if (!eventTemplateService.isInterestMatch(userPreferences, event)) {
        continue;
      }

      const notification = eventTemplateService.buildNotificationFromEvent(
        event,
        userId,
        userPreferences.locale || 'en'
      );

      if (notificationPolicyService.isMuted(notification, userPreferences)) {
        continue;
      }

      if (await notificationPolicyService.isDuplicate(notification)) {
        continue;
      }

      if (await notificationPolicyService.isRateLimited(notification, userPreferences)) {
        continue;
      }

      const deliveryMode = this._resolveDeliveryMode(userPreferences, notification.category);
      if (deliveryMode === NOTIFICATION_DELIVERY_MODE.DIGEST && notification.priority !== 'high') {
        await digestService.enqueue(notification);
        digestQueued += 1;
        continue;
      }

      notifications.push(notification);
    }

    if (!notifications.length && !digestQueued) {
      return { processed: 0, reason: 'FILTERED_OUT' };
    }

    let created = [];
    if (notifications.length) {
      created = await Notification.insertMany(notifications);
      await queueService.sendToBatchQueue(created);
      logger.info(`Generated ${created.length} instant notifications for event ${event.type}`);
    }

    return { processed: created.length, digestQueued, reason: 'OK' };
  }

  _resolveDeliveryMode(preferences, category) {
    const categoryMode = preferences?.delivery?.categoryModes?.[category];
    return categoryMode || preferences?.delivery?.defaultMode || NOTIFICATION_DELIVERY_MODE.INSTANT;
  }

  async _resolveRecipients(event, template) {
    if (Array.isArray(event.recipientIds) && event.recipientIds.length) {
      return [...new Set(event.recipientIds.filter(Boolean))];
    }

    const category = event.category || template.category;

    if (!category) {
      return [];
    }

    const safeLimit = Number.isFinite(event.recipientLimit)
      ? Math.max(1, Math.min(event.recipientLimit, 10000))
      : 5000;

    const users = await UserNotificationPreferences.getUsersForCategory(category, safeLimit);
    return users.map((user) => user.userId);
  }
}

module.exports = new EventNotificationService();
