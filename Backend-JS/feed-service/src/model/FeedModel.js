const mongoose = require('mongoose');

const FeedSchema = new mongoose.Schema(
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
      maxlength: 500,
    },
    content: {
      type: String,
      required: true,
      maxlength: 5000,
    },
    mediaUrl: {
      type: String,
    },
    mediaUrls: [{
      type: String,
    }],
    like: {
      count: {
        type: Number,
        default: 0,
        min: 0,
      },
    },
    comment: {
      count: {
        type: Number,
        default: 0,
        min: 0,
      },
    },
    views: {
      count: {
        type: Number,
        default: 0,
        min: 0,
      },
      lastViewed: {
        type: Date,
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
      },
      // Keep legacy fields for backward compatibility
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
    },
    date: {
      type: Date,
      default: Date.now,
      index: true,
    },
    isDeleted: {
      type: Boolean,
      default: false,
      index: true,
    },
    tags: [{
      type: String,
      lowercase: true,
      trim: true,
    }],
  },
  {
    timestamps: true,
    toJSON: { virtuals: true },
    toObject: { virtuals: true },
  }
);

// Compound indexes for common query patterns (optimized for 10k users)
FeedSchema.index({ date: -1, isDeleted: 1 }); // Feed listing by date
FeedSchema.index({ userId: 1, date: -1 }); // User's feeds
FeedSchema.index({ 'like.count': -1, date: -1 }); // Popular feeds
FeedSchema.index({ 'views.count': -1, date: -1 }); // Most viewed feeds
FeedSchema.index({ tags: 1, date: -1 }); // Tag-based queries
FeedSchema.index({ content: 'text', description: 'text' }); // Full-text search

// Geospatial index for location-based queries
FeedSchema.index({ 'location.coordinates': '2dsphere' });

// Index for legacy location fields
FeedSchema.index({ 'location.latitude': 1, 'location.longitude': 1 });

// Compound index for engagement scoring
FeedSchema.index({
  'like.count': -1,
  'comment.count': -1,
  'views.count': -1,
  date: -1
});

// Virtual for engagement score
FeedSchema.virtual('engagementScore').get(function () {
  return (this.views?.count || 0) +
    (this.like?.count || 0) * 3 +
    (this.comment?.count || 0) * 5;
});

// Pre-save middleware to extract tags from content
FeedSchema.pre('save', function (next) {
  if (this.isModified('content')) {
    const tagRegex = /#(\w+)/g;
    const matches = this.content.match(tagRegex);
    if (matches) {
      this.tags = matches.map(tag => tag.slice(1).toLowerCase());
    }
  }

  // Set GeoJSON coordinates from legacy lat/lng
  if (this.location && this.location.latitude && this.location.longitude) {
    this.location.coordinates = [this.location.longitude, this.location.latitude];
    this.location.type = 'Point';
  }

  next();
});

// Static methods for common queries
FeedSchema.statics.findByLocation = function (longitude, latitude, maxDistanceKm = 50) {
  return this.find({
    'location.coordinates': {
      $nearSphere: {
        $geometry: {
          type: 'Point',
          coordinates: [longitude, latitude],
        },
        $maxDistance: maxDistanceKm * 1000, // Convert km to meters
      },
    },
    isDeleted: false,
  });
};

FeedSchema.statics.findPopular = function (limit = 10) {
  return this.find({ isDeleted: false })
    .sort({ 'like.count': -1, 'comment.count': -1, date: -1 })
    .limit(limit)
    .lean();
};

FeedSchema.statics.findByTags = function (tags, limit = 20) {
  return this.find({
    tags: { $in: tags },
    isDeleted: false,
  })
    .sort({ date: -1 })
    .limit(limit)
    .lean();
};

// Instance methods
FeedSchema.methods.incrementViews = async function () {
  this.views.count += 1;
  this.views.lastViewed = new Date();
  return this.save();
};

FeedSchema.methods.softDelete = async function () {
  this.isDeleted = true;
  return this.save();
};

module.exports = mongoose.model('Feed', FeedSchema);
