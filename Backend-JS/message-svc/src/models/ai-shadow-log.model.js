const mongoose = require('mongoose');

/**
 * Records the shadow-mode comparison between the active provider's response
 * and the proposed-active response. Used during ramp stages to validate a
 * provider switch before flipping production traffic.
 */
const aiShadowLogSchema = new mongoose.Schema(
  {
    chatId: { type: mongoose.Schema.Types.ObjectId, ref: 'AIChat', index: true },
    userId: { type: String, index: true },
    intent: { type: String },
    primary: {
      provider: String,
      model: String,
      latencyMs: Number,
      tokens: {
        prompt: Number,
        cached: Number,
        completion: Number,
      },
      costUsd: Number,
      sample: String, // first ~200 chars of response (truncated)
      error: String,
    },
    shadow: {
      provider: String,
      model: String,
      latencyMs: Number,
      tokens: {
        prompt: Number,
        cached: Number,
        completion: Number,
      },
      costUsd: Number,
      sample: String,
      error: String,
    },
    diff: {
      sampleSimilarity: Number, // 0..1, simple Jaccard on tokens
      latencyDeltaMs: Number,
      costDeltaUsd: Number,
    },
    expiresAt: { type: Date, index: { expires: 0 } },
  },
  { timestamps: true }
);

aiShadowLogSchema.index({ createdAt: -1 });

module.exports = mongoose.model('AIShadowLog', aiShadowLogSchema);
