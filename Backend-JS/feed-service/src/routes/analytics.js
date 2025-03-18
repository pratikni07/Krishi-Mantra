const express = require("express");
const router = express.Router();
const analyticsController = require("../controller/analyticsController");

// Feed statistics endpoint
router.get("/stats", analyticsController.getFeedStats);

module.exports = router; 