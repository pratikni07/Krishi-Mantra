const mongoose = require('mongoose');

/**
 * Subscription Plan Schema
 * Defines available subscription plans for Krishi Mantra
 * Designed for Indian farmers with affordable pricing
 */
const SubscriptionPlanSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: true,
      enum: ['KISAN', 'KISAN_PRO', 'KISAN_PLUS', 'KISAN_MEGA'],
    },
    displayName: {
      type: String,
      required: true,
    },
    displayNameHindi: {
      type: String,
      required: true,
    },
    description: {
      type: String,
      required: true,
    },
    descriptionHindi: {
      type: String,
      required: true,
    },
    // Pricing in INR (Indian Rupees)
    pricing: {
      monthly: {
        amount: { type: Number, required: true }, // in paise (100 paise = 1 INR)
        currency: { type: String, default: 'inr' },
        stripePriceId: { type: String },
      },
      yearly: {
        amount: { type: Number, required: true },
        currency: { type: String, default: 'inr' },
        stripePriceId: { type: String },
        savings: { type: Number, default: 0 }, // Percentage savings
      },
    },
    // Feature limits
    features: {
      // AI Crop Doctor limits
      aiMessagesPerDay: { type: Number, default: 5 },
      imageAnalysisPerDay: { type: Number, default: 2 },

      // Consultant chat limits
      consultantChatsPerDay: { type: Number, default: 10 },
      videoConsultationsPerMonth: { type: Number, default: 0 },

      // Content creation
      canCreatePosts: { type: Boolean, default: false },
      canCreateReels: { type: Boolean, default: false },

      // Marketplace
      marketplaceListings: { type: Number, default: 0 },
      featuredListings: { type: Boolean, default: false },

      // Notifications
      pushNotifications: { type: Boolean, default: true },
      smsNotifications: { type: Boolean, default: false },
      emailNotifications: { type: Boolean, default: false },

      // Ads
      adFree: { type: Boolean, default: false },
      reducedAds: { type: Number, default: 0 }, // Percentage reduction

      // Support
      prioritySupport: { type: Boolean, default: false },

      // Analytics
      analyticsAccess: { type: String, enum: ['none', 'basic', 'full'], default: 'none' },

      // Offline features
      offlineCropCalendar: { type: Boolean, default: false },

      // Feed features
      priorityFeedRecommendations: { type: Boolean, default: false },

      // ========== IoT FEATURES (Future Integration) ==========

      // Smart Water Pump / Irrigation Control
      iot: {
        // Water Pump Automation
        waterPump: {
          enabled: { type: Boolean, default: false },
          maxDevices: { type: Number, default: 0 }, // 0 = not allowed, -1 = unlimited
          schedulingEnabled: { type: Boolean, default: false },
          remoteControlEnabled: { type: Boolean, default: false },
          automationRulesLimit: { type: Number, default: 0 }, // Number of automation rules allowed
          waterUsageAnalytics: { type: Boolean, default: false },
          alertsEnabled: { type: Boolean, default: false },
        },

        // Crop Monitoring Sensors
        cropMonitoring: {
          enabled: { type: Boolean, default: false },
          maxSensors: { type: Number, default: 0 }, // 0 = not allowed, -1 = unlimited
          soilMoistureSensor: { type: Boolean, default: false },
          temperatureSensor: { type: Boolean, default: false },
          humiditySensor: { type: Boolean, default: false },
          lightSensor: { type: Boolean, default: false },
          phSensor: { type: Boolean, default: false },
          nutrientSensor: { type: Boolean, default: false },
          dataRefreshRateMinutes: { type: Number, default: 60 }, // How often data is refreshed
          historicalDataDays: { type: Number, default: 7 }, // Days of historical data stored
          alertsEnabled: { type: Boolean, default: false },
          aiRecommendations: { type: Boolean, default: false }, // AI-based crop recommendations
        },

        // Weather Station Integration
        weatherStation: {
          enabled: { type: Boolean, default: false },
          localWeatherData: { type: Boolean, default: false },
          forecastDays: { type: Number, default: 3 },
          rainPredictionAlerts: { type: Boolean, default: false },
          frostAlerts: { type: Boolean, default: false },
        },

        // General IoT Settings
        dataStorageDays: { type: Number, default: 30 }, // How long IoT data is stored
        apiAccessEnabled: { type: Boolean, default: false }, // API access for custom integrations
        webhooksEnabled: { type: Boolean, default: false }, // Webhook notifications
        maxWebhooks: { type: Number, default: 0 },
      },
    },
    // Plan order for display
    order: { type: Number, default: 0 },
    // Is plan active
    isActive: { type: Boolean, default: true },
    // Is default plan (free tier)
    isDefault: { type: Boolean, default: false },
  },
  {
    timestamps: true,
  }
);

