const mongoosePaginate = require('mongoose-paginate-v2');
const mongoose = require('mongoose');

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
    feed: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Feed',
      required: true,
      index: true,
    },
    content: {
      type: String,
      required: true,
      trim: true,
      maxlength: 2000,
    },
    parentComment: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Comment',
      default: null,
      index: true,
    },
    likes: {
      count: {
        type: Number,
        default: 0,
        min: 0,
      },
      users: [{
        type: String,
      }],
    },
    replies: [{
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Comment',
    }],
    replyCount: {
      type: Number,
      default: 0,
      min: 0,
    },
    depth: {
      type: Number,
      default: 0,
      max: 5,
    },
    reports: [{
      userId: {
        type: String,
      },
      reason: {
        type: String,
        maxlength: 500,
      },
      createdAt: {
        type: Date,
        default: Date.now,
      },
    }],
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

// Pagination plugin
CommentSchema.plugin(mongoosePaginate);

// Compound indexes for common query patterns (optimized for 10k users)
CommentSchema.index({ feed: 1, parentComment: 1, createdAt: -1 }); // Get root comments for a feed
CommentSchema.index({ feed: 1, isDeleted: 1, createdAt: -1 }); // Get all comments for a feed
CommentSchema.index({ parentComment: 1, createdAt: -1 }); // Get replies to a comment
CommentSchema.index({ userId: 1, createdAt: -1 }); // Get user's comments

// Static methods for common queries
CommentSchema.statics.getRootComments = function(feedId, limit = 10, skip = 0) {
  return this.find({
    feed: feedId,
    parentComment: null,
    isDeleted: false,
  })
    .sort({ createdAt: -1 })
    .skip(skip)
    .limit(limit)
    .lean();
};

CommentSchema.statics.getReplies = function(commentId, limit = 5) {
  return this.find({
    parentComment: commentId,
    isDeleted: false,
  })
    .sort({ createdAt: -1 })
    .limit(limit)
    .lean();
};

CommentSchema.statics.getCommentCount = async function(feedId) {
  return this.countDocuments({
    feed: feedId,
    isDeleted: false,
  });
};

// Instance methods
CommentSchema.methods.softDelete = async function() {
  this.isDeleted = true;
  this.content = '[deleted]';
  return this.save();
};

CommentSchema.methods.addReply = async function(replyId) {
  this.replies.push(replyId);
  this.replyCount += 1;
  return this.save();
};

module.exports = mongoose.model('Comment', CommentSchema);
