// routes/reelRoutes.js
const express = require("express");
const ReelController = require("../controllers/reelController");
const router = express.Router();

// Public routes
router.get("/search", ReelController.searchReels);
router.get("/trending", ReelController.getTrendingReels);
router.get("/tags/trending", ReelController.getTrendingTags);
router.get("/tags/:tag", ReelController.getReelsByTag);
router.get("/user/:userId", ReelController.getUserReels);
router.get("/:id", ReelController.getReel);
router.get("/:reelId/comments", ReelController.getCommentByReelId);

router.get("/", ReelController.getReels);

router.post("/", ReelController.createReel);
router.delete("/:id", ReelController.deleteReel);
router.post("/:id/like", ReelController.likeReel);
router.delete("/:id/like", ReelController.unlikeReel);
router.post("/:id/comments", ReelController.addComment);
router.delete("/comments/:commentId", ReelController.deleteComment);

module.exports = router;
