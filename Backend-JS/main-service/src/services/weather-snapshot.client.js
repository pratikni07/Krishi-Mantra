const mongoose = require('mongoose');

let redis;
try {
  redis = require('../config/redis');
} catch (err) {
  redis = null;
}

let logger;
try {
  logger = require('../utils/logger');
} catch (err) {
  logger = { info: () => {}, warn: () => {}, error: () => {} };
}

const REDIS_TTL_SECONDS = 15 * 60;

let WeatherSnapshotModel = null;

/**
 * Lazy-register a minimal WeatherSnapshot model on the shared mongoose
 * connection. The full schema lives in message-svc; we read with `strict: false`
 * so we don't need to keep the two schemas in lockstep — only the fields the
 * action-card recommendation engine actually consumes are typed.
 */
function loadModel() {
  if (WeatherSnapshotModel) return WeatherSnapshotModel;
  try {
    WeatherSnapshotModel = mongoose.model('WeatherSnapshot');
  } catch (err) {
    const { Schema } = mongoose;
    const schema = new Schema(
      {
        bucket: { type: String, index: true },
        lat: Number,
        lon: Number,
        asOf: Date,
        days: [Schema.Types.Mixed],
        provider: String,
        expiresAt: Date,
      },
      {
        timestamps: true,
        collection: 'weathersnapshots',
        strict: false,
      }
    );
    WeatherSnapshotModel = mongoose.model('WeatherSnapshot', schema);
  }
  return WeatherSnapshotModel;
}

function bucketKey(lat, lon) {
  if (typeof lat !== 'number' || typeof lon !== 'number') return null;
  if (Number.isNaN(lat) || Number.isNaN(lon)) return null;
  const r = (n) => Math.round(n * 100) / 100;
  return `${r(lat)},${r(lon)}`;
}

async function readFromRedis(bucket) {
  if (!redis) return null;
  try {
    const raw = await redis.get(`weather:${bucket}`);
    if (!raw) return null;
    const parsed = typeof raw === 'string' ? JSON.parse(raw) : raw;
    if (parsed?.expiresAt && new Date(parsed.expiresAt).getTime() < Date.now()) return null;
    return parsed;
  } catch (err) {
    return null;
  }
}

async function writeToRedis(bucket, snap) {
  if (!redis) return;
  try {
    await redis.setex(`weather:${bucket}`, REDIS_TTL_SECONDS, JSON.stringify(snap));
  } catch (err) {
    // best-effort
  }
}

/**
 * Read-only client. Returns the cached snapshot if available; falls back to
 * the Mongo collection that message-svc's weather.service writes to. Never
 * triggers a fresh provider fetch — that's message-svc's job.
 *
 * Returns null if there's no snapshot for the bucket. Callers (e.g. the
 * recommendation engine) MUST treat null as "weather unavailable; fail open".
 */
async function get(coordinates) {
  if (!coordinates || coordinates.length < 2) return null;
  const lon = Number(coordinates[0]);
  const lat = Number(coordinates[1]);
  const bucket = bucketKey(lat, lon);
  if (!bucket) return null;

  const cached = await readFromRedis(bucket);
  if (cached) return cached;

  try {
    const Model = loadModel();
    const doc = await Model.findOne({ bucket }).lean();
    if (!doc) return null;
    if (doc.expiresAt && doc.expiresAt.getTime() < Date.now()) {
      logger.warn?.('weather-snapshot.stale_served', { bucket });
    }
    await writeToRedis(bucket, doc);
    return doc;
  } catch (err) {
    logger.warn?.('weather-snapshot.read_failed', { bucket, error: err.message });
    return null;
  }
}

module.exports = { get, bucketKey };
