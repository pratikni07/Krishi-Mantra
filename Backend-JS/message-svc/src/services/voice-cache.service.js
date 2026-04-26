const redis = require('../config/redis');

let logger;
try {
  logger = require('../utils/logger');
} catch (err) {
  logger = { info: () => {}, warn: () => {}, error: () => {}, debug: () => {} };
}

const TTL_DEFAULT_SEC = 24 * 60 * 60;
const TTL_RETENTION_SEC = 30 * 24 * 60 * 60;

const key = (messageId, voice) => `voice-tts:${messageId}:${voice || 'default'}`;

/**
 * Cache a synthesized assistant audio so /replay/:messageId can serve it
 * without re-billing TTS. Keyed by `(messageId, voiceName)` — different
 * voices for the same message yield different cache entries.
 *
 * `keepLong: true` extends TTL to 30 days for users who opted into voice-note
 * retention from the settings screen (B04).
 */
async function set(messageId, voice, mime, buffer, { keepLong = false } = {}) {
  if (!messageId || !buffer || !buffer.length) return;
  try {
    const ttl = keepLong ? TTL_RETENTION_SEC : TTL_DEFAULT_SEC;
    await redis.setex(
      key(messageId, voice),
      ttl,
      JSON.stringify({ mime, b64: buffer.toString('base64') })
    );
  } catch (err) {
    logger.warn?.('voice-cache.set_failed', { error: err.message });
  }
}

async function getReplay(messageId, voice) {
  try {
    const raw = await redis.get(key(messageId, voice));
    if (!raw) return null;
    const { mime, b64 } = JSON.parse(raw);
    return { mime, buffer: Buffer.from(b64, 'base64') };
  } catch (err) {
    logger.warn?.('voice-cache.get_failed', { error: err.message });
    return null;
  }
}

async function evict(messageId, voice) {
  try {
    await redis.del(key(messageId, voice));
  } catch (err) {
    // best-effort
  }
}

module.exports = { set, getReplay, evict, TTL_DEFAULT_SEC, TTL_RETENTION_SEC };
