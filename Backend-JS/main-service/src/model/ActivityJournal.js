const mongoose = require('mongoose');

const SOURCES = ['card_done', 'card_skipped', 'manual_log', 'ai_inferred'];

const activityJournalSchema = new mongoose.Schema(
  {
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    cropEntryId: { type: mongoose.Schema.Types.ObjectId, required: true, index: true },
    cropName: { type: String, required: true },

    verb: { type: String, required: true },
    chemical: { type: String },
    dose: { type: String },
    notes: { type: String, maxlength: 500 },

    source: { type: String, enum: SOURCES, required: true },

    cardItemId: { type: String },
    cardLocalDate: { type: String },

    imageUrl: { type: String },

    localDate: { type: String, required: true, index: true },
    timezone: { type: String, default: 'Asia/Kolkata' },

    occurredAt: { type: Date, default: Date.now, index: true },

    isDeleted: { type: Boolean, default: false, index: true },
  },
  { timestamps: true }
);

activityJournalSchema.index({ userId: 1, occurredAt: -1 });
activityJournalSchema.index({ userId: 1, cropEntryId: 1, occurredAt: -1 });
activityJournalSchema.index({ userId: 1, verb: 1, occurredAt: -1 });

activityJournalSchema.statics.SOURCES = SOURCES;

module.exports = mongoose.model('ActivityJournal', activityJournalSchema);
