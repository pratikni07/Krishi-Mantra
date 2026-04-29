/**
 * Event Routes
 * API endpoints for event tracking
 *
 * All event-write routes require an authenticated user via the gateway.
 * The middleware reads the trusted `x-user-id` header that the gateway
 * injects after JWT verification. Client-supplied userIds in the body are
 * ignored (see eventController for details).
 */

const express = require('express');
const router = express.Router();
const EventController = require('../controllers/eventController');
const { requireAuthedUser, requireAdmin, requireInternalService } = require('../middlewares/auth');

// Event tracking — must be authenticated end users.
router.post('/events', requireAuthedUser, EventController.trackEvent);
router.post('/events/batch', requireAuthedUser, EventController.trackBatch);

// Internal: events emitted by other backend services. The caller passes
// X-Service-Token (validated against INTERNAL_SERVICE_SECRET) and supplies
// `userId` in the body to attribute the event to the end user. Used for
// server-authoritative events (subscription_purchase, consultant_chat_request,
// ai_message_send, etc.) where the frontend SDK is too lossy to be the only
// source.
router.post('/events/internal', requireInternalService, EventController.trackEventInternal);
router.post('/events/internal/batch', requireInternalService, EventController.trackBatchInternal);

// Session management — must be the same user who owns the session.
router.post('/sessions/start', requireAuthedUser, EventController.startSession);
router.post('/sessions/end', requireAuthedUser, EventController.endSession);
router.get('/sessions/active/:userId', requireAuthedUser, EventController.getActiveSession);
router.post('/sessions/heartbeat', requireAuthedUser, EventController.heartbeat);

// Real-time stats — admin-only because it exposes platform-wide counters.
router.get('/stats/realtime', requireAuthedUser, requireAdmin, EventController.getRealTimeStats);

module.exports = router;
