/**
 * Event Routes
 * API endpoints for event tracking
 */

const express = require('express');
const router = express.Router();
const EventController = require('../controllers/eventController');

// Event tracking
router.post('/events', EventController.trackEvent);
router.post('/events/batch', EventController.trackBatch);

// Session management
router.post('/sessions/start', EventController.startSession);
router.post('/sessions/end', EventController.endSession);
router.get('/sessions/active/:userId', EventController.getActiveSession);
router.post('/sessions/heartbeat', EventController.heartbeat);

// Real-time stats
router.get('/stats/realtime', EventController.getRealTimeStats);

module.exports = router;
