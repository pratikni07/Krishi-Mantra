const mongoose = require("mongoose");

const ReelSchema = new mongoose.Schema(
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
    description: {
      type: String,
    },
    mediaUrl: {
      type: String,
      required: true,
    },
    like: {
      count: {
        type: Number,
        default: 0,
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
      latitude: {
        type: Number,
        min: [-90, "Latitude must be between -90 and 90"],
        max: [90, "Latitude must be between -90 and 90"],
      },
      longitude: {
        type: Number,
        min: [-180, "Longitude must be between -180 and 180"],
        max: [180, "Longitude must be between -180 and 180"],
      },
    },
    date: {
      type: Date,
      default: Date.now,
    },
  },
  {
    timestamps: true,
  }
);

ReelSchema.index({ userId: 1, createdAt: -1 });
ReelSchema.index({ "like.count": -1, createdAt: -1 });

module.exports = mongoose.model("Reel", ReelSchema);
