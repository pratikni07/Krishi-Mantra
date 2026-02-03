const mongoose = require('mongoose');

const LikeSchema = new mongoose.Schema(
  {
    userId: {
      type: String,
      required: true,
      index: true,
    },
    userName: {
      type: String,
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
    date: {
      type: Date,
      default: Date.now,
      index: true,
    },
  },
  {
    timestamps: true,
  }
);

// Compound unique index to prevent duplicate likes
LikeSchema.index({ feed: 1, userId: 1 }, { unique: true });

// Index for feed-based queries (get all likes for a feed)
LikeSchema.index({ feed: 1, date: -1 });

// Index for user-based queries (get all likes by a user)
LikeSchema.index({ userId: 1, date: -1 });

// Static method to check if user liked a feed
LikeSchema.statics.hasUserLiked = async function(feedId, userId) {
  const like = await this.findOne({ feed: feedId, userId }).lean();
  return !!like;
};

// Static method to get like count for a feed
LikeSchema.statics.getLikeCount = async function(feedId) {
  return this.countDocuments({ feed: feedId });
};

// Static method to get users who liked a feed
LikeSchema.statics.getLikedUsers = function(feedId, limit = 10) {
  return this.find({ feed: feedId })
    .sort({ date: -1 })
    .limit(limit)
    .select('userId userName profilePhoto date')
    .lean();
};

module.exports = mongoose.model('Likes', LikeSchema);
