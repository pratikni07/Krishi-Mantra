// models/Region.js
const mongoose = require("mongoose");

const monthlyAdjustmentSchema = new mongoose.Schema({
  month: {
    type: Number,
    required: [true, "Month is required"],
    min: [1, "Month must be between 1 and 12"],
    max: [12, "Month must be between 1 and 12"],
  },
  adjustedTiming: {
    startWeek: {
      type: Number,
      required: [true, "Start week is required"],
      min: [1, "Week must be between 1 and 4"],
      max: [4, "Week must be between 1 and 4"],
    },
    endWeek: {
      type: Number,
      required: [true, "End week is required"],
      min: [1, "Week must be between 1 and 4"],
      max: [4, "Week must be between 1 and 4"],
    },
  },
  modifiedInstructions: {
    type: String,
    required: [true, "Modified instructions are required"],
    trim: true,
    maxlength: [500, "Modified instructions cannot exceed 500 characters"],
  },
  localConsiderations: [
    {
      type: String,
      trim: true,
      maxlength: [200, "Local consideration cannot exceed 200 characters"],
    },
  ],
});

const cropCalendarModificationSchema = new mongoose.Schema({
  cropCalendarId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "CropCalendar",
    required: [true, "Crop calendar reference is required"],
    index: true,
  },
  monthlyAdjustments: [monthlyAdjustmentSchema],
  status: {
    type: String,
    enum: ["active", "pending", "inactive"],
    default: "active",
  },
  lastUpdated: {
    type: Date,
    default: Date.now,
  },
});

const weatherPatternSchema = new mongoose.Schema({
  season: {
    type: String,
    required: true,
    enum: ["Summer", "Winter", "Monsoon", "Spring", "Autumn"],
  },
  months: [
    {
      type: Number,
      min: 1,
      max: 12,
    },
  ],
  averageTemperature: {
    min: Number,
    max: Number,
  },
  averageRainfall: Number,
  averageHumidity: Number,
});

const soilTypeSchema = new mongoose.Schema({
  name: {
    type: String,
    required: true,
    trim: true,
  },
  characteristics: [
    {
      type: String,
      trim: true,
    },
  ],
  suitableCrops: [
    {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Crop",
    },
  ],
});

const regionSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: [true, "Region name is required"],
      trim: true,
      maxlength: [100, "Region name cannot exceed 100 characters"],
      index: true,
    },
    state: {
      type: String,
      required: [true, "State is required"],
      trim: true,
      index: true,
    },
    country: {
      type: String,
      required: [true, "Country is required"],
      trim: true,
      index: true,
    },
    coordinates: {
      latitude: {
        type: Number,
        required: [true, "Latitude is required"],
        min: [-90, "Latitude must be between -90 and 90"],
        max: [90, "Latitude must be between -90 and 90"],
      },
      longitude: {
        type: Number,
        required: [true, "Longitude is required"],
        min: [-180, "Longitude must be between -180 and 180"],
        max: [180, "Longitude must be between -180 and 180"],
      },
    },
    climateType: {
      type: String,
      required: [true, "Climate type is required"],
      enum: {
        values: [
          "Tropical",
          "Subtropical",
          "Mediterranean",
          "Temperate",
          "Continental",
          "Arid",
          "Semi-arid",
          "Alpine",
        ],
        message: "{VALUE} is not a valid climate type",
      },
    },
    elevation: {
      type: Number,
      required: [true, "Elevation is required"],
      min: [-500, "Elevation cannot be less than -500 meters"],
      max: [9000, "Elevation cannot exceed 9000 meters"],
    },
    weatherPatterns: [weatherPatternSchema],
    soilTypes: [soilTypeSchema],
    cropCalendarModifications: [cropCalendarModificationSchema],
    majorCrops: [
      {
        type: mongoose.Schema.Types.ObjectId,
        ref: "Crop",
      },
    ],
    regionalGuidelines: [
      {
        title: {
          type: String,
          required: true,
          trim: true,
        },
        description: {
          type: String,
          required: true,
          trim: true,
        },
        applicableSeasons: [
          {
            type: String,
            enum: ["Kharif", "Rabi", "Zaid"],
          },
        ],
      },
    ],
    status: {
      type: String,
      enum: ["active", "inactive"],
      default: "active",
      index: true,
    },
    metadata: {
      createdBy: {
        type: String,
        required: true,
      },
      lastUpdatedBy: {
        type: String,
        required: true,
      },
      version: {
        type: Number,
        default: 1,
      },
    },
  },
  {
    timestamps: true,
  }
);

// Indexes
regionSchema.index({ name: 1, state: 1, country: 1 }, { unique: true });
regionSchema.index({ "coordinates.latitude": 1, "coordinates.longitude": 1 });
regionSchema.index({ climateType: 1 });
regionSchema.index({ status: 1, createdAt: -1 });

// Virtual for full location name
regionSchema.virtual("fullLocation").get(function () {
  return `${this.name}, ${this.state}, ${this.country}`;
});

// Middleware to update metadata
regionSchema.pre("save", function (next) {
  if (this.isModified()) {
    this.metadata.version += 1;
  }
  next();
});

// Instance method to get suitable crops
regionSchema.methods.getSuitableCrops = function () {
  return this.soilTypes.reduce((crops, soilType) => {
    return [...new Set([...crops, ...soilType.suitableCrops])];
  }, []);
};

// Static method to find regions by climate type
regionSchema.statics.findByClimate = function (climateType) {
  return this.find({ climateType, status: "active" })
    .select("name state country weatherPatterns")
    .populate("majorCrops");
};

// Query helper
regionSchema.query.active = function () {
  return this.where({ status: "active" });
};

const Region = mongoose.model("Region", regionSchema);

module.exports = Region;
