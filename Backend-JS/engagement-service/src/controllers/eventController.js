/**
 * Event Controller
 * Handles event tracking API endpoints
 */

const EventService = require('../services/eventService');
const SessionService = require('../services/sessionService');
const logger = require('../utils/logger');
const { HTTP_STATUS, ERROR_CODES } = require('../utils/constants');
const { validateEventData } = require('../utils/helpers');

class EventController {
  /**
   * Track a single event
   * POST /api/engagement/events
   */
  static async trackEvent(req, res) {
    try {
      const { userId, sessionId, eventName, eventCategory, properties, device, location } = req.body;

      // Validate required fields
      if (!userId || !eventName) {
        return res.status(HTTP_STATUS.BAD_REQUEST).json({
          success: false,
          error: ERROR_CODES.VALIDATION_ERROR,
          message: 'userId and eventName are required',
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

      // Queue event for async processing (high throughput)
      const result = await EventService.queueEvent(eventData);

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

      const result = await EventService.trackBatch(events);

      return res.status(HTTP_STATUS.OK).json({
        success: true,
        processed: result.success,
        failed: result.failed,
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
      const { userId, device } = req.body;

      if (!userId) {
        return res.status(HTTP_STATUS.BAD_REQUEST).json({
          success: false,
          error: ERROR_CODES.VALIDATION_ERROR,
          message: 'userId is required',
        });
      }

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
      const { sessionId, userId, exitScreen } = req.body;

      let targetSessionId = sessionId;

      // If no sessionId provided, get active session for user
      if (!targetSessionId && userId) {
        const activeSession = await SessionService.getActiveSession(userId);
        if (activeSession) {
          targetSessionId = activeSession.sessionId;
        }
      }

      if (!targetSessionId) {
        return res.status(HTTP_STATUS.BAD_REQUEST).json({
          success: false,
          error: ERROR_CODES.VALIDATION_ERROR,
          message: 'sessionId or userId with active session is required',
        });
      }

      // Track app_close event
      const session = await SessionService.getSession(targetSessionId);
      if (session) {
        await EventService.trackEvent({
          userId: session.userId,
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
      const { userId } = req.params;

      if (!userId) {
        return res.status(HTTP_STATUS.BAD_REQUEST).json({
          success: false,
          error: ERROR_CODES.VALIDATION_ERROR,
          message: 'userId is required',
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
   * Heartbeat endpoint for keeping session alive
   * POST /api/engagement/sessions/heartbeat
   */
  static async heartbeat(req, res) {
    try {
      const { sessionId, userId, currentScreen } = req.body;

      let targetSessionId = sessionId;

      if (!targetSessionId && userId) {
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

      // Track heartbeat event
      await EventService.trackEvent({
        userId,
        sessionId: targetSessionId,
        eventName: 'heartbeat',
        eventCategory: 'system',
        properties: { currentScreen },
        timestamp: new Date(),
      });

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
