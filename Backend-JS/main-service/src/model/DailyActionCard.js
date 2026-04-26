const mongoose = require('mongoose');

const URGENCIES = ['low', 'normal', 'high', 'urgent'];
const STATUSES = ['pending', 'done', 'skipped', 'snoozed'];
const SOURCES = ['template', 'ai', 'weather_alert', 'manual'];

const actionItemSchema = new mongoose.Schema(
  {
    itemId: { type: String, required: true },

    cropEntryId: { type: mongoose.Schema.Types.ObjectId, required: true },
    cropName: { type: String, required: true },
    cropVariety: { type: String },

    templateId: { type: mongoose.Schema.Types.ObjectId, ref: 'CropTaskTemplate' },
    source: { type: String, enum: SOURCES, required: true },

    verb: { type: String, required: true },
    title: { type: String, required: true },
    detail: { type: String },
    chemical: { type: String },
    dose: { type: String },
    safetyNote: { type: String },

    urgency: { type: String, enum: URGENCIES, default: 'normal' },
    rationaleTags: [String],

    status: {
      type: String,
      enum: STATUSES,
      default: 'pending',
      index: true,
    },
    statusUpdatedAt: { type: Date },
    snoozeUntil: { type: Date },
    skipReason: { type: String },
    notes: { type: String, maxlength: 500 },
  },
  { _id: false }
);

const dailyActionCardSchema = new mongoose.Schema(
  {
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },

    localDate: { type: String, required: true },
    timezone: { type: String, default: 'Asia/Kolkata' },

    items: { type: [actionItemSchema], default: [] },

    generatedAt: { type: Date, default: Date.now },
    weatherSnapshotBucket: String,
    farmProfileVersion: Number,
    generator: { type: String, enum: ['cron', 'on_demand'], default: 'cron' },

    aiUsageUsd: { type: Number, default: 0 },

    // What the farmer noted today on the card (text + photos). Carries forward
    // as the highest-priority context for tomorrow's AI builder. `acknowledged`
    // flips to true once the next-day generator has consumed it.
    farmerInput: {
      text: { type: String, maxlength: 500 },
      imageUrls: { type: [String], default: [] },
      voiceUrl: { type: String },
      submittedAt: { type: Date },
      acknowledged: { type: Boolean, default: false },
    },

    // Provenance + metrics for the AI-first builder path.
    aiBuilder: {
      used: { type: Boolean, default: false },        // was AI invoked at all?
      provider: { type: String },                      // "vertex" | "openai"
      model: { type: String },
      itemsAccepted: { type: Number, default: 0 },     // valid AI items kept
      itemsRejected: { type: Number, default: 0 },     // dropped by validator
      imageCount: { type: Number, default: 0 },        // images sent to AI
      latencyMs: { type: Number },
      costUsd: { type: Number, default: 0 },
      fallbackToRule: { type: Boolean, default: false },
      error: { type: String },
    },

    expiresAt: { type: Date, index: { expires: 0 } },
  },
  { timestamps: true }
);

dailyActionCardSchema.index({ userId: 1, localDate: -1 }, { unique: true });

dailyActionCardSchema.statics.URGENCIES = URGENCIES;
dailyActionCardSchema.statics.STATUSES = STATUSES;
dailyActionCardSchema.statics.SOURCES = SOURCES;

module.exports = mongoose.model('DailyActionCard', dailyActionCardSchema);
