// routes/reelRoutes.js
const express = require("express");
const ReelController = require("../controllers/reelController");
const VideoUploadController = require("../controllers/videoUploadController");
const { videoUpload, handleMulterError } = require("../middlewares/uploadMiddleware");
const { verifyMagicBytes } = require("../middlewares/verifyMagicBytes");
const { auth, optionalAuth } = require("../middlewares/auth");
const router = express.Router();

// ============ Video Upload Routes ============
// Check upload service status
router.get("/upload/status", VideoUploadController.checkStatus);

// Get signed upload URL for direct client upload
router.get("/upload/signature", auth, VideoUploadController.getUploadSignature);

// Finalize a direct-to-Cloudinary upload (preferred path). The client
// uploads bytes to Cloudinary via the signed signature and then POSTs
// the resulting publicId here — no video bytes flow through this server.
router.post("/upload/complete", auth, VideoUploadController.completeUpload);

// Legacy proxied upload — bytes stream through the server. Retained for
// backward compatibility until all clients migrate to /upload/complete.
router.post(
  "/upload",
  auth,
  videoUpload.single("video"),
  handleMulterError,
  verifyMagicBytes({ videos: true }),
  VideoUploadController.uploadReel
);

// Migrate single video to streaming format
router.post("/:id/migrate", auth, VideoUploadController.migrateVideo);

// Batch migrate videos to streaming format
router.post("/migrate-all", auth, VideoUploadController.migrateAllVideos);

// Delete reel with video cleanup
router.delete("/:id/video", auth, VideoUploadController.deleteReelVideo);

// ============ Public routes ============
router.get("/search", ReelController.searchReels);
router.get("/trending", ReelController.getTrendingReels);
router.get("/tags/trending", ReelController.getTrendingTags);
router.get("/tags/:tag", ReelController.getReelsByTag);

// Recommendation routes (must be before :id route)
router.get("/recommended/:userId", optionalAuth, ReelController.getRecommendedReels);
router.get("/interests/:userId", optionalAuth, ReelController.getUserInterests);
router.post("/interests/:userId/initialize", auth, ReelController.initializeUserInterests);
router.post("/interaction", auth, ReelController.recordInteraction);
router.post("/sync-tags", auth, ReelController.syncReelTags);

router.get("/user/:userId", ReelController.getUserReels);
router.get("/:id", ReelController.getReel);
router.get("/:reelId/comments", ReelController.getCommentByReelId);

router.get("/", ReelController.getReels);

router.post("/", auth, ReelController.createReel);
router.delete("/:id", auth, ReelController.deleteReel);
router.post("/:id/like", auth, ReelController.likeReel);
router.delete("/:id/like", auth, ReelController.unlikeReel);
router.post("/:id/comments", auth, ReelController.addComment);
router.delete("/comments/:commentId", auth, ReelController.deleteComment);

module.exports = router;
