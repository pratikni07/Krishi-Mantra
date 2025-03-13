const mongoose = require("mongoose");

const userInterestSchema = new mongoose.Schema(
  {
    userId: {
      type: String,
      required: true,
      unique: true,
    },
    location: {
      latitude: Number,
      longitude: Number,
      lastUpdated: {
        type: Date,
        default: Date.now,
      },
    },
    interests: [
      {
        tag: String,
        score: {
          type: Number,
          default: 0,
        },
        lastInteraction: {
          type: Date,
          default: Date.now,
        },
      },
    ],
    recentViews: [
      {
        feedId: {
          type: mongoose.Schema.Types.ObjectId,
          ref: "Feed",
        },
        viewedAt: {
          type: Date,
          default: Date.now,
        },
      },
    ],
    categories: [String],
    engagementLevel: {
      type: String,
      enum: ["low", "medium", "high"],
      default: "medium",
    },
    lastActive: {
      type: Date,
      default: Date.now,
    },
  },
  {
    timestamps: true,
  }
);

module.exports = mongoose.model("UserInterest", userInterestSchema);
