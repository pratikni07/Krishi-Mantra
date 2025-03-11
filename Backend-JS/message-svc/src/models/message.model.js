const mongoose = require("mongoose");

const messageSchema = new mongoose.Schema(
  {
    chatId: {
      type: mongoose.Schema.Types.ObjectId,
      required: true,
      ref: "Chat",
    },
    sender: {
      type: String,
      required: true,
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
    },
    mediaType: {
      type: String,
      enum: ["text", "image", "video", "text_image", "text_video"],
      default: "text",
    },
    mediaUrl: {
      type: String,
    },
    mediaMetadata: {
      type: Map,
      of: String,
      default: {},
    },
    readBy: [
      {
        userId: String,
        userName: String,
        profilePhoto: String,
        readAt: Date,
      },
    ],
    deliveredTo: [
      {
        userId: String,
        userName: String,
        profilePhoto: String,
        deliveredAt: Date,
      },
    ],
    isDeleted: {
      type: Boolean,
      default: false,
    },
  },
  { timestamps: true }
);

messageSchema.index({ chatId: 1, createdAt: -1 });
module.exports = mongoose.model("Message", messageSchema);
