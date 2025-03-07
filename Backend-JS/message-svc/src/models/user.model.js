const mongoose = require("mongoose");

const userSchema = new mongoose.Schema(
  {
    userId: {
      type: String,
      required: true,
      unique: true,
      index: true,
    },
    firstName: {
      type: String,
      required: true,
    },
    lastName: {
      type: String,
    },
    email: {
      type: String,
      required: true,
      unique: true,
    },
    profilePhoto: {
      type: String,
      default: "",
    },
    preferences: {
      language: {
        type: String,
        default: "en",
      },
      location: {
        lat: Number,
        lon: Number,
      },
    },
    messageLimits: {
      dailyCount: {
        type: Number,
        default: 0,
      },
      lastResetDate: {
        type: Date,
        default: Date.now,
      },
    },
    lastActive: {
      type: Date,
      default: Date.now,
    },
    isActive: {
      type: Boolean,
      default: true,
    },
  },
  { timestamps: true }
);

// Reset daily message count at midnight
userSchema.methods.resetDailyMessageCount = function () {
  const today = new Date();
  today.setHours(0, 0, 0, 0);

  if (this.messageLimits.lastResetDate < today) {
    this.messageLimits.dailyCount = 0;
    this.messageLimits.lastResetDate = new Date();
    return true;
  }
  return false;
};

// Update user's last active timestamp
userSchema.methods.updateLastActive = function () {
  this.lastActive = new Date();
};

// Index for efficient querying
userSchema.index({ email: 1 });
userSchema.index({ lastActive: -1 });

module.exports = mongoose.model("User", userSchema);
