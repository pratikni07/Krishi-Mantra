/**
 * Main-Service Client
 *
 * Thin client for message-svc to make narrow lookups against main-service.
 * Currently exposes only `getAccountType(userId)` for consultant-detection
 * in chat-create. Add more methods sparingly — prefer event-driven sync
 * over chatty cross-service reads.
 *
 * Caches results in Redis for 60 s. Account types rarely change; freshness
 * cost is acceptable.
 *
 * Auth: posts X-Service-Token (INTERNAL_SERVICE_SECRET). Falls back to
 * `null` on any error — callers must handle missing values gracefully
 * since this never blocks user-facing flow.
 */

const redis = require('../config/redis');
const logger = require('../utils/logger');

const TIMEOUT_MS = 2500;
const CACHE_TTL_SEC = 60;

const getMainServiceUrl = () => {
  const url = process.env.MAIN_SERVICE_URL;
  return url ? url.replace(/\/+$/, '') : null;
};

/**
 * Look up the account type for a userId via main-service.
 * Returns one of 'user' | 'consultant' | 'admin' | 'marketplace' | null.
 * Result cached in Redis for 60 s.
 */
const getAccountType = async (userId) => {
  if (!userId) return null;

  const cacheKey = `accountType:${userId}`;
  try {
    const cached = await redis.get(cacheKey);
    if (cached) return cached;
  } catch (_) {
    // Cache miss path is tolerated; just call upstream.
  }

  const baseUrl = getMainServiceUrl();
  const secret = process.env.INTERNAL_SERVICE_SECRET;
  if (!baseUrl || !secret) {
    logger.warn('mainServiceClient: MAIN_SERVICE_URL or INTERNAL_SERVICE_SECRET not set');
    return null;
  }

  const controller = new AbortController();
  const t = setTimeout(() => controller.abort(), TIMEOUT_MS);
  try {
    const res = await fetch(`${baseUrl}/user/internal/${userId}/account-type`, {
      method: 'GET',
      headers: { 'X-Service-Token': secret },
      signal: controller.signal,
    });
    if (!res.ok) {
      logger.warn(`mainServiceClient.getAccountType ${userId}: HTTP ${res.status}`);
      return null;
    }
    const body = await res.json();
    const type = body?.accountType || null;
    if (type) {
      try {
        await redis.setex(cacheKey, CACHE_TTL_SEC, type);
      } catch (_) {}
    }
    return type;
  } catch (err) {
    logger.warn(`mainServiceClient.getAccountType ${userId} failed: ${err.message}`);
    return null;
  } finally {
    clearTimeout(t);
  }
};

module.exports = { getAccountType };
