const mongoose = require('mongoose');
const Redis = require('ioredis');
const redis = require('../config/redis');
const logger = require('../utils/logger');

const REDIS_TTL_SECONDS = 10 * 60;
const PUBSUB_CHANNEL = 'farm-profile.updated';

let FarmProfileModel = null;
let subscriberStarted = false;

function loadModel() {
  if (FarmProfileModel) return FarmProfileModel;
  try {
    FarmProfileModel = mongoose.model('FarmProfile');
  } catch (err) {
    // Model hasn't been registered on this connection yet; register a minimal
    // schema that maps to the same collection as main-service.
    const { Schema } = mongoose;
    const schema = new Schema(
      {
        userId: { type: Schema.Types.ObjectId, required: true, unique: true, index: true },
        age: Number,
        gender: String,
        preferredLanguage: { type: String, default: 'en' },
        location: {
          type: { type: String, enum: ['Point'], default: 'Point' },
          coordinates: { type: [Number], default: undefined },
        },
        address: Schema.Types.Mixed,
        totalArea: Number,
        totalAreaUnit: String,
        ownership: String,
        soilTypes: [String],
        irrigationSources: [String],
        experienceYears: Number,
        crops: [Schema.Types.Mixed],
        profileFingerprint: String,
        profileVersion: Number,
        onboardingStatus: String,
      },
      { timestamps: true, collection: 'farmprofiles', strict: false }
    );
    FarmProfileModel = mongoose.model('FarmProfile', schema);
  }
  return FarmProfileModel;
}

function key(userId) {
  return `farm-profile:${userId}`;
}
function fpKey(userId) {
  return `farm-profile:fp:${userId}`;
}

async function get(userId, { force = false } = {}) {
  if (!userId) return null;
  if (!force) {
    try {
      const cached = await redis.get(key(userId));
      if (cached) return JSON.parse(cached);
    } catch (err) {
      // fall through
    }
  }
  const Model = loadModel();
  const doc = await Model.findOne({ userId }).lean();
  if (!doc) return null;
  try {
    await redis.setex(key(userId), REDIS_TTL_SECONDS, JSON.stringify(doc));
    if (doc.profileFingerprint) {
      await redis.setex(fpKey(userId), REDIS_TTL_SECONDS, doc.profileFingerprint);
    }
  } catch (err) {
    // best-effort
  }
  return doc;
}

async function getActiveCrops(userId) {
  const profile = await get(userId);
  if (!profile?.crops?.length) return [];
  return profile.crops.filter((c) => c?.isActive !== false);
}

async function invalidate(userId) {
  if (!userId) return;
  try {
    await redis.del(key(userId));
    await redis.del(fpKey(userId));
  } catch (err) {
    // best-effort
  }
}

function startSubscriber() {
  if (subscriberStarted) return;
  if (redis.isFallback && redis.isFallback()) {
    logger.warn('farm-profile pub/sub disabled: redis in fallback mode');
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
      logger.warn('farm-profile subscriber error', { error: err.message });
    });
    sub.subscribe(PUBSUB_CHANNEL, (err) => {
      if (err) {
        logger.warn('farm-profile subscribe failed', { error: err.message });
        return;
      }
      subscriberStarted = true;
      logger.info('farm-profile subscriber listening', { channel: PUBSUB_CHANNEL });
    });
    sub.on('message', async (_channel, raw) => {
      try {
        const payload = JSON.parse(raw || '{}');
        const userId = payload.userId;
        if (!userId) return;
        await invalidate(userId);
        logger.info('farm-profile cache invalidated', {
          userId,
          profileVersion: payload.profileVersion,
        });
      } catch (err) {
        logger.warn('farm-profile pubsub handler failed', { error: err.message });
      }
    });
  } catch (err) {
    logger.warn('farm-profile subscriber init failed', { error: err.message });
  }
}

module.exports = { get, getActiveCrops, invalidate, startSubscriber, PUBSUB_CHANNEL };
