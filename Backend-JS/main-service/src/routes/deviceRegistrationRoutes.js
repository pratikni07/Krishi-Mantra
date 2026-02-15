const express = require('express');
const router = express.Router();
const DeviceRegistrationController = require('../controller/DeviceRegistrationController');
const { authenticate, authorize } = require('../middlewares/auth');

/**
 * Public Routes
 */

// Create a new device registration
// POST /api/device-registration
router.post('/', DeviceRegistrationController.createRegistration);

/**
 * Admin Routes (require authentication and admin role)
 */

// Get all device registrations
// GET /api/device-registration/admin
router.get('/admin', authenticate, authorize('admin'), DeviceRegistrationController.getAllRegistrations);

// Get registration statistics
// GET /api/device-registration/admin/stats
router.get('/admin/stats', authenticate, authorize('admin'), DeviceRegistrationController.getStats);

// Get a single registration by ID
// GET /api/device-registration/admin/:id
router.get('/admin/:id', authenticate, authorize('admin'), DeviceRegistrationController.getRegistrationById);

// Reply to a registration and send notification
// PUT /api/device-registration/admin/:id/reply
router.put('/admin/:id/reply', authenticate, authorize('admin'), DeviceRegistrationController.replyToRegistration);

// Update registration status
// PATCH /api/device-registration/admin/:id/status
router.patch('/admin/:id/status', authenticate, authorize('admin'), DeviceRegistrationController.updateStatus);

// Delete a registration
// DELETE /api/device-registration/admin/:id
router.delete('/admin/:id', authenticate, authorize('admin'), DeviceRegistrationController.deleteRegistration);

module.exports = router;
