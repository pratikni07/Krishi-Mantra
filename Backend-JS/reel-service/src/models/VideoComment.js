const mongoose = require("mongoose");

const VideoCommentSchema = new mongoose.Schema(
  {
    videoId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "VideoTutorial",
      required: true,
    },
    userId: {
      type: String,
      required: true,
    },
    userName: {
      type: String,
      required: true,
    },
    profilePhoto: {
      type: String,
    },
    content: {
      type: String,
      required: true,
      trim: true,
      maxLength: 1000,
    },
    likes: {
      count: {
        type: Number,
        default: 0,
      },
      users: [{
        type: String, // userId
      }]
    },
    parentComment: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "VideoComment",
      default: null,
    },
    replies: [{
      type: mongoose.Schema.Types.ObjectId,
      ref: "VideoComment",
    }],
    depth: {
      type: Number,
      default: 0,
    },
    isDeleted: {
      type: Boolean,
      default: false,
    },
  },
  {
    timestamps: true,
  }
);

// Indexes
VideoCommentSchema.index({ videoId: 1, createdAt: -1 });
VideoCommentSchema.index({ parentComment: 1, createdAt: -1 });

module.exports = mongoose.model("VideoComment", VideoCommentSchema); 