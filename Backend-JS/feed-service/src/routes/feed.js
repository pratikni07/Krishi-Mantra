const express = require("express");
const router = express.Router();
const feedController = require("../controller/feedController");
const validate = require("../middlewares/validate");
const requireAdmin = require("../middlewares/requireAdmin");
const { auth } = require("../middlewares/auth");
const feedSchemas = require("../schemas/feed");

// Debug middleware
const testingmiddleware = (req, res, next) => {
  console.log("[TESTING MIDDLEWARE] Request received for:", req.originalUrl);
  console.log("[TESTING MIDDLEWARE] Request query:", req.query);
  console.log("[TESTING MIDDLEWARE] Request body:", req.body);
  next();
};

// Static routes MUST come before parameterized routes to avoid conflicts
// Admin routes
router.get("/getAllFeedsAdmin", requireAdmin, testingmiddleware, feedController.getAllFeedsForAdmin);

// Static routes
router.get("/getoptwo", feedController.getTopFeeds);
router.get("/random", feedController.getRandomFeeds);
router.get("/trending/hashtags", feedController.getTrendingHashtags);

// User interest and interaction routes (static paths - must be before :userId)
router.post("/user/interest", auth, feedController.updateUserInterest);
router.post("/user/interaction", auth, feedController.recordInteraction);
router.post("/user/sync-interests", auth, feedController.syncInitialInterests);

// User routes with userId parameter
router.get("/user/:userId/stats", feedController.getUserStats);
router.get("/user/:userId/recommended", feedController.getRecommendedFeeds);

// Tag routes
router.get("/tag/:tagName/feeds", feedController.getFeedsByTag);

// Feed CRUD routes (parameterized routes at the end)
router.post(
  "/",
  auth,
  validate({ body: feedSchemas.createFeed }),
  feedController.createFeed
);
router.get("/:feedId", feedController.getFeed);
router.post(
  "/:feedId/comment",
  auth,
  validate({ params: feedSchemas.addCommentParams, body: feedSchemas.addCommentBody }),
  feedController.addComment
);
router.post(
  "/:feedId/like",
  auth,
  validate({ params: feedSchemas.toggleLikeParams, body: feedSchemas.toggleLikeBody }),
  feedController.toggleLike
);

module.exports = router;
