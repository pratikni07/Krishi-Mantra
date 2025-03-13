const mongoose = require('mongoose');

const UserNotificationPreferencesSchema = new mongoose.Schema({
  userId: {
    type: String,
    required: true,
    unique: true
  },
  enabled: {
    type: Boolean,
    default: true
  },
  channels: {
    push: {
      enabled: { type: Boolean, default: true },
      token: { type: String, default: null }
    },
    email: {
      enabled: { type: Boolean, default: true },
      address: { type: String, default: null }
    },
    sms: {
      enabled: { type: Boolean, default: true },
      phoneNumber: { type: String, default: null }
    },
    inApp: {
      enabled: { type: Boolean, default: true }
    }
  },
  categories: {
    consultant_service: { type: Boolean, default: true },
    new_post: { type: Boolean, default: true },
    new_reel: { type: Boolean, default: true },
    farm_videos: { type: Boolean, default: true },
    crop_care_ai: { type: Boolean, default: true },
    system: { type: Boolean, default: true }
  },
  quietHours: {
    enabled: { type: Boolean, default: false },
    start: { type: String, default: '22:00' },
    end: { type: String, default: '07:00' },
    timezone: { type: String, default: 'UTC' }
  },
  updatedAt: {
    type: Date,
    default: Date.now
  }
});

module.exports = mongoose.model('UserNotificationPreferences', UserNotificationPreferencesSchema); 