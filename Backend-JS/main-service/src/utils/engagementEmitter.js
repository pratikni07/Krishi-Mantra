/**
 * Engagement Emitter
 *
 * Server-side helper for emitting analytics events to the engagement-service.
 * Use this when you need an event to be authoritative — i.e. you can't rely
 * on the frontend SDK because the user might lose connection, the app might
 * crash, or the event is business-critical (revenue, consultant requests).
 *
 * Auth: posts to engagement-service's /events/internal endpoint with the
 * X-Service-Token header. INTERNAL_SERVICE_SECRET must match on both sides
 * or every emit will be rejected with 403.
 *
 * Failure mode: best-effort + non-blocking. If the call fails for any
 * reason, we log and move on — never let a failed analytics emit break a
 * user-facing flow.
 *
 * Identical helper exists in message-svc/src/utils/engagementEmitter.js.
 * If you change one, change the other (Phase 8 of the observability plan
 * will replace this with a shared package).
 */

const axios = require('axios');
const logger = require('../utils/logger');

const ENGAGEMENT_TIMEOUT_MS = 3000;

const getEngagementBaseUrl = () => {
  const url = process.env.ENGAGEMENT_SERVICE_URL;
  if (!url) return null;
  return url.replace(/\/+$/, '');
};

/**
 * Emit a single event. Fire-and-forget by default — returns a promise but
 * callers shouldn't await it on hot paths.
 *
 *   await engagementEmitter.emit({
 *     userId: user._id.toString(),
 *     eventName: 'subscription_purchase',
 *     eventCategory: 'commerce',
 *     properties: {
 *       planName: 'pro',
 *       billingCycle: 'monthly',
 *       amount: paymentIntent.amount,
 *       currency: paymentIntent.currency,
 *     },
 *   });
 */
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
    // Never let an analytics failure break user flow. Log and move on.
    logger.warn(
      `engagementEmitter.emit failed (eventName=${eventName}, userId=${userId}): ${err.response?.status || ''} ${err.message}`
    );
    return false;
  }
};

/**
 * Emit a batch of events. Same contract as emit() but takes an array.
 * Useful for fan-out scenarios (one user action → several events).
 */
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
