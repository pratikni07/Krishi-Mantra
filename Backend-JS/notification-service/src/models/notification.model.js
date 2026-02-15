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
    dedupeKey: {
      type: String,
      default: null,
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
    clickedAt: {
      type: Date,
      default: null,
    },
    actionedAt: {
      type: Date,
      default: null,
    },
    channelTrail: {
      type: [String],
      default: [],
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

NotificationSchema.index({ userId: 1, createdAt: -1 });
NotificationSchema.index({ userId: 1, status: 1, createdAt: -1 });
NotificationSchema.index({ status: 1, scheduledFor: 1 });
NotificationSchema.index({ status: 1, scheduledFor: 1, priority: -1 });
NotificationSchema.index({ userId: 1, category: 1, createdAt: -1 });
NotificationSchema.index({ batchId: 1, status: 1 });
NotificationSchema.index({ userId: 1, seenAt: 1 });
NotificationSchema.index({ dedupeKey: 1, userId: 1, createdAt: -1 });

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

NotificationSchema.statics.countUnread = function(userId) {
  return this.countDocuments({
    userId,
    seenAt: null,
    status: { $in: [NOTIFICATION_STATUS.DELIVERED, NOTIFICATION_STATUS.PENDING] },
  });
};

NotificationSchema.statics.getPendingForBatch = function(limit = 100) {
  return this.find({
    status: { $in: [NOTIFICATION_STATUS.PENDING, NOTIFICATION_STATUS.DEFERRED] },
    scheduledFor: { $lte: new Date() },
  })
    .sort({ priority: -1, scheduledFor: 1 })
    .limit(limit)
    .lean();
};

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

NotificationSchema.statics.markMultipleSeen = function(userId, notificationIds) {
  return this.updateMany(
    { _id: { $in: notificationIds }, userId },
    {
      status: NOTIFICATION_STATUS.READ,
      seenAt: new Date(),
    }
  );
};

NotificationSchema.methods.markFailed = async function(errorMessage) {
  this.status = NOTIFICATION_STATUS.FAILED;
  this.error = errorMessage;
  this.retryCount += 1;
  return this.save();
};

module.exports = mongoose.model('Notification', NotificationSchema);
