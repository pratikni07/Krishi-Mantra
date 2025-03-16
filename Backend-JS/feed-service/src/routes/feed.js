const express = require("express");
const router = express.Router();
const feedController = require("../controller/feedController");

// Existing routes
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

// New recommendation route
// router.get("/user/:userId/recommended", feedController.getRecommendedFeeds);
router.get("/user/:userId/recommended", feedController.getAllFeeds);

// New trending hashtags route
router.get("/trending/hashtags", feedController.getTrendingHashtags);

// get top feeds

module.exports = router;
