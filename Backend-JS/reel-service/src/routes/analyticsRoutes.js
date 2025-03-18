const express = require("express");
const router = express.Router();
const analyticsController = require("../controllers/analyticsController");

// testing middleware
router.use((req, res, next) => {
    console.log("Request query:", req.query);
    next();
});

// Reel statistics endpoint
router.get("/stats", analyticsController.getReelStats);

module.exports = router; 