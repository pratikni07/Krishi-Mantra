const mongoose = require("mongoose");
const { GROUP_LIMITS } = require('../utils/constants');

const groupSchema = new mongoose.Schema(
  {
    chatId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Chat",
      required: true,
      unique: true,
      index: true,
    },
    name: {
      type: String,
      required: true,
      maxlength: GROUP_LIMITS.MAX_NAME_LENGTH,
    },
    description: {
      type: String,
      maxlength: GROUP_LIMITS.MAX_DESCRIPTION_LENGTH,
    },
    photo: String,
    admin: [
      {
        type: String,
        required: true,
        index: true,
      },
    ],
    onlyAdminCanMessage: {
      type: Boolean,
      default: false,
    },
    inviteUrl: {
      type: String,
      unique: true,
      sparse: true,
      index: true,
    },
    memberCount: {
      type: Number,
      default: 0,
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
groupSchema.index({ admin: 1, isActive: 1 }); // Groups by admin
groupSchema.index({ memberCount: -1, isActive: 1 }); // Popular groups
groupSchema.index({ name: 'text', description: 'text' }); // Text search on groups
groupSchema.index({ createdAt: -1, isActive: 1 }); // Recent groups

// Validation for member count
groupSchema.pre("save", function (next) {
  if (this.memberCount > GROUP_LIMITS.MAX_MEMBERS) {
    next(new Error(`Group cannot have more than ${GROUP_LIMITS.MAX_MEMBERS} members`));
  }
  if (this.admin && this.admin.length > GROUP_LIMITS.MAX_ADMINS) {
    next(new Error(`Group cannot have more than ${GROUP_LIMITS.MAX_ADMINS} admins`));
  }
  next();
});

// Static method to find group by chat ID
groupSchema.statics.findByChatId = function(chatId) {
  return this.findOne({ chatId, isActive: true }).lean();
};

// Static method to find group by invite URL
groupSchema.statics.findByInviteUrl = function(inviteUrl) {
  return this.findOne({ inviteUrl, isActive: true }).lean();
};

// Static method to get groups where user is admin
groupSchema.statics.getAdminGroups = function(userId) {
  return this.find({ admin: userId, isActive: true })
    .sort({ updatedAt: -1 })
    .populate('chatId')
    .lean();
};

// Static method to get popular groups
groupSchema.statics.getPopularGroups = function(limit = 20) {
  return this.find({ isActive: true })
    .sort({ memberCount: -1 })
    .limit(limit)
    .lean();
};

// Static method to search groups
groupSchema.statics.searchGroups = function(query, limit = 20) {
  return this.find({
    $text: { $search: query },
    isActive: true,
  })
    .sort({ score: { $meta: 'textScore' } })
    .limit(limit)
    .lean();
};

// Instance method to add admin
groupSchema.methods.addAdmin = async function(userId) {
  if (this.admin.length >= GROUP_LIMITS.MAX_ADMINS) {
    throw new Error(`Group cannot have more than ${GROUP_LIMITS.MAX_ADMINS} admins`);
  }
  if (!this.admin.includes(userId)) {
    this.admin.push(userId);
    await this.save();
  }
  return this;
};

// Instance method to remove admin
groupSchema.methods.removeAdmin = async function(userId) {
  if (this.admin.length <= 1) {
    throw new Error('Group must have at least one admin');
  }
  this.admin = this.admin.filter(id => id !== userId);
  await this.save();
  return this;
};

// Instance method to update member count
groupSchema.methods.updateMemberCount = async function(count) {
  this.memberCount = count;
  await this.save();
  return this;
};

module.exports = mongoose.model("Group", groupSchema);
