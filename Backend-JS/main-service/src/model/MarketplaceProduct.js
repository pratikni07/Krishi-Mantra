const mongoose = require("mongoose");

// Define reply schema first (for nested comments)
const replySchema = new mongoose.Schema(
  {
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    userName: {
      type: String,
      required: true,
    },
    userProfilePhoto: {
      type: String,
    },
    text: {
      type: String,
      required: true,
      trim: true,
    },
  },
  { timestamps: true }
);

// Parent comment schema
const commentSchema = new mongoose.Schema(
  {
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    userName: {
      type: String,
      required: true,
    },
    userProfilePhoto: {
      type: String,
    },
    text: {
      type: String,
      required: true,
      trim: true,
    },
    replies: [replySchema]
  },
  { timestamps: true }
);

const MediaSchema = new mongoose.Schema({
  type: {
    type: String,
    enum: ["image", "video"],
    required: true,
  },
  url: {
    type: String,
    required: true,
  },
  isYoutubeVideo: {
    type: Boolean,
    default: false,
  }
});

const sellerInfoSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "User",
    required: true,
  },
  userName: {
    type: String,
    required: true,
  },
  profilePhoto: {
    type: String,
  },
  contactNumber: {
    type: String,
    required: true,
  }
});

const MarketplaceProductSchema = new mongoose.Schema(
  {
    title: {
      type: String,
      required: true,
      trim: true,
    },
    shortDescription: {
      type: String,
      required: true,
      trim: true,
    },
    detailedDescription: {
      type: String,
      required: true,
    },
    media: [MediaSchema],
    priceRange: {
      min: {
        type: Number,
        required: true,
      },
      max: {
        type: Number,
      },
      currency: {
        type: String,
        default: "INR",
      }
    },
    sellerInfo: sellerInfoSchema,
    category: {
      type: String,
      required: true,
      trim: true,
    },
    condition: {
      type: String,
      enum: ["New", "Used", "Refurbished"],
      default: "New",
    },
    location: {
      type: String,
      trim: true,
    },
    views: {
      type: Number,
      default: 0,
    },
    rating: {
      type: Number,
      default: 4,
      min: 1,
      max: 5
    },
    comments: [commentSchema],
    status: {
      type: String,
      enum: ["active", "sold", "unavailable"],
      default: "active",
    },
    tags: [{
      type: String,
      trim: true
    }],
  },
  {
    timestamps: true,
  }
);

// Create an index for tags to improve search performance
MarketplaceProductSchema.index({ tags: 1 });
MarketplaceProductSchema.index({ title: 'text', shortDescription: 'text', detailedDescription: 'text' });

module.exports = mongoose.model("MarketplaceProduct", MarketplaceProductSchema); 