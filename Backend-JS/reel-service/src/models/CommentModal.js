const mongoose = require("mongoose");
const { REEL_LIMITS } = require('../utils/constants');

const CommentSchema = new mongoose.Schema(
  {
    userId: {
      type: String,
      required: true,
      index: true,
    },
    userName: {
      type: String,
      required: true,
    },
    profilePhoto: {
      type: String,
    },
    reel: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Reel",
      required: true,
      index: true,
    },
    content: {
      type: String,
      required: true,
      trim: true,
      maxlength: REEL_LIMITS.MAX_COMMENT_LENGTH,
    },
    parentComment: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "ReelComment",
      default: null,
      index: true,
    },
    likes: {
      count: {
        type: Number,
        default: 0,
      },
      users: [{
        type: String, // userId as string for consistency
      }],
    },
    replies: [{
      type: mongoose.Schema.Types.ObjectId,
      ref: "ReelComment",
    }],
    depth: {
      type: Number,
      default: 0,
      max: REEL_LIMITS.MAX_COMMENT_DEPTH,
    },
    isDeleted: {
      type: Boolean,
      default: false,
      index: true,
    },
  },
  {
    timestamps: true,
  }
);

// Compound indexes for common query patterns (optimized for 10k users)
CommentSchema.index({ reel: 1, isDeleted: 1, createdAt: -1 }); // Comments for reel
CommentSchema.index({ reel: 1, parentComment: 1, createdAt: -1 }); // Top-level comments
CommentSchema.index({ parentComment: 1, isDeleted: 1, createdAt: -1 }); // Replies

// Static method to get comments for a reel
CommentSchema.statics.getByReel = function(reelId, { page = 1, limit = 20, parentComment = null } = {}) {
  const skip = (page - 1) * limit;
  return this.find({
    reel: reelId,
    parentComment,
    isDeleted: false,
  })
    .sort({ createdAt: -1 })
    .skip(skip)
    .limit(limit)
    .populate({
      path: 'replies',
      match: { isDeleted: false },
      options: { sort: { createdAt: -1 }, limit: 5 },
    })
    .lean();
};

// Static method to count comments for a reel
CommentSchema.statics.countByReel = function(reelId) {
  return this.countDocuments({ reel: reelId, parentComment: null, isDeleted: false });
};

// Instance method to soft delete
CommentSchema.methods.softDelete = async function() {
  this.isDeleted = true;
  this.content = '[deleted]';
  return this.save();
};

const ReelComment = mongoose.model("ReelComment", CommentSchema);
module.exports = ReelComment;
