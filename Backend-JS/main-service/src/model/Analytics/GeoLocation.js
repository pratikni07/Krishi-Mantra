const mongoose = require("mongoose");

const GeoLocationSchema = new mongoose.Schema({
  ipAddress: {
    type: String,
    required: true,
  },
  country: {
    type: String,
  },
  region: {
    type: String,
  },
  city: {
    type: String,
  },
  latitude: {
    type: Number,
  },
  longitude: {
    type: Number,
  },
  timestamp: {
    type: Date,
    default: Date.now,
  },
  deviceInfo: {
    type: String,
  },
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "User",
  }
}, {
  timestamps: true
});

// Add indexes for common queries
GeoLocationSchema.index({ timestamp: -1 });
GeoLocationSchema.index({ ipAddress: 1 });
GeoLocationSchema.index({ userId: 1 });

module.exports = mongoose.model("GeoLocation", GeoLocationSchema); 