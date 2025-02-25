const mongoose = require("mongoose");

const cropSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: true,
      index: true, // Index for faster search by name
    },
    scientificName: {
      type: String,
      index: true,
    },
    description: String,
    growingPeriod: {
      type: Number,
      required: true,
    },
    seasons: [
      {
        type: {
          type: String,
          required: true,
          enum: ["Kharif", "Rabi", "Zaid"], // Validation for season types
        },
        startMonth: {
          type: Number,
          required: true,
          min: 1,
          max: 12,
        },
        endMonth: {
          type: Number,
          required: true,
          min: 1,
          max: 12,
        },
      },
    ],
    imageUrl: String,
    status: {
      type: String,
      enum: ["active", "inactive"],
      default: "active",
      index: true,
    },
    createdAt: {
      type: Date,
      default: Date.now,
      index: true,
    },
  },
  {
    timestamps: true,
  }
);

// Compound index for efficient season queries
cropSchema.index({ "seasons.type": 1, "seasons.startMonth": 1 });

module.exports = mongoose.model("Crop", cropSchema);
