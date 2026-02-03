const mongoose = require('mongoose');
const { NOTIFICATION_CATEGORIES } = require('../utils/constants');

const UserNotificationPreferencesSchema = new mongoose.Schema(
  {
    userId: {
      type: String,
      required: true,
      unique: true,
      index: true,
    },
    enabled: {
      type: Boolean,
      default: true,
    },
    channels: {
      push: {
        enabled: { type: Boolean, default: true },
        token: { type: String, default: null },
        platform: { type: String, enum: ['android', 'ios', 'web'], default: null },
      },
      email: {
        enabled: { type: Boolean, default: true },
        address: { type: String, default: null },
        verified: { type: Boolean, default: false },
      },
      sms: {
        enabled: { type: Boolean, default: true },
        phoneNumber: { type: String, default: null },
        verified: { type: Boolean, default: false },
      },
      inApp: {
        enabled: { type: Boolean, default: true },
      },
    },
    categories: {
      consultant_service: { type: Boolean, default: true },
      new_post: { type: Boolean, default: true },
      new_reel: { type: Boolean, default: true },
      farm_videos: { type: Boolean, default: true },
      crop_care_ai: { type: Boolean, default: true },
      system: { type: Boolean, default: true },
    },
    quietHours: {
      enabled: { type: Boolean, default: false },
      start: { type: String, default: '22:00' },
      end: { type: String, default: '07:00' },
      timezone: { type: String, default: 'Asia/Kolkata' },
    },
    lastNotificationAt: {
      type: Date,
      default: null,
    },
  },
  {
    timestamps: true,
  }
);

// Indexes for efficient queries (optimized for 10k users)
UserNotificationPreferencesSchema.index({ 'channels.push.token': 1 });
UserNotificationPreferencesSchema.index({ enabled: 1 });

// Static method to get or create preferences
UserNotificationPreferencesSchema.statics.getOrCreate = async function(userId) {
  let preferences = await this.findOne({ userId });

  if (!preferences) {
    preferences = await this.create({ userId });
  }

  return preferences;
};

// Static method to update push token
UserNotificationPreferencesSchema.statics.updatePushToken = function(userId, token, platform) {
  return this.findOneAndUpdate(
    { userId },
    {
      'channels.push.token': token,
      'channels.push.platform': platform,
      'channels.push.enabled': true,
    },
    { new: true, upsert: true }
  );
};

// Static method to get users by category preference
UserNotificationPreferencesSchema.statics.getUsersForCategory = function(category, limit = 1000) {
  return this.find({
    enabled: true,
    [`categories.${category}`]: true,
  })
    .select('userId channels')
    .limit(limit)
    .lean();
};

// Instance method to check if category is enabled
UserNotificationPreferencesSchema.methods.isCategoryEnabled = function(category) {
  if (!this.enabled) return false;
  return this.categories[category] !== false;
};

// Instance method to check if channel is enabled
UserNotificationPreferencesSchema.methods.isChannelEnabled = function(channel) {
  if (!this.enabled) return false;
  return this.channels[channel]?.enabled !== false;
};

// Instance method to check if in quiet hours
UserNotificationPreferencesSchema.methods.isInQuietHours = function() {
  if (!this.quietHours.enabled) return false;

  const now = new Date();
  const timeString = now.toLocaleTimeString('en-US', {
    hour12: false,
    hour: '2-digit',
    minute: '2-digit',
    timeZone: this.quietHours.timezone,
  });

  const currentTime = timeString.replace(':', '');
  const startTime = this.quietHours.start.replace(':', '');
  const endTime = this.quietHours.end.replace(':', '');

  // Handle overnight quiet hours (e.g., 22:00 to 07:00)
  if (startTime > endTime) {
    return currentTime >= startTime || currentTime < endTime;
  }

  return currentTime >= startTime && currentTime < endTime;
};

module.exports = mongoose.model('UserNotificationPreferences', UserNotificationPreferencesSchema);
