const mongoose = require("mongoose");

const cropCalendarSchema = new mongoose.Schema(
  {
    cropId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Crop",
      required: true,
      index: true,
    },
    month: {
      type: Number,
      required: true,
      min: 1,
      max: 12,
      index: true,
    },
    growthStage: {
      type: String,
      required: true,
    },
    activities: [
      {
        activityId: {
          type: mongoose.Schema.Types.ObjectId,
          ref: "Activity",
          required: true,
        },
        timing: {
          week: {
            type: Number,
            required: true,
            min: 1,
            max: 4,
          },
          recommendedTime: {
            type: String,
            enum: ["Morning", "Afternoon", "Evening", "Any"],
          },
        },
        instructions: String,
        importance: {
          type: String,
          enum: ["Critical", "Important", "Optional"],
        },
      },
    ],
    weatherConsiderations: {
      idealTemperature: {
        min: Number,
        max: Number,
      },
      rainfall: String,
      humidity: String,
    },
    possibleIssues: [
      {
        problem: String,
        solution: String,
        preventiveMeasures: [String],
      },
    ],
    expectedOutcomes: {
      growth: String,
      signs: [String],
    },
    tips: [String],
    nextMonthPreparation: [String],
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

// Compound index for efficient calendar queries
cropCalendarSchema.index({ cropId: 1, month: 1 });

module.exports = mongoose.model("CropCalendar", cropCalendarSchema);
