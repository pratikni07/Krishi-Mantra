const aiConfig = require('../services/ai-config.service');
const logger = require('../utils/logger');
const { STTUnavailable } = require('./stt.interface');

const googleStt = require('./google-stt.provider');

let lastBound = null;
let lastBoundFingerprint = null;

function fingerprintCfg(cfg) {
  if (!cfg) return 'none';
  const stt = cfg.voice?.stt || {};
  return [
    cfg.provider,
    String(cfg._id || ''),
    stt.provider || 'inherit',
    stt.region || cfg.extras?.location || '',
  ].join('|');
}

/**
 * Resolve the active STT provider.
 *
 * Priority of source for credentials/region:
 *   1. AiProviderConfig.voice.stt (admin-explicit)
 *   2. AiProviderConfig (reuse Vertex GCP creds)
 *   3. Env vars (bootstrap)
 */
async function active() {
  const cfg = await aiConfig.getActive().catch(() => null);
  const fp = fingerprintCfg(cfg);
  if (lastBound && fp === lastBoundFingerprint) return lastBound;

  const stt = cfg?.voice?.stt || {};
  if (stt.isEnabled === false) {
    throw new STTUnavailable('configured', 'stt_disabled_in_config');
  }

  // Provider name selection: explicit override → fall back to "google".
  const providerName =
    stt.provider ||
    process.env.VOICE_STT_PROVIDER ||
    'google';

  // Build a credentials/extras shim that mimics the AiProviderConfig shape
  // the google providers expect. Re-uses Vertex SA when admin has an active
  // Vertex config; otherwise falls back to env-var bootstrap.
  const shim = {
    voice: { stt },
    extras: {
      project:
        stt.project ||
        cfg?.extras?.project ||
        process.env.VERTEX_DEFAULT_PROJECT ||
        process.env.GCP_PROJECT ||
        null,
      location:
        stt.region ||
        cfg?.extras?.location ||
        process.env.VOICE_STT_REGION ||
        'asia-south1',
    },
    credentials: cfg?.credentials || null,
  };

  if (providerName === 'google') {
    if (!shim.credentials || cfg?.provider !== 'vertex') {
      // Try env-var fallback (key embedded as JSON).
      const envSa = process.env.GOOGLE_APPLICATION_CREDENTIALS_JSON;
      if (envSa) {
        try {
          shim.credentials = {
            type: 'service_account_json',
            serviceAccount: JSON.parse(envSa),
          };
        } catch (err) {
          logger.warn('voice.stt.bad_env_credentials');
        }
      }
    }
    if (!shim.credentials?.serviceAccount?.client_email) {
      throw new STTUnavailable('google', 'no_credentials');
    }
    const inst = googleStt.bind(shim);
    lastBound = inst;
    lastBoundFingerprint = fp;
    return inst;
  }

  throw new STTUnavailable(providerName, 'unknown_provider');
}

function resetCache() {
  lastBound = null;
  lastBoundFingerprint = null;
}

module.exports = { active, resetCache };
