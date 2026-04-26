const aiConfig = require('../services/ai-config.service');
const logger = require('../utils/logger');
const { TTSUnavailable } = require('./tts.interface');

const googleTts = require('./google-tts.provider');

let lastBound = null;
let lastBoundFingerprint = null;

function fingerprintCfg(cfg) {
  if (!cfg) return 'none';
  const tts = cfg.voice?.tts || {};
  return [
    cfg.provider,
    String(cfg._id || ''),
    tts.provider || 'inherit',
    tts.region || cfg.extras?.location || '',
    JSON.stringify(tts.voices || {}),
  ].join('|');
}

async function active() {
  const cfg = await aiConfig.getActive().catch(() => null);
  const fp = fingerprintCfg(cfg);
  if (lastBound && fp === lastBoundFingerprint) return lastBound;

  const tts = cfg?.voice?.tts || {};
  if (tts.isEnabled === false) {
    throw new TTSUnavailable('configured', 'tts_disabled_in_config');
  }

  const providerName =
    tts.provider || process.env.VOICE_TTS_PROVIDER || 'google';

  const shim = {
    voice: { tts },
    extras: {
      project:
        tts.project ||
        cfg?.extras?.project ||
        process.env.VERTEX_DEFAULT_PROJECT ||
        process.env.GCP_PROJECT ||
        null,
      location: tts.region || cfg?.extras?.location || 'asia-south1',
    },
    credentials: cfg?.credentials || null,
  };

  if (providerName === 'google') {
    if (!shim.credentials || cfg?.provider !== 'vertex') {
      const envSa = process.env.GOOGLE_APPLICATION_CREDENTIALS_JSON;
      if (envSa) {
        try {
          shim.credentials = {
            type: 'service_account_json',
            serviceAccount: JSON.parse(envSa),
          };
        } catch (err) {
          logger.warn('voice.tts.bad_env_credentials');
        }
      }
    }
    if (!shim.credentials?.serviceAccount?.client_email) {
      throw new TTSUnavailable('google', 'no_credentials');
    }
    const inst = googleTts.bind(shim);
    lastBound = inst;
    lastBoundFingerprint = fp;
    return inst;
  }

  throw new TTSUnavailable(providerName, 'unknown_provider');
}

function resetCache() {
  lastBound = null;
  lastBoundFingerprint = null;
}

module.exports = { active, resetCache };