/**
 * User Subscription Schema
 * Tracks individual user subscriptions
 */
const UserSubscriptionSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    planId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'SubscriptionPlan',
      required: true,
    },
    planName: {
      type: String,
      required: true,
      enum: ['KISAN', 'KISAN_PRO', 'KISAN_PLUS', 'KISAN_MEGA'],
    },
    // Stripe subscription details
    stripeCustomerId: {
      type: String,
      index: true,
    },
    stripeSubscriptionId: {
      type: String,
      index: true,
    },
    stripePriceId: {
      type: String,
    },
    // Subscription period
    billingCycle: {
      type: String,
      enum: ['monthly', 'yearly', 'lifetime'],
      default: 'monthly',
    },
    // Subscription status
    status: {
      type: String,
      enum: ['active', 'cancelled', 'expired', 'past_due', 'trialing', 'pending'],
      default: 'pending',
      index: true,
    },
    // Dates
    startDate: {
      type: Date,
      default: Date.now,
    },
    endDate: {
      type: Date,
      required: true,
      index: true,
    },
    cancelledAt: {
      type: Date,
    },
    // Trial period
    trialStart: {
      type: Date,
    },
    trialEnd: {
      type: Date,
    },
    // Payment details
    lastPaymentAmount: {
      type: Number, // in paise
    },
    lastPaymentDate: {
      type: Date,
    },
    nextPaymentDate: {
      type: Date,
    },
    // Auto-renewal
    autoRenew: {
      type: Boolean,
      default: true,
    },
    // Cancellation reason
    cancellationReason: {
      type: String,
    },
  },
  {
    timestamps: true,
  }
);

// Compound indexes for efficient queries
UserSubscriptionSchema.index({ userId: 1, status: 1 });
UserSubscriptionSchema.index({ endDate: 1, status: 1 });
UserSubscriptionSchema.index({ stripeSubscriptionId: 1 }, { sparse: true });

/**
 * Payment History Schema
 * Tracks all subscription payments
 */
const PaymentHistorySchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    subscriptionId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'UserSubscription',
      required: true,
    },
    // Stripe payment details
    stripePaymentIntentId: {
      type: String,
      index: true,
    },
    stripeInvoiceId: {
      type: String,
    },
    stripeChargeId: {
      type: String,
    },
    // Payment details
    amount: {
      type: Number, // in paise
      required: true,
    },
    currency: {
      type: String,
      default: 'inr',
    },
    // Payment status
    status: {
      type: String,
      enum: ['pending', 'succeeded', 'failed', 'refunded', 'cancelled'],
      default: 'pending',
    },
    // Payment method
    paymentMethod: {
      type: {
        type: String,
        enum: ['card', 'upi', 'netbanking', 'wallet'],
      },
      last4: String,
      brand: String,
      upiId: String,
    },
    // Description
    description: {
      type: String,
    },
    // Invoice URL
    invoiceUrl: {
      type: String,
    },
    receiptUrl: {
      type: String,
    },
    // Refund details
    refundedAmount: {
      type: Number,
      default: 0,
    },
    refundReason: {
      type: String,
    },
    refundedAt: {
      type: Date,
    },
    // Metadata
    metadata: {
      type: mongoose.Schema.Types.Mixed,
    },
  },
  {
    timestamps: true,
  }
);

