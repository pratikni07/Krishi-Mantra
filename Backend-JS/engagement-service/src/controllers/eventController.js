/**
 * Event Controller
 * Handles event tracking API endpoints
 */

const EventService = require('../services/eventService');
const SessionService = require('../services/sessionService');
const logger = require('../utils/logger');
const { HTTP_STATUS, ERROR_CODES } = require('../utils/constants');
const { sanitizeEvent } = require('../utils/eventSanitizer');

class EventController {
  /**
   * Track a single event
   * POST /api/engagement/events
   */
  static async trackEvent(req, res) {
    try {
      const { sessionId, eventName, eventCategory, properties, device, location } = req.body;
      // userId is derived from the gateway-injected `x-user-id` header.
      // Never trust a client-supplied userId — that would let any authed user
      // pollute another user's analytics.
      const userId = req.user.id;

      // Validate required fields
      if (!eventName) {
        return res.status(HTTP_STATUS.BAD_REQUEST).json({
          success: false,
          error: ERROR_CODES.VALIDATION_ERROR,
          message: 'eventName is required',
        });
      }

      // Get or create session
      let activeSessionId = sessionId;
      if (!activeSessionId) {
        const activeSession = await SessionService.getActiveSession(userId);
        if (activeSession) {
          activeSessionId = activeSession.sessionId;
        } else {
          // Start new session
          const newSession = await SessionService.startSession(userId, device);
          activeSessionId = newSession.sessionId;
        }
      }

      const eventData = {
        userId,
        sessionId: activeSessionId,
        eventName,
        eventCategory,
        properties: properties || {},
        device: device || {},
        location: location || {},
        timestamp: new Date(),
      };

      // Strip / reject events with PII or oversize properties.
      const sanitized = sanitizeEvent(eventData);
      if (!sanitized.ok) {
        logger.warn(`Rejecting event ${eventName} from user ${userId}: ${sanitized.reason}`);
        return res.status(HTTP_STATUS.BAD_REQUEST).json({
          success: false,
          error: ERROR_CODES.VALIDATION_ERROR,
          message: `Event rejected: ${sanitized.reason}`,
        });
      }

      // Queue event for async processing (high throughput)
      const result = await EventService.queueEvent(sanitized.event);

      // Track screen view in session if applicable
      if (eventName === 'screen_view' && properties?.screenName) {
        await SessionService.trackScreenView(
          activeSessionId,
          properties.screenName,
          properties.previousScreen
        );
      }

      return res.status(HTTP_STATUS.OK).json({
        success: true,
        sessionId: activeSessionId,
        queued: result.queued || false,
      });
    } catch (error) {
      logger.error('Error in trackEvent:', error.message);
      return res.status(HTTP_STATUS.INTERNAL_ERROR).json({
        success: false,
        error: ERROR_CODES.INTERNAL_ERROR,
        message: 'Failed to track event',
      });
    }
  }

  /**
   * Track multiple events (batch)
   * POST /api/engagement/events/batch
   */
  static async trackBatch(req, res) {
    try {
      const { events } = req.body;

      if (!Array.isArray(events) || events.length === 0) {
        return res.status(HTTP_STATUS.BAD_REQUEST).json({
          success: false,
          error: ERROR_CODES.VALIDATION_ERROR,
          message: 'events array is required',
        });
      }

      // Limit batch size
      if (events.length > 100) {
        return res.status(HTTP_STATUS.BAD_REQUEST).json({
          success: false,
          error: ERROR_CODES.VALIDATION_ERROR,
          message: 'Maximum batch size is 100 events',
        });
      }

      // Stamp the trusted userId onto every event in the batch. Whatever the
      // client put in `event.userId` is ignored — preventing cross-user
      // pollution from a single authed session.
      const trustedUserId = req.user.id;

      // Sanitize each event individually. A single bad event shouldn't
      // poison the whole batch; we accept the clean ones and report the
      // rejections so the caller can fix them.
      const accepted = [];
      const rejected = [];
      for (const raw of events) {
        const stamped = { ...raw, userId: trustedUserId };
        const result = sanitizeEvent(stamped);
        if (result.ok) {
          accepted.push(result.event);
        } else {
          rejected.push({ eventName: stamped.eventName, reason: result.reason });
        }
      }

      if (rejected.length > 0) {
        logger.warn(`Rejected ${rejected.length}/${events.length} events for user ${trustedUserId}`);
      }

      const result = accepted.length > 0
        ? await EventService.trackBatch(accepted)
        : { success: 0, failed: 0, errors: [] };

      return res.status(HTTP_STATUS.OK).json({
        success: true,
        processed: result.success,
        failed: result.failed,
        rejected: rejected.length,
        rejections: rejected.slice(0, 10),
        errors: result.errors?.slice(0, 10), // Limit error details
      });
    } catch (error) {
      logger.error('Error in trackBatch:', error.message);
      return res.status(HTTP_STATUS.INTERNAL_ERROR).json({
        success: false,
        error: ERROR_CODES.INTERNAL_ERROR,
        message: 'Failed to track batch',
      });
    }
  }

