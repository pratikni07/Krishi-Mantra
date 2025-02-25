const mongoose = require("mongoose");

const HomeScreenSchema = new mongoose.Schema({
  title: {
    type: String,
  },
  content: {
    type: String,
  },
  dirURL: {
    type: String,
  },
  prority: {
    type: Number,
    default: 1,
  },
  createdAt: {
    type: Date,
    default: Date.now,
  },
});

module.exports = mongoose.model("HomeScreenAds", HomeScreenSchema);