PaymentHistorySchema.index({ userId: 1, createdAt: -1 });
PaymentHistorySchema.index({ stripePaymentIntentId: 1 }, { sparse: true });

/**
 * Usage Tracking Schema
 * Tracks daily usage of features for rate limiting
 */
const UsageTrackingSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    date: {
      type: String, // YYYY-MM-DD format
      required: true,
    },
    // AI usage
    aiMessagesUsed: {
      type: Number,
      default: 0,
    },
    imageAnalysisUsed: {
      type: Number,
      default: 0,
    },
    // Consultant chat usage
    consultantChatsUsed: {
      type: Number,
      default: 0,
    },
    // Video consultations (monthly tracking)
    videoConsultationsUsed: {
      type: Number,
      default: 0,
    },
    // Reset timestamps
    lastAiMessageAt: {
      type: Date,
    },
    lastImageAnalysisAt: {
      type: Date,
    },
    lastConsultantChatAt: {
      type: Date,
    },
  },
  {
    timestamps: true,
  }
);

// Compound index for daily lookups
UsageTrackingSchema.index({ userId: 1, date: 1 }, { unique: true });
UsageTrackingSchema.index({ date: 1 }); // For cleanup of old records

// Static method to get or create today's usage
UsageTrackingSchema.statics.getTodayUsage = async function (userId) {
  const today = new Date().toISOString().split('T')[0];

  let usage = await this.findOne({ userId, date: today });

  if (!usage) {
    usage = await this.create({
      userId,
      date: today,
    });
  }

  return usage;
};

// Method to increment usage
UsageTrackingSchema.methods.incrementUsage = async function (field) {
  const validFields = ['aiMessagesUsed', 'imageAnalysisUsed', 'consultantChatsUsed', 'videoConsultationsUsed'];

  if (!validFields.includes(field)) {
    throw new Error(`Invalid usage field: ${field}`);
  }

  this[field] += 1;
  this[`last${field.replace('Used', 'At').replace('ai', 'Ai').replace('image', 'Image').replace('consultant', 'Consultant').replace('video', 'Video')}`] = new Date();

  return this.save();
};

/**
 * IoT Add-on Schema
 * Defines available IoT add-ons that can be purchased separately
 * Pricing: Water Pump +₹100/month, Crop IoT +₹200/month, Bundle +₹350/month
 */
const IotAddonSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: true,
      enum: ['WATER_PUMP', 'CROP_IOT', 'IOT_BUNDLE'],
    },
    displayName: {
      type: String,
      required: true,
    },
    displayNameHindi: {
      type: String,
      required: true,
    },
    description: {
      type: String,
      required: true,
    },
    descriptionHindi: {
      type: String,
      required: true,
    },
    // Pricing in INR (paise)
    pricing: {
      monthly: {
        amount: { type: Number, required: true }, // in paise
        currency: { type: String, default: 'inr' },
        stripePriceId: { type: String },
      },
      yearly: {
        amount: { type: Number, required: true },
        currency: { type: String, default: 'inr' },
        stripePriceId: { type: String },
        savings: { type: Number, default: 0 },
      },
    },
    // Features included in this add-on
    features: {
      // Water Pump features
      waterPump: {
        enabled: { type: Boolean, default: false },
        maxDevices: { type: Number, default: 0 },
        schedulingEnabled: { type: Boolean, default: false },
        remoteControlEnabled: { type: Boolean, default: false },
        automationRulesLimit: { type: Number, default: 0 },
        waterUsageAnalytics: { type: Boolean, default: false },
        alertsEnabled: { type: Boolean, default: false },
      },
      // Crop IoT features
      cropMonitoring: {
        enabled: { type: Boolean, default: false },
        maxSensors: { type: Number, default: 0 },
        soilMoistureSensor: { type: Boolean, default: false },
        temperatureSensor: { type: Boolean, default: false },
        humiditySensor: { type: Boolean, default: false },
        lightSensor: { type: Boolean, default: false },
        phSensor: { type: Boolean, default: false },
        nutrientSensor: { type: Boolean, default: false },
        dataRefreshRateMinutes: { type: Number, default: 60 },
        historicalDataDays: { type: Number, default: 30 },
        alertsEnabled: { type: Boolean, default: false },
        aiRecommendations: { type: Boolean, default: false },
      },
      // Weather Station (included in bundle)
      weatherStation: {
        enabled: { type: Boolean, default: false },
        localWeatherData: { type: Boolean, default: false },
        forecastDays: { type: Number, default: 7 },
        rainPredictionAlerts: { type: Boolean, default: false },
        frostAlerts: { type: Boolean, default: false },
      },
    },
    // Bundle savings info
    bundleSavings: {
      type: Number, // Amount saved in paise
      default: 0,
    },
    // Display order
    order: { type: Number, default: 0 },
    isActive: { type: Boolean, default: true },
  },
  {
    timestamps: true,
  }
);