  /**
   * Start a new session
   * POST /api/engagement/sessions/start
   */
  static async startSession(req, res) {
    try {
      const { device } = req.body;
      const userId = req.user.id;

      // Check for existing active session
      const existingSession = await SessionService.getActiveSession(userId);
      if (existingSession) {
        // End existing session first
        await SessionService.endSession(existingSession.sessionId);
      }

      const session = await SessionService.startSession(userId, device || {});

      // Track app_open event
      await EventService.trackEvent({
        userId,
        sessionId: session.sessionId,
        eventName: 'app_open',
        eventCategory: 'navigation',
        device: device || {},
        timestamp: new Date(),
      });

      return res.status(HTTP_STATUS.CREATED).json({
        success: true,
        sessionId: session.sessionId,
        startTime: session.startTime,
      });
    } catch (error) {
      logger.error('Error in startSession:', error.message);
      return res.status(HTTP_STATUS.INTERNAL_ERROR).json({
        success: false,
        error: ERROR_CODES.INTERNAL_ERROR,
        message: 'Failed to start session',
      });
    }
  }

  /**
   * End a session
   * POST /api/engagement/sessions/end
   */
  static async endSession(req, res) {
    try {
      const { sessionId, exitScreen } = req.body;
      const userId = req.user.id;

      let targetSessionId = sessionId;

      // If no sessionId provided, look up the user's active session.
      if (!targetSessionId) {
        const activeSession = await SessionService.getActiveSession(userId);
        if (activeSession) {
          targetSessionId = activeSession.sessionId;
        }
      }

      if (!targetSessionId) {
        return res.status(HTTP_STATUS.BAD_REQUEST).json({
          success: false,
          error: ERROR_CODES.VALIDATION_ERROR,
          message: 'No active session found',
        });
      }

      // Track app_close event. Verify the session belongs to the caller —
      // a client passing an arbitrary sessionId shouldn't end someone else's
      // session.
      const session = await SessionService.getSession(targetSessionId);
      if (session && String(session.userId) !== String(userId)) {
        return res.status(HTTP_STATUS.FORBIDDEN).json({
          success: false,
          error: ERROR_CODES.FORBIDDEN || 'FORBIDDEN',
          message: 'Session does not belong to caller.',
        });
      }
      if (session) {
        await EventService.trackEvent({
          userId,
          sessionId: targetSessionId,
          eventName: 'app_close',
          eventCategory: 'navigation',
          properties: { exitScreen },
          timestamp: new Date(),
        });
      }

      const result = await SessionService.endSession(targetSessionId, { exitScreen });

      if (!result) {
        return res.status(HTTP_STATUS.NOT_FOUND).json({
          success: false,
          error: ERROR_CODES.INVALID_SESSION,
          message: 'Session not found',
        });
      }

      return res.status(HTTP_STATUS.OK).json({
        success: true,
        sessionId: result.sessionId,
        duration: result.duration,
        engagement: result.engagement,
      });
    } catch (error) {
      logger.error('Error in endSession:', error.message);
      return res.status(HTTP_STATUS.INTERNAL_ERROR).json({
        success: false,
        error: ERROR_CODES.INTERNAL_ERROR,
        message: 'Failed to end session',
      });
    }
  }

  /**
   * Get active session
   * GET /api/engagement/sessions/active/:userId
   */
  static async getActiveSession(req, res) {
    try {
      // The :userId URL param is preserved for backward compat but ignored
      // for trust purposes — we always use the authenticated caller.
      // Reject if a client tries to look at someone else's session.
      const paramUserId = req.params.userId;
      const userId = req.user.id;
      if (paramUserId && String(paramUserId) !== String(userId)) {
        return res.status(HTTP_STATUS.FORBIDDEN).json({
          success: false,
          error: ERROR_CODES.FORBIDDEN || 'FORBIDDEN',
          message: 'Cannot read another user\'s session.',
        });
      }

      const session = await SessionService.getActiveSession(userId);

      return res.status(HTTP_STATUS.OK).json({
        success: true,
        hasActiveSession: !!session,
        session,
      });
    } catch (error) {
      logger.error('Error in getActiveSession:', error.message);
      return res.status(HTTP_STATUS.INTERNAL_ERROR).json({
        success: false,
        error: ERROR_CODES.INTERNAL_ERROR,
        message: 'Failed to get active session',
      });
    }
  }

  /**
   * Get real-time stats
   * GET /api/engagement/stats/realtime
   */
  static async getRealTimeStats(req, res) {
    try {
      const stats = await EventService.getRealTimeStats();

      return res.status(HTTP_STATUS.OK).json({
        success: true,
        stats,
      });
    } catch (error) {
      logger.error('Error in getRealTimeStats:', error.message);
      return res.status(HTTP_STATUS.INTERNAL_ERROR).json({
        success: false,
        error: ERROR_CODES.INTERNAL_ERROR,
        message: 'Failed to get real-time stats',
      });
    }
  }

