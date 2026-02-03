const mongoose = require("mongoose");
const { REEL_LIMITS } = require('../utils/constants');

const ReelSchema = new mongoose.Schema(
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
    description: {
      type: String,
      maxlength: REEL_LIMITS.MAX_DESCRIPTION_LENGTH,
    },
    // Primary video URL (HLS streaming preferred)
    mediaUrl: {
      type: String,
      required: true,
    },
    // Alternative video formats for fallback/compatibility
    videoUrls: {
      hls: { type: String }, // HLS streaming (adaptive bitrate) - PRIMARY
      mp4: { type: String }, // Direct MP4 fallback
      webm: { type: String }, // WebM format
    },
    // Cloudinary public ID for video management
    cloudinaryId: {
      type: String,
      index: true,
    },
    // Thumbnail image URL
    thumbnail: {
      type: String,
      default: '',
    },
    // Animated preview (like Instagram)
    preview: {
      type: String,
      default: '',
    },
    // Video metadata
    videoMeta: {
      duration: { type: Number }, // Duration in seconds
      width: { type: Number },
      height: { type: Number },
      size: { type: Number }, // File size in bytes
      format: { type: String },
    },
    like: {
      count: {
        type: Number,
        default: 0,
        index: true,
      },
      users: [{
        type: String  // userId
      }]
    },
    comment: {
      count: {
        type: Number,
        default: 0,
      },
    },
    location: {
      type: {
        type: String,
        enum: ['Point'],
        default: 'Point',
      },
      coordinates: {
        type: [Number], // [longitude, latitude]
        default: undefined,
      },
    },
    isActive: {
      type: Boolean,
      default: true,
      index: true,
    },
    viewCount: {
      type: Number,
      default: 0,
    },
    // Denormalized tags for faster recommendation queries
    tags: [{
      type: String,
      lowercase: true,
      trim: true,
      index: true,
    }],
    // Category for content classification
    category: {
      type: String,
      trim: true,
      index: true,
    },
  },
  {
    timestamps: true,
  }
);

// Compound indexes for common query patterns (optimized for 10k users)
ReelSchema.index({ userId: 1, createdAt: -1 }); // User's reels
ReelSchema.index({ 'like.count': -1, createdAt: -1 }); // Trending reels
ReelSchema.index({ createdAt: -1, isActive: 1 }); // Recent reels feed
ReelSchema.index({ isActive: 1, 'like.count': -1 }); // Popular active reels
ReelSchema.index({ description: 'text', userName: 'text' }); // Text search
ReelSchema.index({ 'location': '2dsphere' }); // Geospatial queries
ReelSchema.index({ tags: 1, createdAt: -1 }); // Tag-based recommendations
ReelSchema.index({ category: 1, createdAt: -1 }); // Category-based queries

// Static method to get trending reels
ReelSchema.statics.getTrending = function(limit = 20) {
  return this.find({ isActive: true })
    .sort({ 'like.count': -1, createdAt: -1 })
    .limit(limit)
    .lean();
};

// Static method to get user's reels
ReelSchema.statics.getByUser = function(userId, { page = 1, limit = 10 } = {}) {
  const skip = (page - 1) * limit;
  return this.find({ userId, isActive: true })
    .sort({ createdAt: -1 })
    .skip(skip)
    .limit(limit)
    .lean();
};

// Static method to search reels
ReelSchema.statics.search = function(query, { page = 1, limit = 10 } = {}) {
  const skip = (page - 1) * limit;
  return this.find({
    $text: { $search: query },
    isActive: true,
  })
    .sort({ score: { $meta: 'textScore' } })
    .skip(skip)
    .limit(limit)
    .lean();
};

// Instance method for soft delete
ReelSchema.methods.softDelete = async function() {
  this.isActive = false;
  return this.save();
};

module.exports = mongoose.model("Reel", ReelSchema);
