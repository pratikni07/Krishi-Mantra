const mongoose = require('mongoose');
const { NOTIFICATION_DELIVERY_MODE } = require('../utils/constants');

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
    locale: {
      type: String,
      default: 'en',
      maxlength: 10,
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
      system: { type: Boolean, default: true },
      subscription: { type: Boolean, default: true },
      promotion: { type: Boolean, default: true },
      advertisement: { type: Boolean, default: true },
      post_engagement: { type: Boolean, default: true },
      reel_engagement: { type: Boolean, default: true },
      marketplace: { type: Boolean, default: true },
      consultant_service: { type: Boolean, default: true },
      message: { type: Boolean, default: true },
    },
    interests: {
      crops: { type: [String], default: [] },
      livestock: { type: [String], default: [] },
      marketplaceTags: { type: [String], default: [] },
      contentTopics: { type: [String], default: [] },
      locations: { type: [String], default: [] },
    },
    muted: {
      actorIds: { type: [String], default: [] },
      entityIds: { type: [String], default: [] },
      categories: { type: [String], default: [] },
    },
    delivery: {
      defaultMode: {
        type: String,
        enum: Object.values(NOTIFICATION_DELIVERY_MODE),
        default: NOTIFICATION_DELIVERY_MODE.INSTANT,
      },
      categoryModes: {
        type: Map,
        of: {
          type: String,
          enum: Object.values(NOTIFICATION_DELIVERY_MODE),
        },
        default: {},
      },
      digest: {
        enabled: { type: Boolean, default: true },
        frequencyMinutes: { type: Number, default: 60, min: 15, max: 1440 },
      },
      channelFallback: {
        enabled: { type: Boolean, default: true },
      },
    },
    frequencyCaps: {
      type: Map,
      of: {
        limit: { type: Number, min: 1, default: 20 },
        windowSeconds: { type: Number, min: 60, default: 3600 },
      },
      default: {},
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

UserNotificationPreferencesSchema.index({ 'channels.push.token': 1 });
UserNotificationPreferencesSchema.index({ enabled: 1 });

UserNotificationPreferencesSchema.statics.getOrCreate = async function(userId) {
  let preferences = await this.findOne({ userId });

  if (!preferences) {
    preferences = await this.create({ userId });
  }

  return preferences;
};

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

UserNotificationPreferencesSchema.statics.getUsersForCategory = function(category, limit = 1000) {
  return this.find({
    enabled: true,
    [`categories.${category}`]: { $ne: false },
    'muted.categories': { $ne: category },
  })
    .select('userId channels interests muted delivery frequencyCaps locale')
    .limit(limit)
    .lean();
};

UserNotificationPreferencesSchema.methods.isCategoryEnabled = function(category) {
  if (!this.enabled) return false;
  if (this.muted?.categories?.includes(category)) return false;
  return this.categories?.[category] !== false;
};

UserNotificationPreferencesSchema.methods.isChannelEnabled = function(channel) {
  if (!this.enabled) return false;
  return this.channels?.[channel]?.enabled !== false;
};

UserNotificationPreferencesSchema.methods.isEntityMuted = function(entityId, actorId) {
  if (!this.muted) return false;
  return Boolean(
    (entityId && this.muted.entityIds?.includes(entityId)) ||
    (actorId && this.muted.actorIds?.includes(actorId))
  );
};

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

  if (startTime > endTime) {
    return currentTime >= startTime || currentTime < endTime;
  }

  return currentTime >= startTime && currentTime < endTime;
};

module.exports = mongoose.model('UserNotificationPreferences', UserNotificationPreferencesSchema);
