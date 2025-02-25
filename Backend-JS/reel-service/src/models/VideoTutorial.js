const mongoose = require("mongoose");

const VideoTutorialSchema = new mongoose.Schema(
  {
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
    title: {
      type: String,
      required: true,
      trim: true,
      maxLength: 100,
    },
    description: {
      type: String,
      trim: true,
      maxLength: 5000,
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
      enum: ['youtube', 'drive', 'cloudinary', 'direct'],
      required: true,
    },
    duration: {
      type: Number, // Duration in seconds
    },
    tags: [{
      type: String,
      trim: true,
    }],
    category: {
      type: String,
      required: true,
    },
    visibility: {
      type: String,
      enum: ['public', 'private', 'unlisted'],
      default: 'public',
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
    views: {
      count: {
        type: Number,
        default: 0,
      },
      unique: [{
        type: String, // userId
      }]
    },
    comments: {
      count: {
        type: Number,
        default: 0,
      },
    },
    reports: [{
      userId: String,
      reason: String,
      description: String,
      date: {
        type: Date,
        default: Date.now,
      },
    }],
  },
  {
    timestamps: true,
  }
);

// Indexes for better query performance
VideoTutorialSchema.index({ userId: 1, createdAt: -1 });
VideoTutorialSchema.index({ title: 'text', description: 'text', tags: 'text' });
VideoTutorialSchema.index({ "likes.count": -1, createdAt: -1 });
VideoTutorialSchema.index({ "views.count": -1, createdAt: -1 });
VideoTutorialSchema.index({ category: 1, createdAt: -1 });

module.exports = mongoose.model("VideoTutorial", VideoTutorialSchema); 