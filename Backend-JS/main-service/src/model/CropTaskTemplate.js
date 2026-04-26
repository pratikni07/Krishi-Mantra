const mongoose = require('mongoose');

const STAGES = [
  'pre_sowing',
  'germination',
  'seedling',
  'vegetative',
  'flowering',
  'fruiting',
  'maturity',
  'harvested',
];

const VERBS = [
  'spray_fungicide',
  'spray_insecticide',
  'spray_herbicide',
  'fertilize',
  'irrigate',
  'scout',
  'weed',
  'prune',
  'stake',
  'thin',
  'harvest_check',
  'soil_test',
  'mulch',
];

const URGENCIES = ['low', 'normal', 'high', 'urgent'];

const localizedStringsSchema = new mongoose.Schema(
  {
    title: String,
    detail: String,
    safetyNote: String,
    weatherClauses: { type: mongoose.Schema.Types.Mixed, default: {} },
  },
  { _id: false }
);

const cropTaskTemplateSchema = new mongoose.Schema(
  {
    cropId: { type: mongoose.Schema.Types.ObjectId, ref: 'Crop', required: true, index: true },
    cropName: { type: String, required: true, index: true },

    stage: { type: String, enum: STAGES, required: true, index: true },

    daysFromSowingMin: { type: Number, required: true, min: 0 },
    daysFromSowingMax: { type: Number, required: true, min: 0 },

    verb: { type: String, enum: VERBS, required: true },

    titleTemplate: { type: String, required: true, maxlength: 200 },
    detailTemplate: { type: String, maxlength: 600 },

    chemical: { type: String },
    dose: { type: String },
    safetyNote: { type: String, maxlength: 200 },

    urgency: { type: String, enum: URGENCIES, default: 'normal' },

    weather: {
      requiresDryDays: { type: Number, default: 0 },
      maxRainfallMmTomorrow: { type: Number },
      minTempC: { type: Number },
      maxTempC: { type: Number },
      requiresMoistSoil: { type: Boolean, default: false },
    },

    cooldownDays: { type: Number, default: 7 },

    seasons: [{ type: String, enum: ['Kharif', 'Rabi', 'Zaid'] }],
    regions: [String],

    // Per-language curated translations. Falls back to titleTemplate/detailTemplate
    // (assumed EN) when a language is missing.
    translations: { type: Map, of: localizedStringsSchema, default: {} },

    isActive: { type: Boolean, default: true, index: true },
    sourceRefs: [String],

    // Provenance tag — "calendar_seed" for seeded rows pending agronomy signoff.
    seedSource: { type: String },
  },
  { timestamps: true }
);

cropTaskTemplateSchema.index({ cropId: 1, stage: 1, isActive: 1 });
cropTaskTemplateSchema.index({ cropName: 'text' });

cropTaskTemplateSchema.statics.STAGES = STAGES;
cropTaskTemplateSchema.statics.VERBS = VERBS;
cropTaskTemplateSchema.statics.URGENCIES = URGENCIES;

module.exports = mongoose.model('CropTaskTemplate', cropTaskTemplateSchema);
