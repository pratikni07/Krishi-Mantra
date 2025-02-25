const mongoose = require("mongoose");

const UserDetailSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
    },
    address: {
      type: String,
      trim: true,
    },
    location: {
      type: {
        type: String, // Must be 'Point'
        enum: ["Point"],
        required: true,
      },
      coordinates: {
        type: [Number], // [longitude, latitude]
        required: true,
      },
    },
    interests: [
      {
        type: String,
        trim: true,
      },
    ],
    profilePic: {
      type: String,
      trim: true,
    },
    followers: [
      {
        type: mongoose.Schema.Types.ObjectId,
        ref: "User",
      },
    ],
    followings: [
      {
        type: mongoose.Schema.Types.ObjectId,
        ref: "User",
      },
    ],
    blockedUsers: [
      {
        type: mongoose.Schema.Types.ObjectId,
        ref: "User",
      },
    ],
    subscription: {
      type: {
        type: String, // Directly define 'type' as a String
        enum: ["FREE", "PRIME", "MEGA"],
        default: "FREE",
      },
      transactionDetails: {
        type: mongoose.Schema.Types.Mixed,
      },
      endDate: Date,
      purchasedDate: Date,
    },
    experience: {
      type: Number,
      default: 0,
    },
    company: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Company",
    },
    rating: {
      type: Number,
      default: 3,
    },
  },
  {
    timestamps: true,
  }
);

UserDetailSchema.index({ location: "2dsphere" });

module.exports = mongoose.model("UserDetail", UserDetailSchema);
