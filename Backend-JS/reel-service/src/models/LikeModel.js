const mongoose = require("mongoose");

const LikeSchema = new mongoose.Schema(
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
  },
  {
    timestamps: true,
  }
);

LikeSchema.index({ reel: 1, userId: 1 }, { unique: true });

module.exports = mongoose.model("ReelLike", LikeSchema);
