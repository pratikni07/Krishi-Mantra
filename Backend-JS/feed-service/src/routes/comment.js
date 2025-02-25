const express = require("express");
const router = express.Router();
const CommentController = require("../controller/commentController");

// Create a new comment
router.post("/create", CommentController.createComment);

// Get comments for a specific feed
router.get("/getComment", CommentController.getComments);

// Update a specific comment
router.put("/:commentId", CommentController.updateComment);

// Delete a comment
router.delete("/:commentId", CommentController.deleteComment);

// Report a comment
router.post("/:commentId/report", CommentController.reportComment);

module.exports = router;
