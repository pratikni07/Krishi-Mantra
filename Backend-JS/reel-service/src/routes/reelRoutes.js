// routes/reelRoutes.js
const express = require("express");
const ReelController = require("../controllers/reelController");
const VideoUploadController = require("../controllers/videoUploadController");
const { videoUpload, handleMulterError } = require("../middlewares/uploadMiddleware");
const { verifyMagicBytes } = require("../middlewares/verifyMagicBytes");
const router = express.Router();

// ============ Video Upload Routes ============
// Check upload service status
router.get("/upload/status", VideoUploadController.checkStatus);

// Get signed upload URL for direct client upload
router.get("/upload/signature", VideoUploadController.getUploadSignature);

// Finalize a direct-to-Cloudinary upload (preferred path). The client
// uploads bytes to Cloudinary via the signed signature and then POSTs
// the resulting publicId here — no video bytes flow through this server.
router.post("/upload/complete", VideoUploadController.completeUpload);

// Legacy proxied upload — bytes stream through the server. Retained for
// backward compatibility until all clients migrate to /upload/complete.
router.post(
  "/upload",
  videoUpload.single("video"),
  handleMulterError,
  verifyMagicBytes({ videos: true }),
  VideoUploadController.uploadReel
);

// Migrate single video to streaming format
router.post("/:id/migrate", VideoUploadController.migrateVideo);

// Batch migrate videos to streaming format
router.post("/migrate-all", VideoUploadController.migrateAllVideos);

// Delete reel with video cleanup
router.delete("/:id/video", VideoUploadController.deleteReelVideo);

// ============ Public routes ============
router.get("/search", ReelController.searchReels);
router.get("/trending", ReelController.getTrendingReels);
router.get("/tags/trending", ReelController.getTrendingTags);
router.get("/tags/:tag", ReelController.getReelsByTag);

// Recommendation routes (must be before :id route)
router.get("/recommended/:userId", ReelController.getRecommendedReels);
router.get("/interests/:userId", ReelController.getUserInterests);
router.post("/interests/:userId/initialize", ReelController.initializeUserInterests);
router.post("/interaction", ReelController.recordInteraction);
router.post("/sync-tags", ReelController.syncReelTags);

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
