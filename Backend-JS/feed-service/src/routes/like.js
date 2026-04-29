const express = require("express");
const router = express.Router();
const LikeController = require("../controller/likeController");
const { auth } = require("../middlewares/auth");

// Toggle Like (Create/Remove)
router.post("/toggle", auth, LikeController.toggleLike);

// Get Likes for a Specific Feed
router.get("/feed/:feedId", LikeController.getFeedLikes);

// Get User's Liked Feeds
router.get("/user/:userId", LikeController.getUserLikedFeeds);

module.exports = router;
