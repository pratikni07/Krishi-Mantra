const express = require("express");
const VideoTutorialController = require("../controllers/videoTutorialController");
const router = express.Router();

// Public routes
router.get("/search", VideoTutorialController.searchVideos);
router.get("/", VideoTutorialController.getVideos);
router.get("/:id", VideoTutorialController.getVideo);
router.get("/:id/related", VideoTutorialController.getRelatedVideos);

// Protected routes (add authentication middleware as needed)
router.post("/", VideoTutorialController.createVideo);
router.put("/:id", VideoTutorialController.updateVideo);
router.delete("/:id", VideoTutorialController.deleteVideo);
router.post("/:id/report", VideoTutorialController.reportVideo);
router.post("/:id/like", VideoTutorialController.toggleLike);

// Comment routes
router.get("/:videoId/comments", VideoTutorialController.getComments);
router.post("/:videoId/comments", VideoTutorialController.addComment);
router.delete("/comments/:commentId", VideoTutorialController.deleteComment);
router.post("/comments/:commentId/like", VideoTutorialController.toggleCommentLike);

module.exports = router; 