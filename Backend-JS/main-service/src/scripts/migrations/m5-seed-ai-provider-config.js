/**
 * M5 — bootstrap: if no AiProviderConfig rows exist and legacy OPENAI_API_KEYS
 * is set in env, seed a single active OpenAI config so the factory has something
 * to return on cold start. Idempotent.
 *
 * Usage: node src/scripts/migrations/m5-seed-ai-provider-config.js
 */
const path = require('path');
const dotenv = require('dotenv');
dotenv.config({ path: path.resolve(__dirname, '../../../.env.development') });
dotenv.config({ path: path.resolve(__dirname, '../../../.env') });

const mongoose = require('mongoose');
const AiProviderConfig = require('../../model/AiProviderConfig');
const AiProviderAudit = require('../../model/AiProviderAudit');
const secretBox = require('../../utils/secret-box');

async function up() {
  await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/farmer-chat');
  console.log('[M5] connected');

  const existing = await AiProviderConfig.countDocuments();
  if (existing > 0) {
    console.log(`[M5] skipping — ${existing} AiProviderConfig doc(s) already exist`);
    await mongoose.disconnect();
    return;
  }

  const rawKeys = process.env.OPENAI_API_KEYS;
  if (!rawKeys) {
    console.log('[M5] skipping — OPENAI_API_KEYS not set; admin must create config manually');
    await mongoose.disconnect();
    return;
  }
  const keys = rawKeys.split(',').map((k) => k.trim()).filter(Boolean);
  if (!keys.length) {
    console.log('[M5] skipping — OPENAI_API_KEYS has no valid entries');
    await mongoose.disconnect();
    return;
  }

  const plaintext = keys.join('\n');
  const config = new AiProviderConfig({
    provider: 'openai',
    displayName: 'OpenAI (bootstrapped)',
    models: {
      chat: process.env.OPENAI_CHAT_MODEL || 'gpt-4.1-mini',
      vision: process.env.OPENAI_VISION_MODEL || 'gpt-4o-mini',
      embed: process.env.OPENAI_EMBED_MODEL || 'text-embedding-3-small',
    },
    credentials: {
      type: 'api_key',
      payload: { iv: '', tag: '', ciphertext: '' },
      fingerprint: secretBox.fingerprint(plaintext),
    },
    extras: { orgId: process.env.OPENAI_ORG_ID || undefined, keyCount: keys.length },
    status: 'unvalidated',
    autoFallback: false,
    isActive: true,
  });

  config.credentials.payload = secretBox.encrypt(plaintext, { aad: String(config._id) });
  await config.save();

  await AiProviderAudit.create({
    configId: config._id,
    provider: 'openai',
    action: 'create',
    diff: { seededFromEnv: true, keyCount: keys.length, models: config.models },
  });

  console.log(`[M5] seeded OpenAI config id=${config._id} with ${keys.length} key(s)`);
  await mongoose.disconnect();
}

if (require.main === module) {
  up().catch((err) => {
    console.error('[M5] failed:', err.message);
    process.exit(1);
  });
}

module.exports = { up };
