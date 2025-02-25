// models/Activity.js
const mongoose = require("mongoose");

const activitySchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: true,
      index: true,
    },
    description: String,
    category: {
      type: String,
      required: true,
      index: true,
      enum: ["Pre-planting", "Planting", "Maintenance", "Harvest"],
    },
    requiredTools: [String],
    precautions: [String],
    status: {
      type: String,
      enum: ["active", "inactive"],
      default: "active",
      index: true,
    },
  },
  {
    timestamps: true,
  }
);

module.exports = mongoose.model("Activity", activitySchema);
