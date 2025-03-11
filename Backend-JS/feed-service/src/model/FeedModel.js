const mongoose = require("mongoose");

const FeedSchema = new mongoose.Schema({
  userId: {
    type: String,
  },
  userName: {
    type: String,
  },
  profilePhoto: {
    type: String,
  },
  description: {
    type: String,
  },
  content: {
    type: String,
  },
  mediaUrl: {
    type: String,
  },
  like: {
    count: {
      type: Number,
    },
  },
  comment: {
    count: {
      type: Number,
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
});

module.exports = mongoose.model("Feed", FeedSchema);
