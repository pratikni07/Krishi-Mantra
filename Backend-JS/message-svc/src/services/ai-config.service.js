const Redis = require('ioredis');
const AiProviderConfig = require('../models/ai-provider-config.model');
const redis = require('../config/redis');
const secretBox = require('../utils/secret-box');
const logger = require('../utils/logger');

const CACHE_KEY = 'ai-config:active-provider';
const CACHE_TTL_SECONDS = 5 * 60;
const PUBSUB_CHANNEL = 'ai-config.changed';

let memoryCache = null;
let memoryCacheExpiresAt = 0;
let subscriberStarted = false;

function resetMemoryCache() {
  memoryCache = null;
  memoryCacheExpiresAt = 0;
}

function decryptCredentials(cfg) {
  if (!cfg || !cfg.credentials) return cfg;
  const out = cfg.toObject ? cfg.toObject() : { ...cfg };
  const plaintext = secretBox.decrypt(out.credentials.payload, { aad: String(out._id) });
  const cred = { type: out.credentials.type, fingerprint: out.credentials.fingerprint };
  if (cred.type === 'api_key') {
    cred.apiKeys = plaintext
      .split(/[\n,]/)
      .map((k) => k.trim())
      .filter(Boolean);
  } else if (cred.type === 'service_account_json') {
    try {
      cred.serviceAccount = JSON.parse(plaintext);
    } catch (err) {
      throw new Error('service_account_json payload is not valid JSON');
    }
  } else {
    cred.raw = plaintext;
  }
  out.credentials = cred;
  return out;
}

async function getActive({ force = false } = {}) {
  const now = Date.now();
  if (!force && memoryCache && memoryCacheExpiresAt > now) return memoryCache;

  if (!force) {
    try {
      const cached = await redis.get(CACHE_KEY);
      if (cached) {
        const parsed = JSON.parse(cached);
        memoryCache = parsed;
        memoryCacheExpiresAt = now + 30_000;
        return parsed;
      }
    } catch (err) {
      logger.warn('ai-config cache read failed', { error: err.message });
    }
  }

  const doc = await AiProviderConfig.findOne({ isActive: true }).lean();
  if (!doc) {
    resetMemoryCache();
    return null;
  }

  const decrypted = decryptCredentials(doc);
  try {
    await redis.setex(CACHE_KEY, CACHE_TTL_SECONDS, JSON.stringify(decrypted));
  } catch (err) {
    logger.warn('ai-config cache write failed', { error: err.message });
  }
  memoryCache = decrypted;
  memoryCacheExpiresAt = now + 30_000;
  return decrypted;
}

async function invalidate() {
  resetMemoryCache();
  try {
    await redis.del(CACHE_KEY);
  } catch (err) {
    logger.warn('ai-config invalidate failed', { error: err.message });
  }
}

async function publishChange(payload = {}) {
  try {
    const pubClient = redis.client;
    if (!pubClient || typeof pubClient.publish !== 'function') return;
    await pubClient.publish(PUBSUB_CHANNEL, JSON.stringify(payload));
  } catch (err) {
    logger.warn('ai-config publish failed', { error: err.message });
  }
}

function startSubscriber() {
  if (subscriberStarted) return;
  if (redis.isFallback && redis.isFallback()) {
    logger.warn('ai-config pub/sub disabled: redis in fallback mode');
    subscriberStarted = true;
    return;
  }

  try {
    const sub = new Redis({
      host: process.env.REDIS_HOST || 'localhost',
      port: parseInt(process.env.REDIS_PORT) || 6379,
      password: process.env.REDIS_PASSWORD || undefined,
      lazyConnect: false,
      maxRetriesPerRequest: 3,
    });

    sub.on('error', (err) => {
      logger.warn('ai-config subscriber error', { error: err.message });
    });

    sub.subscribe(PUBSUB_CHANNEL, (err) => {
      if (err) {
        logger.warn('ai-config subscribe failed', { error: err.message });
        return;
      }
      subscriberStarted = true;
      logger.info('ai-config subscriber listening', { channel: PUBSUB_CHANNEL });
    });

    sub.on('message', async (_channel, raw) => {
      logger.info('ai-config change notification received');
      resetMemoryCache();
      try {
        await redis.del(CACHE_KEY);
      } catch (err) {
        logger.warn('ai-config cache clear failed', { error: err.message });
      }
    });
  } catch (err) {
    logger.warn('ai-config subscriber init failed', { error: err.message });
  }
}

module.exports = {
  getActive,
  invalidate,
  publishChange,
  startSubscriber,
  _decryptCredentials: decryptCredentials,
  CACHE_KEY,
  PUBSUB_CHANNEL,
};
