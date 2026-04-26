const mongoose = require('mongoose');

const encryptedBlobSchema = new mongoose.Schema(
  {
    iv: { type: String, required: true },
    tag: { type: String, required: true },
    ciphertext: { type: String, required: true },
    kekAlias: { type: String },
  },
  { _id: false }
);

const credentialsSchema = new mongoose.Schema(
  {
    type: {
      type: String,
      enum: ['api_key', 'service_account_json', 'wif'],
      required: true,
    },
    payload: { type: encryptedBlobSchema, required: true },
    fingerprint: { type: String, required: true },
    lastRotatedAt: { type: Date, default: Date.now },
  },
  { _id: false }
);

const aiProviderConfigSchema = new mongoose.Schema(
  {
    provider: { type: String, enum: ['openai', 'vertex'], required: true, index: true },
    displayName: { type: String, required: true },

    models: {
      chat: { type: String, required: true },
      vision: { type: String, required: true },
      embed: { type: String, required: true },
    },

    credentials: { type: credentialsSchema, required: true },

    extras: {
      type: mongoose.Schema.Types.Mixed,
      default: {},
    },

    voice: {
      stt: {
        provider: { type: String, enum: ['google', 'sarvam', 'ai4bharat'] },
        region: { type: String },
        project: { type: String },
        extras: { type: mongoose.Schema.Types.Mixed },
        isEnabled: { type: Boolean, default: true },
      },
      tts: {
        provider: { type: String, enum: ['google', 'sarvam', 'azure'] },
        region: { type: String },
        project: { type: String },
        voices: { type: Map, of: String },
        extras: { type: mongoose.Schema.Types.Mixed },
        isEnabled: { type: Boolean, default: true },
      },
    },

    status: {
      type: String,
      enum: ['unvalidated', 'valid', 'credential_invalid', 'error'],
      default: 'unvalidated',
    },
    lastValidatedAt: Date,
    lastError: String,

    autoFallback: { type: Boolean, default: false },

    isActive: { type: Boolean, default: false },

    createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    updatedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  },
  { timestamps: true }
);

aiProviderConfigSchema.index(
  { isActive: 1 },
  { unique: true, partialFilterExpression: { isActive: true } }
);

module.exports = mongoose.model('AiProviderConfig', aiProviderConfigSchema);
