const express = require("express");
const router = express.Router();
const AnalyticsController = require("../controller/AnalyticsController");
// const { auth } = require("../middleware/auth"); // Assuming you have an auth middleware

// Dashboard statistics 
router.get("/dashboard-stats", AnalyticsController.getDashboardStats);

// Geolocation data
router.get("/geo-data", AnalyticsController.getGeoLocationData);

module.exports = router; 