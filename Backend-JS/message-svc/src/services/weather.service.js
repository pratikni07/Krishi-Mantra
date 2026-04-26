const WeatherSnapshot = require('../models/weather-snapshot.model');
const redis = require('../config/redis');
const logger = require('../utils/logger');
const openMeteo = require('../ai-providers/weather/open-meteo.provider');

const REDIS_TTL_SECONDS = 15 * 60;
const MONGO_TTL_MS = 60 * 60 * 1000;
const LOCK_TTL_SECONDS = 10;
const ACTIVE_BUCKETS_KEY = 'weather:active-buckets';

function bucketKey(lat, lon) {
  const r = (n) => Math.round(n * 100) / 100;
  return `${r(lat)},${r(lon)}`;
}

function parseBucket(bucket) {
  const [lat, lon] = bucket.split(',').map(Number);
  return { lat, lon };
}

function selectProvider() {
  const name = (process.env.WEATHER_PROVIDER || 'open-meteo').toLowerCase();
  if (name === 'open-meteo') return openMeteo;
  logger.warn('weather provider not implemented; falling back to open-meteo', { name });
  return openMeteo;
}

async function acquireLock(bucket) {
  try {
    const client = redis.client;
    if (!client || typeof client.set !== 'function') return true;
    const result = await client.set(
      `weather:lock:${bucket}`,
      '1',
      'NX',
      'EX',
      LOCK_TTL_SECONDS
    );
    return result === 'OK';
  } catch (err) {
    return true;
  }
}

async function releaseLock(bucket) {
  try {
    await redis.del(`weather:lock:${bucket}`);
  } catch (err) {
    // best-effort
  }
}

function snapshotFromDoc(doc) {
  if (!doc) return null;
  const plain = typeof doc.toObject === 'function' ? doc.toObject() : doc;
  return {
    bucket: plain.bucket,
    lat: plain.lat,
    lon: plain.lon,
    asOf: plain.asOf,
    provider: plain.provider,
    days: plain.days,
    expiresAt: plain.expiresAt,
  };
}

async function readFromRedis(bucket) {
  try {
    const raw = await redis.get(`weather:${bucket}`);
    if (!raw) return null;
    const parsed = JSON.parse(raw);
    if (!parsed?.expiresAt) return parsed;
    return new Date(parsed.expiresAt).getTime() > Date.now() ? parsed : null;
  } catch (err) {
    return null;
  }
}

async function writeToRedis(bucket, snapshot) {
  try {
    await redis.setex(`weather:${bucket}`, REDIS_TTL_SECONDS, JSON.stringify(snapshot));
  } catch (err) {
    // best-effort
  }
}

async function trackActiveBucket(bucket) {
  try {
    const client = redis.client;
    if (!client || typeof client.zadd !== 'function') return;
    await client.zadd(ACTIVE_BUCKETS_KEY, Date.now(), bucket);
  } catch (err) {
    // best-effort
  }
}

async function get7Day(lat, lon, { force = false } = {}) {
  if (typeof lat !== 'number' || typeof lon !== 'number' || Number.isNaN(lat) || Number.isNaN(lon)) {
    return null;
  }
  const bucket = bucketKey(lat, lon);
  trackActiveBucket(bucket);

  if (!force) {
    const cached = await readFromRedis(bucket);
    if (cached) return cached;

    const doc = await WeatherSnapshot.findOne({ bucket });
    if (doc && doc.expiresAt && doc.expiresAt.getTime() > Date.now()) {
      const snap = snapshotFromDoc(doc);
      await writeToRedis(bucket, snap);
      return snap;
    }
  }

  const gotLock = await acquireLock(bucket);
  if (!gotLock) {
    await new Promise((r) => setTimeout(r, 250));
    const cached = await readFromRedis(bucket);
    if (cached) return cached;
  }

  try {
    const provider = selectProvider();
    const { days, provider: providerName } = await provider.fetch(lat, lon);
    const now = new Date();
    const expiresAt = new Date(now.getTime() + MONGO_TTL_MS);

    const updated = await WeatherSnapshot.findOneAndUpdate(
      { bucket },
      {
        bucket,
        lat,
        lon,
        asOf: now,
        days,
        provider: providerName,
        expiresAt,
      },
      { upsert: true, new: true, setDefaultsOnInsert: true }
    );

    const snap = snapshotFromDoc(updated);
    await writeToRedis(bucket, snap);
    return snap;
  } catch (err) {
    logger.error('weather fetch failed', { bucket, error: err.message });
    const doc = await WeatherSnapshot.findOne({ bucket });
    if (doc) {
      logger.warn('weather.stale_served', { bucket });
      return snapshotFromDoc(doc);
    }
    return null;
  } finally {
    await releaseLock(bucket);
  }
}

module.exports = { get7Day, bucketKey, parseBucket };
