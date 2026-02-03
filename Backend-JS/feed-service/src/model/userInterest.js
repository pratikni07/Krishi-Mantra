const mongoose = require('mongoose');
const { FEED_CONSTANTS } = require('../utils/constants');

const userInterestSchema = new mongoose.Schema(
  {
    userId: {
      type: String,
      required: true,
      unique: true,
      index: true,
    },
    location: {
      latitude: {
        type: Number,
        min: -90,
        max: 90,
      },
      longitude: {
        type: Number,
        min: -180,
        max: 180,
      },
      lastUpdated: {
        type: Date,
        default: Date.now,
      },
    },
    interests: [{
      tag: {
        type: String,
        lowercase: true,
        trim: true,
      },
      score: {
        type: Number,
        default: 0,
        min: 0,
      },
      lastInteraction: {
        type: Date,
        default: Date.now,
      },
    }],
    recentViews: [{
      feedId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Feed',
      },
      viewedAt: {
        type: Date,
        default: Date.now,
      },
    }],
    categories: [{
      type: String,
      trim: true,
    }],
    engagementLevel: {
      type: String,
      enum: ['low', 'medium', 'high'],
      default: 'medium',
      index: true,
    },
    lastActive: {
      type: Date,
      default: Date.now,
      index: true,
    },
  },
  {
    timestamps: true,
  }
);

// Index for location-based queries
userInterestSchema.index({ 'location.latitude': 1, 'location.longitude': 1 });

// Index for engagement queries
userInterestSchema.index({ engagementLevel: 1, lastActive: -1 });

// Index for interests
userInterestSchema.index({ 'interests.tag': 1 });

// Method to add or update an interest
userInterestSchema.methods.updateInterest = function(tag, scoreIncrement) {
  const existingInterest = this.interests.find(i => i.tag === tag);

  if (existingInterest) {
    existingInterest.score = Math.max(0, existingInterest.score + scoreIncrement);
    existingInterest.lastInteraction = new Date();
  } else {
    this.interests.push({
      tag,
      score: Math.max(0, scoreIncrement),
      lastInteraction: new Date(),
    });
  }

  // Keep only top interests to prevent unbounded growth
  if (this.interests.length > FEED_CONSTANTS.MAX_INTERESTS) {
    this.interests.sort((a, b) => b.score - a.score);
    this.interests = this.interests.slice(0, FEED_CONSTANTS.MAX_INTERESTS);
  }

  this.lastActive = new Date();
  return this;
};

// Method to add a view
userInterestSchema.methods.addView = function(feedId) {
  const existingView = this.recentViews.find(
    v => v.feedId.toString() === feedId.toString()
  );

  if (existingView) {
    existingView.viewedAt = new Date();
  } else {
    this.recentViews.push({
      feedId,
      viewedAt: new Date(),
    });
  }

  // Keep only recent views to prevent unbounded growth
  if (this.recentViews.length > FEED_CONSTANTS.MAX_RECENT_VIEWS) {
    this.recentViews.sort((a, b) => b.viewedAt - a.viewedAt);
    this.recentViews = this.recentViews.slice(0, FEED_CONSTANTS.MAX_RECENT_VIEWS);
  }

  return this;
};

// Method to calculate engagement level
userInterestSchema.methods.calculateEngagementLevel = function() {
  const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
  const recentInteractions = this.recentViews.filter(
    v => v.viewedAt >= thirtyDaysAgo
  ).length;

  if (recentInteractions > 100) {
    this.engagementLevel = 'high';
  } else if (recentInteractions > 30) {
    this.engagementLevel = 'medium';
  } else {
    this.engagementLevel = 'low';
  }

  return this;
};

// Static method to get top tags for user
userInterestSchema.statics.getTopTags = async function(userId, limit = 10) {
  const user = await this.findOne({ userId }).lean();
  if (!user || !user.interests) return [];

  return user.interests
    .sort((a, b) => b.score - a.score)
    .slice(0, limit)
    .map(i => i.tag);
};

module.exports = mongoose.model('UserInterest', userInterestSchema);
