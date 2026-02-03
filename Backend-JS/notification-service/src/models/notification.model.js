const mongoose = require('mongoose');
const {
  NOTIFICATION_TYPES,
  NOTIFICATION_STATUS,
  NOTIFICATION_PRIORITY,
  NOTIFICATION_CATEGORIES,
} = require('../utils/constants');

const NotificationSchema = new mongoose.Schema(
  {
    userId: {
      type: String,
      required: true,
      index: true,
    },
    type: {
      type: String,
      required: true,
      enum: Object.values(NOTIFICATION_TYPES),
      default: NOTIFICATION_TYPES.IN_APP,
    },
    title: {
      type: String,
      required: true,
      trim: true,
      maxlength: 200,
    },
    body: {
      type: String,
      required: true,
      trim: true,
      maxlength: 1000,
    },
    data: {
      type: mongoose.Schema.Types.Mixed,
    },
    status: {
      type: String,
      enum: Object.values(NOTIFICATION_STATUS),
      default: NOTIFICATION_STATUS.PENDING,
      index: true,
    },
    priority: {
      type: String,
      enum: Object.values(NOTIFICATION_PRIORITY),
      default: NOTIFICATION_PRIORITY.MEDIUM,
    },
    category: {
      type: String,
      enum: Object.values(NOTIFICATION_CATEGORIES),
      default: NOTIFICATION_CATEGORIES.SYSTEM,
      index: true,
    },
    scheduledFor: {
      type: Date,
      default: Date.now,
      index: true,
    },
    batchId: {
      type: String,
      index: true,
    },
    deliveredAt: {
      type: Date,
      default: null,
    },
    seenAt: {
      type: Date,
      default: null,
    },
    error: {
      type: String,
      default: null,
    },
    retryCount: {
      type: Number,
      default: 0,
    },
  },
  {
    timestamps: true,
  }
);

// Compound indexes for common query patterns (optimized for 10k users)
NotificationSchema.index({ userId: 1, createdAt: -1 }); // User notifications list
NotificationSchema.index({ userId: 1, status: 1, createdAt: -1 }); // User notifications by status
NotificationSchema.index({ status: 1, scheduledFor: 1 }); // Batch processing
NotificationSchema.index({ status: 1, scheduledFor: 1, priority: -1 }); // Priority processing
NotificationSchema.index({ userId: 1, category: 1, createdAt: -1 }); // Category filtering
NotificationSchema.index({ batchId: 1, status: 1 }); // Batch status tracking
NotificationSchema.index({ userId: 1, seenAt: 1 }); // Unread notifications

// Static method to get user notifications
NotificationSchema.statics.getByUser = function(userId, { page = 1, limit = 20, status = null } = {}) {
  const skip = (page - 1) * limit;
  const query = { userId };

  if (status) {
    query.status = status;
  }

  return this.find(query)
    .sort({ createdAt: -1 })
    .skip(skip)
    .limit(limit)
    .lean();
};

// Static method to count unread notifications
NotificationSchema.statics.countUnread = function(userId) {
  return this.countDocuments({
    userId,
    seenAt: null,
    status: { $in: [NOTIFICATION_STATUS.DELIVERED, NOTIFICATION_STATUS.PENDING] },
  });
};

// Static method to get pending notifications for batch processing
NotificationSchema.statics.getPendingForBatch = function(limit = 100) {
  return this.find({
    status: NOTIFICATION_STATUS.PENDING,
    scheduledFor: { $lte: new Date() },
  })
    .sort({ priority: -1, scheduledFor: 1 })
    .limit(limit)
    .lean();
};

// Static method to mark as delivered
NotificationSchema.statics.markDelivered = function(notificationId) {
  return this.findByIdAndUpdate(
    notificationId,
    {
      status: NOTIFICATION_STATUS.DELIVERED,
      deliveredAt: new Date(),
    },
    { new: true }
  );
};

// Static method to mark as seen/read
NotificationSchema.statics.markSeen = function(notificationId, userId) {
  return this.findOneAndUpdate(
    { _id: notificationId, userId },
    {
      status: NOTIFICATION_STATUS.READ,
      seenAt: new Date(),
    },
    { new: true }
  );
};

// Static method to mark multiple as seen
NotificationSchema.statics.markMultipleSeen = function(userId, notificationIds) {
  return this.updateMany(
    { _id: { $in: notificationIds }, userId },
    {
      status: NOTIFICATION_STATUS.READ,
      seenAt: new Date(),
    }
  );
};

// Instance method to mark as failed
NotificationSchema.methods.markFailed = async function(errorMessage) {
  this.status = NOTIFICATION_STATUS.FAILED;
  this.error = errorMessage;
  this.retryCount += 1;
  return this.save();
};

module.exports = mongoose.model('Notification', NotificationSchema);
