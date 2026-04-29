const mongoose = require('mongoose');

const messageSchema = new mongoose.Schema(
  {
    chatId: {
      type: mongoose.Schema.Types.ObjectId,
      required: true,
      ref: 'Chat',
      index: true,
    },
    sender: {
      type: String,
      required: true,
      index: true,
    },
    senderName: {
      type: String,
      required: true,
    },
    senderPhoto: {
      type: String,
    },
    content: {
      type: String,
      maxlength: 5000,
    },
    mediaType: {
      type: String,
      enum: ['text', 'image', 'video', 'text_image', 'text_video', 'audio', 'file'],
      default: 'text',
    },
    mediaUrl: {
      type: String,
    },
    mediaMetadata: {
      type: Map,
      of: String,
      default: {},
    },
    readBy: [{
      userId: {
        type: String,
        index: true,
      },
      userName: String,
      profilePhoto: String,
      readAt: {
        type: Date,
        default: Date.now,
      },
    }],
    deliveredTo: [{
      userId: {
        type: String,
        index: true,
      },
      userName: String,
      profilePhoto: String,
      deliveredAt: {
        type: Date,
        default: Date.now,
      },
    }],
    isDeleted: {
      type: Boolean,
      default: false,
      index: true,
    },
    // Client-generated UUID for idempotency. The mobile client tags every
    // outbound `message:send` with a stable id so a manual retry (or socket
    // reconnect mid-emit) can't create two copies of the same message.
    // Indexed unique-per-sender — different users can't collide and we
    // can't fail a legit message because some other user picked the same
    // UUID. Sparse so legacy rows without the field don't trip the index.
    clientMessageId: {
      type: String,
    },
  },
  {
    timestamps: true,
  }
);

// Compound indexes for common query patterns (optimized for 10k users)
messageSchema.index({ chatId: 1, createdAt: -1 }); // Get messages for a chat
messageSchema.index({ chatId: 1, isDeleted: 1, createdAt: -1 }); // Get non-deleted messages
messageSchema.index({ sender: 1, createdAt: -1 }); // Get messages by user
messageSchema.index({ chatId: 1, 'readBy.userId': 1 }); // Find unread messages
messageSchema.index(
  { sender: 1, clientMessageId: 1 },
  { unique: true, sparse: true, partialFilterExpression: { clientMessageId: { $exists: true } } }
);

// Static method to get unread count for a user in a chat
messageSchema.statics.getUnreadCount = async function(chatId, userId) {
  return this.countDocuments({
    chatId,
    sender: { $ne: userId },
    'readBy.userId': { $ne: userId },
    isDeleted: false,
  });
};

// Static method to get latest messages
messageSchema.statics.getLatestMessages = function(chatId, limit = 50) {
  return this.find({
    chatId,
    isDeleted: false,
  })
    .sort({ createdAt: -1 })
    .limit(limit)
    .lean();
};

// Instance method for soft delete
messageSchema.methods.softDelete = async function() {
  this.isDeleted = true;
  this.content = '[deleted]';
  return this.save();
};

module.exports = mongoose.model('Message', messageSchema);
