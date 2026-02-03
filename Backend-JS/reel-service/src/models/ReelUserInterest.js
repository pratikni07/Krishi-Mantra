const mongoose = require('mongoose');

const REEL_INTEREST_CONSTANTS = {
  MAX_INTERESTS: 100,
  MAX_RECENT_VIEWS: 500,
  INTERACTION_SCORES: {
    view: 0.2,
    like: 0.5,
    comment: 1.0,
    share: 1.5,
    save: 1.2,
  },
};

const reelUserInterestSchema = new mongoose.Schema(
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
      reelId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Reel',
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
    // Track interaction counts for analytics
    interactionCounts: {
      views: { type: Number, default: 0 },
      likes: { type: Number, default: 0 },
      comments: { type: Number, default: 0 },
      shares: { type: Number, default: 0 },
    },
  },
  {
    timestamps: true,
  }
);

// Indexes for efficient queries
reelUserInterestSchema.index({ 'location.latitude': 1, 'location.longitude': 1 });
reelUserInterestSchema.index({ engagementLevel: 1, lastActive: -1 });
reelUserInterestSchema.index({ 'interests.tag': 1 });
reelUserInterestSchema.index({ 'interests.score': -1 });

// Method to add or update an interest
reelUserInterestSchema.methods.updateInterest = function(tag, scoreIncrement) {
  const normalizedTag = tag.toLowerCase().trim();
  const existingInterest = this.interests.find(i => i.tag === normalizedTag);

  if (existingInterest) {
    existingInterest.score = Math.max(0, existingInterest.score + scoreIncrement);
    existingInterest.lastInteraction = new Date();
  } else {
    this.interests.push({
      tag: normalizedTag,
      score: Math.max(0, scoreIncrement),
      lastInteraction: new Date(),
    });
  }

  // Keep only top interests to prevent unbounded growth
  if (this.interests.length > REEL_INTEREST_CONSTANTS.MAX_INTERESTS) {
    this.interests.sort((a, b) => b.score - a.score);
    this.interests = this.interests.slice(0, REEL_INTEREST_CONSTANTS.MAX_INTERESTS);
  }

  this.lastActive = new Date();
  return this;
};

// Method to update multiple interests at once
reelUserInterestSchema.methods.updateInterests = function(tags, scoreIncrement) {
  tags.forEach(tag => {
    this.updateInterest(tag, scoreIncrement);
  });
  return this;
};

// Method to add a view
reelUserInterestSchema.methods.addView = function(reelId) {
  const reelIdStr = reelId.toString();
  const existingView = this.recentViews.find(
    v => v.reelId && v.reelId.toString() === reelIdStr
  );

  if (existingView) {
    existingView.viewedAt = new Date();
  } else {
    this.recentViews.push({
      reelId,
      viewedAt: new Date(),
    });
  }

  // Keep only recent views to prevent unbounded growth
  if (this.recentViews.length > REEL_INTEREST_CONSTANTS.MAX_RECENT_VIEWS) {
    this.recentViews.sort((a, b) => b.viewedAt - a.viewedAt);
    this.recentViews = this.recentViews.slice(0, REEL_INTEREST_CONSTANTS.MAX_RECENT_VIEWS);
  }

  return this;
};

// Method to calculate engagement level
reelUserInterestSchema.methods.calculateEngagementLevel = function() {
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

// Method to get viewed reel IDs (for exclusion in recommendations)
reelUserInterestSchema.methods.getViewedReelIds = function(limit = 100) {
  return this.recentViews
    .sort((a, b) => b.viewedAt - a.viewedAt)
    .slice(0, limit)
    .map(v => v.reelId);
};

// Static method to get top tags for user
reelUserInterestSchema.statics.getTopTags = async function(userId, limit = 10) {
  const user = await this.findOne({ userId }).lean();
  if (!user || !user.interests) return [];

  return user.interests
    .sort((a, b) => b.score - a.score)
    .slice(0, limit)
    .map(i => i.tag);
};

// Static method to find or create user interest
reelUserInterestSchema.statics.findOrCreate = async function(userId) {
  let userInterest = await this.findOne({ userId });

  if (!userInterest) {
    userInterest = new this({ userId });
    await userInterest.save();
  }

  return userInterest;
};

// Static method to get users with similar interests
reelUserInterestSchema.statics.getSimilarUsers = async function(userId, limit = 10) {
  const user = await this.findOne({ userId }).lean();
  if (!user || !user.interests || user.interests.length === 0) return [];

  const topTags = user.interests
    .sort((a, b) => b.score - a.score)
    .slice(0, 5)
    .map(i => i.tag);

  return this.find({
    userId: { $ne: userId },
    'interests.tag': { $in: topTags },
  })
    .sort({ lastActive: -1 })
    .limit(limit)
    .select('userId interests')
    .lean();
};

module.exports = mongoose.model('ReelUserInterest', reelUserInterestSchema);
module.exports.REEL_INTEREST_CONSTANTS = REEL_INTEREST_CONSTANTS;
