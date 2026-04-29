/**
 * Engagement Emitter
 *
 * Server-side helper for emitting analytics events to the engagement-service.
 * Use this when you need an event to be authoritative — i.e. you can't rely
 * on the frontend SDK because the user might lose connection, the app might
 * crash, or the event is business-critical.
 *
 * Auth: posts to engagement-service's /events/internal endpoint with the
 * X-Service-Token header. INTERNAL_SERVICE_SECRET must match on both sides.
 *
 * Failure mode: best-effort + non-blocking. Never let a failed analytics
 * emit break a user-facing flow.
 *
 * Identical helper exists in main-service/src/utils/engagementEmitter.js.
 * If you change one, change the other (Phase 8 of the observability plan
 * will replace this with a shared package).
 *
 * Implementation note: uses Node 18+ built-in fetch since this service
 * doesn't pull in axios.
 */

const logger = require('../utils/logger');

const ENGAGEMENT_TIMEOUT_MS = 3000;

const getEngagementBaseUrl = () => {
  const url = process.env.ENGAGEMENT_SERVICE_URL;
  if (!url) return null;
  return url.replace(/\/+$/, '');
};

const postJson = async (url, body, headers) => {
  const controller = new AbortController();
  const t = setTimeout(() => controller.abort(), ENGAGEMENT_TIMEOUT_MS);
  try {
    const res = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', ...headers },
      body: JSON.stringify(body),
      signal: controller.signal,
    });
    if (!res.ok) {
      throw new Error(`HTTP ${res.status}`);
    }
    return true;
  } finally {
    clearTimeout(t);
  }
};

const emit = async ({ userId, eventName, eventCategory, properties, sessionId, device, location, timestamp }) => {
  if (!userId || !eventName) {
    logger.warn(`engagementEmitter.emit: missing userId or eventName (userId=${userId}, eventName=${eventName})`);
    return false;
  }

  const baseUrl = getEngagementBaseUrl();
  const secret = process.env.INTERNAL_SERVICE_SECRET;
  if (!baseUrl || !secret) {
    logger.warn('engagementEmitter: ENGAGEMENT_SERVICE_URL or INTERNAL_SERVICE_SECRET not set; skipping emit');
    return false;
  }

  try {
    await postJson(
      `${baseUrl}/api/engagement/events/internal`,
      {
        userId,
        sessionId: sessionId || null,
        eventName,
        eventCategory,
        properties: properties || {},
        device: device || {},
        location: location || {},
        timestamp: timestamp || new Date().toISOString(),
      },
      { 'X-Service-Token': secret }
    );
    return true;
  } catch (err) {
    logger.warn(`engagementEmitter.emit failed (eventName=${eventName}, userId=${userId}): ${err.message}`);
    return false;
  }
};

const emitBatch = async (events) => {
  if (!Array.isArray(events) || events.length === 0) return false;

  const baseUrl = getEngagementBaseUrl();
  const secret = process.env.INTERNAL_SERVICE_SECRET;
  if (!baseUrl || !secret) {
    logger.warn('engagementEmitter: ENGAGEMENT_SERVICE_URL or INTERNAL_SERVICE_SECRET not set; skipping batch');
    return false;
  }

  try {
    await postJson(
      `${baseUrl}/api/engagement/events/internal/batch`,
      { events },
      { 'X-Service-Token': secret }
    );
    return true;
  } catch (err) {
    logger.warn(`engagementEmitter.emitBatch failed (count=${events.length}): ${err.message}`);
    return false;
  }
};

module.exports = { emit, emitBatch };
