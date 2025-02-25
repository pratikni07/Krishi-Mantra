const mongoosePaginate = require("mongoose-paginate-v2");
const mongoose = require("mongoose");
const CommentSchema = new mongoose.Schema(
  {
    userId: {
      type: String,
    },
    userName: {
      type: String,
    },
    profilePhoto: {
      type: String,
    },
    feed: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Feed",
    },
    content: {
      type: String,
      required: true,
      trim: true,
    },
    parentComment: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Comment",
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
        ref: "Comment",
      },
    ],
    depth: {
      type: Number,
      default: 0,
      max: 5,
    },
    reports: [
      {
        userId: {
          type: mongoose.Schema.Types.ObjectId,
          ref: "User",
        },
        reason: String,
        createdAt: {
          type: Date,
          default: Date.now,
        },
      },
    ],
    isDeleted: {
      type: Boolean,
      default: false,
    },
  },
  {
    timestamps: true,
  }
);

// Integrate the pagination plugin with the schema
CommentSchema.plugin(mongoosePaginate);

// Indexes for performance
CommentSchema.index({ feed: 1, createdAt: -1 });
CommentSchema.index({ parentComment: 1 });

module.exports = mongoose.model("Comment", CommentSchema);
