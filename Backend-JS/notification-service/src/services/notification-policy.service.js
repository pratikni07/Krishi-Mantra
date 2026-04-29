const redis = require('../config/redis');
const logger = require('../utils/logger');
const { CACHE_KEYS, CACHE_TTL, DEFAULT_CATEGORY_CAPS } = require('../utils/constants');

class NotificationPolicyService {
  _buildDedupeKey(notification) {
    const eventType = notification?.data?.eventType || 'generic';
    const entityId = notification?.data?.entityId || 'none';
    const actorId = notification?.data?.actorId || 'none';
    return `${notification.userId}:${eventType}:${entityId}:${actorId}`;
  }

  /**
   * Atomic check-and-set: returns true iff the dedupe key already exists.
   * The previous version did `GET` then `SET` separately, so two concurrent
   * dispatches could both observe "not present" and both fall through —
   * the dedupe wasn't actually deduping under load. `SET ... NX EX`
   * collapses both into a single round trip with the right semantics.
   */
  async isDuplicate(notification) {
    const dedupeKey = notification.dedupeKey || this._buildDedupeKey(notification);
    const cacheKey = `${CACHE_KEYS.DEDUPE}${dedupeKey}`;
    notification.dedupeKey = dedupeKey;

    try {
      const result = await redis.client.set(cacheKey, '1', 'EX', CACHE_TTL.DEDUPE, 'NX');
      // ioredis returns 'OK' on insert, null on collision.
      if (result === null || result === undefined) {
        return true;
      }
      return false;
    } catch (e) {
      logger.warn(`isDuplicate redis error (${e.message}); treating as not-duplicate`);
      return false;
    }
  }

  /**
   * Per-user/category rate limit with atomic INCR + EXPIRE.
   *
   * The naive `incr; if (counter === 1) expire(...)` pattern races: if the
   * process crashes between INCR and EXPIRE, the key sticks without a TTL
   * and the user is locked out indefinitely. A pipeline (multi/exec) makes
   * the pair atomic so either both apply or neither does.
   *
   * On Redis errors we fall through to "not rate-limited" — better to send
   * a duplicate than to silently swallow every notification during an
   * outage.
   */
  async isRateLimited(notification, preferences = {}) {
    const category = notification.category || 'system';
    const caps = preferences.frequencyCaps || {};
    const customCap = caps[category] || (typeof caps.get === 'function' ? caps.get(category) : null);
    const defaultCap = DEFAULT_CATEGORY_CAPS[category] || { limit: 30, windowSeconds: 3600 };
    const cap = customCap || defaultCap;

    const key = `${CACHE_KEYS.RATE_LIMIT}${notification.userId}:${category}`;

    try {
      // pipeline → single round-trip, atomic relative to other clients.
      const results = await redis.client
        .multi()
        .incr(key)
        .expire(key, cap.windowSeconds, 'NX')
        .exec();

      // ioredis: results = [[err, val], [err, val]]
      const incrEntry = Array.isArray(results) ? results[0] : null;
      const counter = incrEntry && Array.isArray(incrEntry) ? Number(incrEntry[1]) : NaN;
      if (Number.isNaN(counter)) {
        return false;
      }
      return counter > cap.limit;
    } catch (e) {
      logger.warn(`isRateLimited redis error (${e.message}); allowing send`);
      return false;
    }
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
