const express = require("express");
const router = express.Router();
const CommentController = require("../controller/commentController");
const { auth } = require("../middlewares/auth");

// Create a new comment
router.post("/create", auth, CommentController.createComment);

// Get comments for a specific feed
router.get("/getComment", CommentController.getComments);

// Update a specific comment
router.put("/:commentId", auth, CommentController.updateComment);

// Delete a comment
router.delete("/:commentId", auth, CommentController.deleteComment);

// Report a comment
router.post("/:commentId/report", auth, CommentController.reportComment);

module.exports = router;
