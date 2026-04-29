/**
 * Engagement Emitter
 *
 * Server-side helper for emitting analytics events to the engagement-service.
 * Identical surface to the main-service / message-svc copies. Fires events
 * via POST /api/engagement/events/internal with X-Service-Token auth.
 *
 * Failure mode: best-effort + non-blocking. Never let a failed analytics
 * emit break a user-facing flow.
 *
 * Phase 8 of the observability plan replaces these duplicated copies with
 * a shared package. Until then, keep the four copies in sync — the file is
 * intentionally byte-identical across services.
 */

const axios = require('axios');
const logger = require('./logger');

const ENGAGEMENT_TIMEOUT_MS = 3000;

const getEngagementBaseUrl = () => {
  const url = process.env.ENGAGEMENT_SERVICE_URL;
  if (!url) return null;
  return url.replace(/\/+$/, '');
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
    await axios.post(
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
      {
        timeout: ENGAGEMENT_TIMEOUT_MS,
        headers: { 'X-Service-Token': secret },
      }
    );
    return true;
  } catch (err) {
    logger.warn(
      `engagementEmitter.emit failed (eventName=${eventName}, userId=${userId}): ${err.response?.status || ''} ${err.message}`
    );
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
    await axios.post(
      `${baseUrl}/api/engagement/events/internal/batch`,
      { events },
      {
        timeout: ENGAGEMENT_TIMEOUT_MS,
        headers: { 'X-Service-Token': secret },
      }
    );
    return true;
  } catch (err) {
    logger.warn(
      `engagementEmitter.emitBatch failed (count=${events.length}): ${err.response?.status || ''} ${err.message}`
    );
    return false;
  }
};

module.exports = { emit, emitBatch };
