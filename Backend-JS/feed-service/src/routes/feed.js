const express = require("express");
const router = express.Router();
const feedController = require("../controller/feedController");

// Debug middleware
const testingmiddleware = (req, res, next) => {
  console.log("[TESTING MIDDLEWARE] Request received for:", req.originalUrl);
  console.log("[TESTING MIDDLEWARE] Request query:", req.query);
  console.log("[TESTING MIDDLEWARE] Request body:", req.body);
  next();
};

// Static routes MUST come before parameterized routes to avoid conflicts
// Admin routes
router.get("/getAllFeedsAdmin", testingmiddleware, feedController.getAllFeedsForAdmin);

// Static routes
router.get("/getoptwo", feedController.getTopFeeds);
router.get("/feeds/random", feedController.getRandomFeeds);
router.get("/trending/hashtags", feedController.getTrendingHashtags);

// User interest and interaction routes (static paths - must be before :userId)
router.post("/user/interest", feedController.updateUserInterest);
router.post("/user/interaction", feedController.recordInteraction);
router.post("/user/sync-interests", feedController.syncInitialInterests);

// User routes with userId parameter
router.get("/user/:userId/stats", feedController.getUserStats);
router.get("/user/:userId/recommended", feedController.getRecommendedFeeds);

// Tag routes
router.get("/tag/:tagName/feeds", feedController.getFeedsByTag);

// Feed CRUD routes (parameterized routes at the end)
router.post("/", feedController.createFeed);
router.get("/:feedId", feedController.getFeed);
router.post("/:feedId/comment", feedController.addComment);
router.post("/:feedId/like", feedController.toggleLike);

module.exports = router;
