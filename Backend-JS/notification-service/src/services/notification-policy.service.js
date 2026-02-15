const redis = require('../config/redis');
const { CACHE_KEYS, CACHE_TTL, DEFAULT_CATEGORY_CAPS } = require('../utils/constants');

class NotificationPolicyService {
  _buildDedupeKey(notification) {
    const eventType = notification?.data?.eventType || 'generic';
    const entityId = notification?.data?.entityId || 'none';
    const actorId = notification?.data?.actorId || 'none';
    return `${notification.userId}:${eventType}:${entityId}:${actorId}`;
  }

  async isDuplicate(notification) {
    const dedupeKey = notification.dedupeKey || this._buildDedupeKey(notification);
    const cacheKey = `${CACHE_KEYS.DEDUPE}${dedupeKey}`;
    const existing = await redis.get(cacheKey);
    if (existing) {
      return true;
    }

    await redis.set(cacheKey, '1', 'EX', CACHE_TTL.DEDUPE);
    notification.dedupeKey = dedupeKey;
    return false;
  }

  async isRateLimited(notification, preferences = {}) {
    const category = notification.category || 'system';
    const caps = preferences.frequencyCaps || {};
    const customCap = caps[category] || (typeof caps.get === 'function' ? caps.get(category) : null);
    const defaultCap = DEFAULT_CATEGORY_CAPS[category] || { limit: 30, windowSeconds: 3600 };
    const cap = customCap || defaultCap;

    const key = `${CACHE_KEYS.RATE_LIMIT}${notification.userId}:${category}`;
    const counter = await redis.client.incr(key);
    if (counter === 1) {
      await redis.client.expire(key, cap.windowSeconds);
    }

    return counter > cap.limit;
  }

  isMuted(notification, preferences = {}) {
    const muted = preferences.muted || {};
    const entityId = notification?.data?.entityId;
    const actorId = notification?.data?.actorId;

    const categoryMuted = muted.categories?.includes(notification.category);
    const actorMuted = actorId && muted.actorIds?.includes(actorId);
    const entityMuted = entityId && muted.entityIds?.includes(entityId);

    return Boolean(categoryMuted || actorMuted || entityMuted);
  }
}

module.exports = new NotificationPolicyService();
