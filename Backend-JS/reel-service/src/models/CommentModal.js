const mongoose = require("mongoose");

const CommentSchema = new mongoose.Schema(
  {
    userId: {
      type: String,
      required: true,
    },
    userName: {
      type: String,
      required: true,
    },
    profilePhoto: {
      type: String,
    },
    reel: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Reel",
      required: true,
    },
    content: {
      type: String,
      required: true,
      trim: true,
    },
    parentComment: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "ReelComment",
      default: null,
    },
    likes: {
      count: {
        type: Number,
        default: 0,
      },
      users: [
        {
          type: mongoose.Schema.Types.ObjectId,
          ref: "User",
        },
      ],
    },
    replies: [
      {
        type: mongoose.Schema.Types.ObjectId,
        ref: "ReelComment",
      },
    ],
    depth: {
      type: Number,
      default: 0,
      max: 5,
    },
    isDeleted: {
      type: Boolean,
      default: false,
    },
  },
  {
    timestamps: true,
  }
);

CommentSchema.index({ reel: 1, createdAt: -1 });
CommentSchema.index({ parentComment: 1 });

const ReelComment = mongoose.model("ReelComment", CommentSchema);
module.exports = ReelComment;
