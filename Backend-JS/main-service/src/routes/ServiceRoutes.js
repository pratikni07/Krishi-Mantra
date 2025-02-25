// routes/serviceRoutes.js
const express = require('express');
const router = express.Router();
const serviceController = require('../controller/ServiceController');

// Create a new service
router.post('/', serviceController.createService);

// Get all services (with pagination)
router.get('/', serviceController.getAllServices);

// Get a specific service by ID
router.get('/:id', serviceController.getServiceById);

// Update a service
router.put('/:id', serviceController.updateService);

// Delete a service
router.delete('/:id', serviceController.deleteService);

module.exports = router;