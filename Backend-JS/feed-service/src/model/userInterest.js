const mongoose = require("mongoose");

const userInterestSchema = new mongoose.Schema({
  userId: {
    type: String,
    required: true,
  },
  interests: [
    {
      tag: String,
      score: {
        type: Number,
        default: 1,
      },
      lastInteraction: {
        type: Date,
        default: Date.now,
      },
    },
  ],
  location: {
    latitude: Number,
    longitude: Number,
  },
  recentViews: [
    {
      feedId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: "Feed",
      },
      viewedAt: {
        type: Date,
        default: Date.now,
      },
    },
  ],
});

module.exports = mongoose.model("UserInterest", userInterestSchema);
