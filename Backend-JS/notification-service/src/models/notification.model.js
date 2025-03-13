const mongoose = require('mongoose');

const NotificationSchema = new mongoose.Schema({
  userId: {
    type: String,
    required: true,
    index: true
  },
  type: {
    type: String,
    required: true,
    enum: ['in_app', 'push', 'email', 'sms'],
    default: 'in_app'
  },
  title: {
    type: String,
    required: true
  },
  body: {
    type: String,
    required: true
  },
  data: {
    type: mongoose.Schema.Types.Mixed
  },
  status: {
    type: String,
    enum: ['pending', 'processing', 'delivered', 'failed'],
    default: 'pending'
  },
  priority: {
    type: String,
    enum: ['low', 'medium', 'high'],
    default: 'medium'
  },
  category: {
    type: String,
    enum: ['system', 'consultant_service', 'new_post', 'new_reel', 'farm_videos', 'crop_care_ai'],
    default: 'system'
  },
  scheduledFor: {
    type: Date,
    default: Date.now
  },
  createdAt: {
    type: Date,
    default: Date.now
  },
  updatedAt: {
    type: Date,
    default: Date.now
  },
  batchId: {
    type: String,
    index: true
  },
  deliveredAt: {
    type: Date,
    default: null
  },
  seenAt: {
    type: Date,
    default: null
  },
  error: {
    type: String,
    default: null
  }
});

// Indexes for efficient querying
NotificationSchema.index({ status: 1, scheduledFor: 1 });
NotificationSchema.index({ userId: 1, createdAt: -1 });

module.exports = mongoose.model('Notification', NotificationSchema); 