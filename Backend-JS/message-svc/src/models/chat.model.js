const mongoose = require("mongoose");

const chatSchema = new mongoose.Schema(
  {
    type: {
      type: String,
      enum: ["direct", "group"],
      required: true,
    },
    participants: [
      {
        userId: {
          type: String,
          require: true,
        },
        userName: {
          type: String,
          require: true,
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
    unreadCount: {
      type: Map,
      of: Number,
      default: new Map(),
    },
  },
  { timestamps: true }
);

chatSchema.index({ participants: 1 });
module.exports = mongoose.model("Chat", chatSchema);
