const mongoose = require("mongoose");

const reelAdSchema = new mongoose.Schema({
  title: {
    type: String,
    required: true,
  },
  videoUrl: {
    type: String,
    required: true,
  },
  popUpView: {
    enabled: {
      type: Boolean,
      default: false,
    },
    productId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "MarketplaceProduct",
    },
    type: {
      type: String,
      enum: ["marketplace", "posts"],
    },
    image: {
      type: String,
    },
    popupTitle: {
      type: String,
    },
  },
  impressions: {
    type: Number,
    default: 0,
  },
  views: {
    type: Number,
    default: 0,
  },
  viewTracking: [
    {
      userId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: "User",
      },
      viewedAt: {
        type: Date,
        default: Date.now,
      },
      duration: {
        type: Number,
        default: 0,
      },
    },
  ],
  createdAt: {
    type: Date,
    default: Date.now,
  },
});

module.exports = mongoose.model("ReelAds", reelAdSchema);
