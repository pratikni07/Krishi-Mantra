const mongoose = require('mongoose');

const tagSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
      trim: true,
      index: true,
    },
    feedId: [{
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Feed',
    }],
    feedCount: {
      type: Number,
      default: 0,
      min: 0,
    },
    totalEngagement: {
      type: Number,
      default: 0,
      min: 0,
    },
    lastActivity: {
      type: Date,
      default: Date.now,
      index: true,
    },
  },
  {
    timestamps: true,
  }
);

// Index for trending tags query
tagSchema.index({ feedCount: -1, lastActivity: -1 });
tagSchema.index({ totalEngagement: -1 });

// Static method to add feed to tag
tagSchema.statics.addFeedToTag = async function(tagName, feedId) {
  return this.findOneAndUpdate(
    { name: tagName.toLowerCase() },
    {
      $setOnInsert: { name: tagName.toLowerCase() },
      $addToSet: { feedId: feedId },
      $inc: { feedCount: 1 },
      $set: { lastActivity: new Date() },
    },
    { upsert: true, new: true }
  );
};

// Static method to remove feed from tag
tagSchema.statics.removeFeedFromTag = async function(tagName, feedId) {
  return this.findOneAndUpdate(
    { name: tagName.toLowerCase() },
    {
      $pull: { feedId: feedId },
      $inc: { feedCount: -1 },
    },
    { new: true }
  );
};

// Static method to get trending tags
tagSchema.statics.getTrending = function(limit = 10) {
  return this.find()
    .sort({ feedCount: -1, totalEngagement: -1, lastActivity: -1 })
    .limit(limit)
    .select('name feedCount totalEngagement lastActivity')
    .lean();
};

module.exports = mongoose.model('Tag', tagSchema);
