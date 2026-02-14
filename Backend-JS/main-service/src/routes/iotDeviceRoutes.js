/**
 * IoT Device Routes
 * Server-to-server API endpoints for IoT device validation and management
 * Used by the IoT Go service for handshake protocol and device lifecycle
 */

const express = require('express');
const router = express.Router();
const subscriptionController = require('../controller/SubscriptionController');
const { iotServiceAuth } = require('../middlewares/auth');

/**
 * Health Check
 * GET /health
 * Used by IoT service to verify main service availability
 */
router.get('/health', (req, res) => {
    res.status(200).json({
        success: true,
        message: 'IoT API is healthy',
        timestamp: new Date().toISOString(),
    });
});

/**
 * Device Validation Endpoints (require iotServiceAuth)
 */

// Validate device subscription during handshake
// POST /validate-subscription
router.post('/validate-subscription', iotServiceAuth, subscriptionController.validateDeviceSubscription);

// Get device subscription details
// GET /devices/:deviceId/subscription
router.get('/devices/:deviceId/subscription', iotServiceAuth, subscriptionController.getDeviceSubscriptionDetails);

// Update device online/offline status
// PUT /devices/:deviceId/status
router.put('/devices/:deviceId/status', iotServiceAuth, subscriptionController.updateDeviceStatus);

// Log device activity
// POST /devices/activity
router.post('/devices/activity', iotServiceAuth, subscriptionController.logDeviceActivity);

module.exports = router;