  /**
   * Internal: track an event submitted by another backend service.
   * Caller authenticates with X-Service-Token (see middlewares/auth.js).
   * userId comes from the body (the calling service has already authenticated
   * the end user it's attributing the event to).
   * POST /api/engagement/events/internal
   */
  static async trackEventInternal(req, res) {
    try {
      const { userId, sessionId, eventName, eventCategory, properties, device, location, timestamp } = req.body;

      if (!userId || !eventName) {
        return res.status(HTTP_STATUS.BAD_REQUEST).json({
          success: false,
          error: ERROR_CODES.VALIDATION_ERROR,
          message: 'userId and eventName are required',
        });
      }

      const eventData = {
        userId,
        sessionId: sessionId || null,
        eventName,
        eventCategory,
        properties: properties || {},
        device: device || {},
        location: location || {},
        timestamp: timestamp ? new Date(timestamp) : new Date(),
      };

      const sanitized = sanitizeEvent(eventData);
      if (!sanitized.ok) {
        logger.warn(`Rejecting internal event ${eventName} for user ${userId}: ${sanitized.reason}`);
        return res.status(HTTP_STATUS.BAD_REQUEST).json({
          success: false,
          error: ERROR_CODES.VALIDATION_ERROR,
          message: `Event rejected: ${sanitized.reason}`,
        });
      }

      const result = await EventService.queueEvent(sanitized.event);
      return res.status(HTTP_STATUS.OK).json({
        success: true,
        queued: result.queued || false,
      });
    } catch (error) {
      logger.error('Error in trackEventInternal:', error.message);
      return res.status(HTTP_STATUS.INTERNAL_ERROR).json({
        success: false,
        error: ERROR_CODES.INTERNAL_ERROR,
        message: 'Failed to track internal event',
      });
    }
  }

  /**
   * Internal: track multiple events submitted by another backend service.
   * POST /api/engagement/events/internal/batch
   */
  static async trackBatchInternal(req, res) {
    try {
      const { events } = req.body;

      if (!Array.isArray(events) || events.length === 0) {
        return res.status(HTTP_STATUS.BAD_REQUEST).json({
          success: false,
          error: ERROR_CODES.VALIDATION_ERROR,
          message: 'events array is required',
        });
      }
      if (events.length > 100) {
        return res.status(HTTP_STATUS.BAD_REQUEST).json({
          success: false,
          error: ERROR_CODES.VALIDATION_ERROR,
          message: 'Maximum batch size is 100 events',
        });
      }

      const accepted = [];
      const rejected = [];
      for (const raw of events) {
        if (!raw || !raw.userId || !raw.eventName) {
          rejected.push({ eventName: raw?.eventName, reason: 'missing userId or eventName' });
          continue;
        }
        const result = sanitizeEvent(raw);
        if (result.ok) accepted.push(result.event);
        else rejected.push({ eventName: raw.eventName, reason: result.reason });
      }

      if (rejected.length > 0) {
        logger.warn(`Rejected ${rejected.length}/${events.length} internal events`);
      }

      const result = accepted.length > 0
        ? await EventService.trackBatch(accepted)
        : { success: 0, failed: 0, errors: [] };

      return res.status(HTTP_STATUS.OK).json({
        success: true,
        processed: result.success,
        failed: result.failed,
        rejected: rejected.length,
        rejections: rejected.slice(0, 10),
      });
    } catch (error) {
      logger.error('Error in trackBatchInternal:', error.message);
      return res.status(HTTP_STATUS.INTERNAL_ERROR).json({
        success: false,
        error: ERROR_CODES.INTERNAL_ERROR,
        message: 'Failed to track internal batch',
      });
    }
  }

  /**
   * Heartbeat endpoint for keeping session alive
   * POST /api/engagement/sessions/heartbeat
   */
  static async heartbeat(req, res) {
    try {
      const { sessionId, currentScreen } = req.body;
      const userId = req.user.id;

      let targetSessionId = sessionId;

      if (!targetSessionId) {
        const activeSession = await SessionService.getActiveSession(userId);
        if (activeSession) {
          targetSessionId = activeSession.sessionId;
        }
      }

      if (!targetSessionId) {
        return res.status(HTTP_STATUS.BAD_REQUEST).json({
          success: false,
          error: ERROR_CODES.INVALID_SESSION,
          message: 'No active session found',
        });
      }

      // Update session lastActivity timestamp via the session service.
      // We deliberately do NOT write a `heartbeat` event row — that name
      // isn't in the event enum and was being silently rejected by Mongoose
      // anyway. Heartbeats keep the session alive; they aren't analytics.
      await SessionService.touchSession(targetSessionId, { currentScreen });

      return res.status(HTTP_STATUS.OK).json({
        success: true,
        sessionId: targetSessionId,
      });
    } catch (error) {
      logger.error('Error in heartbeat:', error.message);
      return res.status(HTTP_STATUS.INTERNAL_ERROR).json({
        success: false,
        error: ERROR_CODES.INTERNAL_ERROR,
        message: 'Failed to process heartbeat',
      });
    }
  }
}

module.exports = EventController;