/**
 * User IoT Add-on Subscription Schema
 * Tracks individual user's IoT add-on subscriptions
 */
const UserIotAddonSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    addonId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'IotAddon',
      required: true,
    },
    addonName: {
      type: String,
      required: true,
      enum: ['WATER_PUMP', 'CROP_IOT', 'IOT_BUNDLE'],
    },
    // Stripe subscription details
    stripeCustomerId: {
      type: String,
      index: true,
    },
    stripeSubscriptionId: {
      type: String,
      index: true,
    },
    stripePriceId: {
      type: String,
    },
    // Subscription period
    billingCycle: {
      type: String,
      enum: ['monthly', 'yearly'],
      default: 'monthly',
    },
    // Subscription status
    status: {
      type: String,
      enum: ['active', 'cancelled', 'expired', 'past_due', 'pending'],
      default: 'pending',
      index: true,
    },
    // Dates
    startDate: {
      type: Date,
      default: Date.now,
    },
    endDate: {
      type: Date,
      required: true,
      index: true,
    },
    cancelledAt: {
      type: Date,
    },
    // Payment details
    lastPaymentAmount: {
      type: Number, // in paise
    },
    lastPaymentDate: {
      type: Date,
    },
    nextPaymentDate: {
      type: Date,
    },
    // Auto-renewal
    autoRenew: {
      type: Boolean,
      default: true,
    },
    // Linked devices
    linkedDevices: [
      {
        deviceId: { type: String },
        deviceType: { type: String, enum: ['water_pump', 'soil_sensor', 'weather_station'] },
        deviceName: { type: String },
        addedAt: { type: Date, default: Date.now },
        isActive: { type: Boolean, default: true },
      },
    ],
  },
  {
    timestamps: true,
  }
);

// Compound indexes
UserIotAddonSchema.index({ userId: 1, status: 1 });
UserIotAddonSchema.index({ userId: 1, addonName: 1 });
UserIotAddonSchema.index({ endDate: 1, status: 1 });

// Check if user has active IoT addon
UserIotAddonSchema.statics.hasActiveAddon = async function (userId, addonName) {
  const addon = await this.findOne({
    userId,
    addonName,
    status: 'active',
    endDate: { $gt: new Date() },
  });
  return !!addon;
};

// Get all active addons for user
UserIotAddonSchema.statics.getActiveAddons = async function (userId) {
  return this.find({
    userId,
    status: 'active',
    endDate: { $gt: new Date() },
  }).populate('addonId');
};

const SubscriptionPlan = mongoose.model('SubscriptionPlan', SubscriptionPlanSchema);
const UserSubscription = mongoose.model('UserSubscription', UserSubscriptionSchema);
const PaymentHistory = mongoose.model('PaymentHistory', PaymentHistorySchema);
const UsageTracking = mongoose.model('UsageTracking', UsageTrackingSchema);
const IotAddon = mongoose.model('IotAddon', IotAddonSchema);
const UserIotAddon = mongoose.model('UserIotAddon', UserIotAddonSchema);

module.exports = {
  SubscriptionPlan,
  UserSubscription,
  PaymentHistory,
  UsageTracking,
  IotAddon,
  UserIotAddon,
};
