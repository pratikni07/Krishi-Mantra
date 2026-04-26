const mongoose = require('mongoose');

const aiProviderAuditSchema = new mongoose.Schema(
  {
    configId: { type: mongoose.Schema.Types.ObjectId, ref: 'AiProviderConfig', index: true },
    provider: { type: String, enum: ['openai', 'vertex'], required: true, index: true },
    action: {
      type: String,
      enum: ['create', 'update', 'validate', 'activate', 'deactivate', 'rotate', 'delete'],
      required: true,
    },
    actor: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    diff: { type: mongoose.Schema.Types.Mixed },
    at: { type: Date, default: Date.now, index: true },
    ip: String,
    userAgent: String,
  },
  { timestamps: false }
);

aiProviderAuditSchema.index({ configId: 1, at: -1 });

module.exports = mongoose.model('AiProviderAudit', aiProviderAuditSchema);
