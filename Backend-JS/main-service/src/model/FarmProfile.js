const mongoose = require('mongoose');
const { farmProfile: fingerprintFarmProfile } = require('../utils/fingerprint');

const cropEntrySchema = new mongoose.Schema(
  {
    cropId: { type: mongoose.Schema.Types.ObjectId, ref: 'Crop', required: true, index: true },
    cropName: { type: String, required: true },
    variety: { type: String, trim: true },
    area: { type: Number, required: true, min: 0 },
    areaUnit: { type: String, enum: ['acre', 'hectare', 'bigha', 'gunta'], default: 'acre' },
    sowingDate: { type: Date, required: true, index: true },
    expectedHarvestDate: { type: Date },
    growthStage: {
      type: String,
      enum: [
        'pre_sowing',
        'germination',
        'seedling',
        'vegetative',
        'flowering',
        'fruiting',
        'maturity',
        'harvested',
      ],
      default: 'vegetative',
    },
    plantingMethod: {
      type: String,
      enum: ['direct_sowing', 'transplanting', 'broadcasting', 'line_sowing', 'other'],
    },
    irrigationMethod: {
      type: String,
      enum: ['rainfed', 'drip', 'sprinkler', 'flood', 'furrow', 'other'],
    },
    notes: { type: String, maxlength: 500 },
    isActive: { type: Boolean, default: true },
  },
  { timestamps: true, _id: true }
);

const farmProfileSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      unique: true,
      index: true,
    },

    age: { type: Number, min: 10, max: 120 },
    gender: { type: String, enum: ['male', 'female', 'other', 'prefer_not_to_say'] },
    preferredLanguage: { type: String, default: 'en' },

    location: {
      type: {
        type: String,
        enum: ['Point'],
        default: 'Point',
      },
      coordinates: { type: [Number], default: undefined },
    },
    address: {
      village: String,
      taluka: String,
      district: { type: String, index: true },
      state: { type: String, index: true },
      country: { type: String, default: 'India' },
      pincode: String,
    },

    totalArea: { type: Number, min: 0 },
    totalAreaUnit: { type: String, enum: ['acre', 'hectare', 'bigha', 'gunta'], default: 'acre' },
    ownership: { type: String, enum: ['owned', 'leased', 'shared', 'mixed'] },
    soilTypes: [
      {
        type: String,
        enum: ['sandy', 'loam', 'clay', 'black', 'red', 'laterite', 'alluvial', 'silty'],
      },
    ],
    irrigationSources: [
      {
        type: String,
        enum: ['borewell', 'canal', 'river', 'pond', 'rainfed', 'drip', 'sprinkler'],
      },
    ],
    experienceYears: { type: Number, min: 0, default: 0 },

    crops: [cropEntrySchema],

    profileFingerprint: { type: String, index: true },
    profileVersion: { type: Number, default: 1 },
    onboardingStatus: {
      type: String,
      enum: ['not_started', 'in_progress', 'completed'],
      default: 'not_started',
    },

    timezone: { type: String, default: 'Asia/Kolkata' },

    // Daily action card + push notification preferences. Defaults match the
    // post-launch behavior; user can opt out from settings.
    notifyPrefs: {
      morningCardEnabled: { type: Boolean, default: true },
      morningCardLocalTime: { type: String, default: '07:00' },
      weatherAlertsEnabled: { type: Boolean, default: true },
      preferredChannel: { type: String, enum: ['push', 'sms', 'none'], default: 'push' },
    },
  },
  { timestamps: true }
);

farmProfileSchema.index({ location: '2dsphere' });
farmProfileSchema.index({ 'address.state': 1, 'address.district': 1 });

farmProfileSchema.pre('save', function (next) {
  if (this.isModified() && !this.isNew) this.profileVersion += 1;
  this.profileFingerprint = fingerprintFarmProfile(this);
  next();
});

module.exports = mongoose.model('FarmProfile', farmProfileSchema);
