const redis = require('../config/redis');
const Notification = require('../models/notification.model');
const queueService = require('./queue.service');
const logger = require('../utils/logger');
const {
  CACHE_KEYS,
  CACHE_TTL,
  NOTIFICATION_PRIORITY,
  NOTIFICATION_STATUS,
  NOTIFICATION_TYPES,
} = require('../utils/constants');

class DigestService {
  _digestKey(userId, category) {
    return `${CACHE_KEYS.DIGEST}${userId}:${category}`;
  }

  async enqueue(notification) {
    const key = this._digestKey(notification.userId, notification.category);
    const payload = {
      title: notification.title,
      body: notification.body,
      data: notification.data,
      createdAt: new Date().toISOString(),
    };

    const existing = await redis.get(key);
    const parsed = existing ? JSON.parse(existing) : { items: [], meta: {} };

    parsed.items.push(payload);
    parsed.meta = {
      userId: notification.userId,
      category: notification.category,
      updatedAt: new Date().toISOString(),
    };

    await redis.setex(key, CACHE_TTL.DIGEST_WINDOW, JSON.stringify(parsed));
    return parsed.items.length;
  }

  async flushDigests(limit = 500) {
    const keys = await redis.keys(`${CACHE_KEYS.DIGEST}*`);
    const selected = keys.slice(0, limit);
    let flushed = 0;

    for (const key of selected) {
      try {
        const raw = await redis.get(key);
        if (!raw) continue;

        const digest = JSON.parse(raw);
        if (!digest.items || !digest.items.length) {
          await redis.del(key);
          continue;
        }

        const [userId, category] = key.replace(CACHE_KEYS.DIGEST, '').split(':');
        const title = `You have ${digest.items.length} new ${(category || 'activity').replace('_', ' ')} updates`;
        const body = digest.items.slice(0, 3).map((item) => item.body).join(' • ');

        const notification = await Notification.create({
          userId,
          type: NOTIFICATION_TYPES.IN_APP,
          title,
          body,
          category,
          priority: NOTIFICATION_PRIORITY.LOW,
          status: NOTIFICATION_STATUS.PENDING,
          data: {
            digest: true,
            count: digest.items.length,
            items: digest.items,
          },
        });

        await queueService.sendToNotificationQueue(notification);
        await redis.del(key);
        flushed += 1;
      } catch (error) {
        logger.error('Digest flush failed:', error.message);
      }
    }

    return flushed;
  }
}

module.exports = new DigestService();
