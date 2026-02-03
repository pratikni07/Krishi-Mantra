const mongoose = require("mongoose");

const chatSchema = new mongoose.Schema(
  {
    type: {
      type: String,
      enum: ["direct", "group"],
      required: true,
      index: true,
    },
    participants: [
      {
        userId: {
          type: String,
          required: true,
          index: true,
        },
        userName: {
          type: String,
          required: true,
        },
        profilePhoto: {
          type: String,
          default:
            "https://media.istockphoto.com/id/1269841295/photo/side-view-of-a-senior-farmer-standing-in-corn-field-examining-crop-at-sunset.jpg?s=612x612&w=0&k=20&c=Lheldd6VVGQGxrgC8_mwUTLxXGg9v8Y6abjmYLhLHug=",
        },
      },
    ],
    lastMessage: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Message",
    },
    lastMessageAt: {
      type: Date,
      default: Date.now,
      index: true,
    },
    unreadCount: {
      type: Map,
      of: Number,
      default: new Map(),
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
chatSchema.index({ 'participants.userId': 1, lastMessageAt: -1 }); // Get user's chats sorted by recent
chatSchema.index({ 'participants.userId': 1, type: 1 }); // Filter user's chats by type
chatSchema.index({ type: 1, updatedAt: -1 }); // Get chats by type
chatSchema.index({ 'participants.userId': 1, isActive: 1, lastMessageAt: -1 }); // Active chats for user

// Static method to find direct chat between two users
chatSchema.statics.findDirectChat = async function(userId1, userId2) {
  return this.findOne({
    type: 'direct',
    'participants.userId': { $all: [userId1, userId2] },
    $expr: { $eq: [{ $size: '$participants' }, 2] },
  }).lean();
};

// Static method to get user's recent chats with pagination
chatSchema.statics.getUserChats = function(userId, { page = 1, limit = 20 } = {}) {
  const skip = (page - 1) * limit;
  return this.find({
    'participants.userId': userId,
    isActive: true,
  })
    .sort({ lastMessageAt: -1 })
    .skip(skip)
    .limit(limit)
    .populate('lastMessage')
    .lean();
};

// Static method to update last message
chatSchema.statics.updateLastMessage = async function(chatId, messageId) {
  return this.findByIdAndUpdate(
    chatId,
    {
      lastMessage: messageId,
      lastMessageAt: new Date(),
    },
    { new: true }
  );
};

// Instance method to increment unread count
chatSchema.methods.incrementUnread = async function(userId) {
  const current = this.unreadCount.get(userId) || 0;
  this.unreadCount.set(userId, current + 1);
  return this.save();
};

// Instance method to clear unread count
chatSchema.methods.clearUnread = async function(userId) {
  this.unreadCount.set(userId, 0);
  return this.save();
};

module.exports = mongoose.model("Chat", chatSchema);
