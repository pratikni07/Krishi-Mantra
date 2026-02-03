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
      index: true,
    },
    isActive: {
      type: Boolean,
      default: true,
      index: true,
    },
  },
  { timestamps: true }
);

// Compound indexes for common query patterns (optimized for 10k users)
// Note: email already has unique index from schema definition
userSchema.index({ isActive: 1, lastActive: -1 }); // Active users sorted by activity
userSchema.index({ 'preferences.language': 1 }); // Users by language preference
userSchema.index({ userId: 1, isActive: 1 }); // Active user lookup

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

// Static method to find or create user
userSchema.statics.findOrCreate = async function(userData) {
  let user = await this.findOne({ userId: userData.userId });
  if (!user) {
    user = await this.create(userData);
  }
  return user;
};

// Static method to get active users
userSchema.statics.getActiveUsers = function(limit = 100) {
  return this.find({ isActive: true })
    .sort({ lastActive: -1 })
    .limit(limit)
    .select('userId firstName lastName profilePhoto lastActive')
    .lean();
};

// Static method to update last active with rate limiting
userSchema.statics.touchLastActive = async function(userId) {
  const fiveMinutesAgo = new Date(Date.now() - 5 * 60 * 1000);
  return this.findOneAndUpdate(
    { userId, lastActive: { $lt: fiveMinutesAgo } },
    { lastActive: new Date() },
    { new: true }
  );
};

// Static method to increment message count
userSchema.statics.incrementMessageCount = async function(userId) {
  const user = await this.findOne({ userId });
  if (user) {
    user.resetDailyMessageCount();
    user.messageLimits.dailyCount += 1;
    await user.save();
    return user.messageLimits.dailyCount;
  }
  return 0;
};

module.exports = mongoose.model("User", userSchema);
