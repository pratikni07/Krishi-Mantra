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

// Start fresh with a clean route
router.get("/getAllFeedsAdmin", testingmiddleware, feedController.getAllFeedsForAdmin);

// Other routes
router.get("/getoptwo", feedController.getTopFeeds);
router.post("/", feedController.createFeed);
router.get("/:feedId", feedController.getFeed);
router.post("/:feedId/comment", feedController.addComment);
router.post("/:feedId/like", feedController.toggleLike);
router.get("/tag/:tagName/feeds", feedController.getFeedsByTag);
router.get("/feeds/random", feedController.getRandomFeeds);

// User interest and interaction routes
router.post("/user/interest", feedController.updateUserInterest);
router.post("/user/interaction", feedController.recordInteraction);

// Recommended feeds route
router.get("/user/:userId/recommended", feedController.getAllFeeds);

// Trending hashtags route
router.get("/trending/hashtags", feedController.getTrendingHashtags);

module.exports = router;
