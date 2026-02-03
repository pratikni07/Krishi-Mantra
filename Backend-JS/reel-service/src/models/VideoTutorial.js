const mongoose = require("mongoose");
const { VIDEO_LIMITS, VIDEO_TYPES, VISIBILITY } = require('../utils/constants');

const VideoTutorialSchema = new mongoose.Schema(
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
    title: {
      type: String,
      required: true,
      trim: true,
      maxLength: VIDEO_LIMITS.MAX_TITLE_LENGTH,
    },
    description: {
      type: String,
      trim: true,
      maxLength: VIDEO_LIMITS.MAX_DESCRIPTION_LENGTH,
    },
    thumbnail: {
      type: String,
      required: true,
    },
    videoUrl: {
      type: String,
      required: true,
    },
    videoType: {
      type: String,
      enum: Object.values(VIDEO_TYPES),
      required: true,
    },
    duration: {
      type: Number,
    },
    tags: {
      type: [String],
      validate: [arr => arr.length <= VIDEO_LIMITS.MAX_TAGS, `Maximum ${VIDEO_LIMITS.MAX_TAGS} tags allowed`],
    },
    category: {
      type: String,
      required: true,
      index: true,
    },
    visibility: {
      type: String,
      enum: Object.values(VISIBILITY),
      default: VISIBILITY.PUBLIC,
      index: true,
    },
    likes: {
      count: {
        type: Number,
        default: 0,
        index: true,
      },
      users: [{
        type: String, // userId
      }],
    },
    views: {
      count: {
        type: Number,
        default: 0,
        index: true,
      },
      unique: [{
        type: String, // userId - limit to last 1000 for performance
      }],
    },
    comments: {
      count: {
        type: Number,
        default: 0,
      },
    },
    reports: {
      type: [{
        userId: String,
        reason: String,
        description: String,
        date: {
          type: Date,
          default: Date.now,
        },
      }],
      default: [],
    },
    isActive: {
      type: Boolean,
      default: true,
      index: true,
    },
  },
  {
    timestamps: true,
  }
);

// Compound indexes for common query patterns (optimized for 10k users)
VideoTutorialSchema.index({ userId: 1, createdAt: -1 }); // User's videos
VideoTutorialSchema.index({ title: 'text', description: 'text', tags: 'text' }); // Text search
VideoTutorialSchema.index({ 'likes.count': -1, createdAt: -1 }); // Popular videos
VideoTutorialSchema.index({ 'views.count': -1, createdAt: -1 }); // Most viewed
VideoTutorialSchema.index({ category: 1, createdAt: -1 }); // Videos by category
VideoTutorialSchema.index({ visibility: 1, isActive: 1, createdAt: -1 }); // Public feed
VideoTutorialSchema.index({ category: 1, 'views.count': -1 }); // Popular by category
VideoTutorialSchema.index({ tags: 1 }); // Videos by tag

// Pre-save hook to limit unique views array
VideoTutorialSchema.pre('save', function(next) {
  // Keep only last 1000 unique viewers to prevent unbounded growth
  if (this.views.unique && this.views.unique.length > 1000) {
    this.views.unique = this.views.unique.slice(-1000);
  }
  // Check reports threshold
  if (this.reports && this.reports.length >= VIDEO_LIMITS.MAX_REPORTS_BEFORE_REVIEW) {
    // Flag for review
    this.isActive = false;
  }
  next();
});

// Static method to get videos by category
VideoTutorialSchema.statics.getByCategory = function(category, { page = 1, limit = 12, sort = 'recent' } = {}) {
  const skip = (page - 1) * limit;
  const sortOptions = {
    recent: { createdAt: -1 },
    popular: { 'views.count': -1 },
    trending: { 'likes.count': -1 },
  };

  return this.find({ category, visibility: VISIBILITY.PUBLIC, isActive: true })
    .sort(sortOptions[sort] || sortOptions.recent)
    .skip(skip)
    .limit(limit)
    .lean();
};

// Static method to search videos
VideoTutorialSchema.statics.searchVideos = function(query, { page = 1, limit = 12 } = {}) {
  const skip = (page - 1) * limit;
  return this.find({
    $text: { $search: query },
    visibility: VISIBILITY.PUBLIC,
    isActive: true,
  })
    .sort({ score: { $meta: 'textScore' } })
    .skip(skip)
    .limit(limit)
    .lean();
};

// Static method to get related videos
VideoTutorialSchema.statics.getRelated = function(videoId, category, tags, limit = 8) {
  return this.find({
    _id: { $ne: videoId },
    isActive: true,
    visibility: VISIBILITY.PUBLIC,
    $or: [
      { category },
      { tags: { $in: tags } },
    ],
  })
    .sort({ 'views.count': -1 })
    .limit(limit)
    .lean();
};

// Instance method to record view
VideoTutorialSchema.methods.recordView = async function(userId) {
  if (userId && !this.views.unique.includes(userId)) {
    this.views.count += 1;
    this.views.unique.push(userId);
    await this.save();
    return true;
  }
  return false;
};

module.exports = mongoose.model("VideoTutorial", VideoTutorialSchema);
