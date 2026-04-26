const redis = require('../config/redis');

let SubscriptionService;
try {
  SubscriptionService = require('./subscription.service');
} catch (err) {
  SubscriptionService = null;
}

let logger;
try {
  logger = require('../utils/logger');
} catch (err) {
  logger = { info: () => {}, warn: () => {}, error: () => {}, debug: () => {} };
}

const TIER_DEFAULTS = {
  free: {
    soft: parseInt(process.env.VOICE_FREE_SOFT_LIMIT || '10', 10),
    hard: parseInt(process.env.VOICE_FREE_HARD_LIMIT || '30', 10),
    maxAudioSec: parseInt(process.env.VOICE_MAX_AUDIO_SEC_FREE || '30', 10),
    dailyCostCapUsd: parseFloat(process.env.VOICE_FREE_DAILY_COST_CAP || '0.50'),
  },
  premium: {
    soft: parseInt(process.env.VOICE_PREMIUM_SOFT_LIMIT || '50', 10),
    hard: parseInt(process.env.VOICE_PREMIUM_HARD_LIMIT || '100', 10),
    maxAudioSec: parseInt(process.env.VOICE_MAX_AUDIO_SEC_PAID || '60', 10),
    dailyCostCapUsd: parseFloat(process.env.VOICE_PREMIUM_DAILY_COST_CAP || '1.50'),
  },
  pro: {
    soft: parseInt(process.env.VOICE_PRO_SOFT_LIMIT || '300', 10),
    hard: parseInt(process.env.VOICE_PRO_HARD_LIMIT || '300', 10),
    maxAudioSec: parseInt(process.env.VOICE_MAX_AUDIO_SEC_PAID || '60', 10),
    dailyCostCapUsd: parseFloat(process.env.VOICE_PRO_DAILY_COST_CAP || '5.00'),
  },
};

const KEY = (uid, day) => `voice-quota:${uid}:${day}`;
const COST_KEY = (uid, day) => `voice-daily-cost:${uid}:${day}`;

function todayKey() {
  return new Date().toISOString().slice(0, 10);
}

async function detectTier(userId) {
  // Best-effort tier resolution. Returns "free" if subscription service is
  // unavailable; the soft/hard caps still apply.
  try {
    if (!SubscriptionService) return 'free';
    if (typeof SubscriptionService.getTier === 'function') {
      const tier = await SubscriptionService.getTier(userId);
      if (tier && TIER_DEFAULTS[tier]) return tier;
    }
    if (typeof SubscriptionService.getActiveSubscription === 'function') {
      const sub = await SubscriptionService.getActiveSubscription(userId);
      const tier = sub?.tier || sub?.plan || sub?.name || 'free';
      const lower = String(tier).toLowerCase();
      if (TIER_DEFAULTS[lower]) return lower;
    }
  } catch (err) {
    // fall through
  }
  return 'free';
}

async function _readInt(key) {
  try {
    const raw = await redis.get(key);
    return parseInt(raw || '0', 10) || 0;
  } catch (err) {
    return 0;
  }
}

async function _readFloat(key) {
  try {
    const raw = await redis.get(key);
    return parseFloat(raw || '0') || 0;
  } catch (err) {
    return 0;
  }
}

async function getStatus(userId) {
  const tier = await detectTier(userId);
  const limits = TIER_DEFAULTS[tier];
  const day = todayKey();
  const [used, costCents] = await Promise.all([
    _readInt(KEY(userId, day)),
    _readInt(COST_KEY(userId, day)),
  ]);
  return {
    tier,
    used,
    softLimit: limits.soft,
    hardLimit: limits.hard,
    maxAudioSec: limits.maxAudioSec,
    dailyCostCapUsd: limits.dailyCostCapUsd,
    costUsdToday: costCents / 10_000,
  };
}

async function exceededHard(userId) {
  const s = await getStatus(userId);
  if (s.used >= s.hardLimit) return { exceeded: true, reason: 'hard_count' };
  if (s.costUsdToday >= s.dailyCostCapUsd) return { exceeded: true, reason: 'daily_cost' };
  return { exceeded: false };
}

async function exceededSoft(userId) {
  const s = await getStatus(userId);
  return { exceeded: s.used >= s.softLimit, status: s };
}

async function consume(userId) {
  const day = todayKey();
  try {
    const c = await redis.incr(KEY(userId, day));
    if (c === 1) await redis.expire(KEY(userId, day), 48 * 3600);
    return c;
  } catch (err) {
    return null;
  }
}

async function refundLastCall(userId, reason) {
  const day = todayKey();
  try {
    await redis.decr(KEY(userId, day));
  } catch (err) {
    // best-effort
  }
  logger.info?.('voice-quota.refund', { userId, reason });
}

/**
 * Track per-user voice spend in $ cents × 10000 (so we can sum sub-cent costs
 * accurately). Bucketed daily, 48h TTL. Used by exceededHard's cost cap check.
 */
async function recordCost(userId, costUsd) {
  if (!Number.isFinite(costUsd) || costUsd <= 0) return;
  const day = todayKey();
  const cents = Math.round(costUsd * 10_000);
  try {
    if (typeof redis.incrby === 'function') await redis.incrby(COST_KEY(userId, day), cents);
    else for (let i = 0; i < cents; i++) await redis.incr(COST_KEY(userId, day));
    await redis.expire(COST_KEY(userId, day), 48 * 3600);
  } catch (err) {
    // best-effort
  }
}

async function maxAudioSecForUser(userId) {
  const s = await getStatus(userId);
  return s.maxAudioSec;
}

module.exports = {
  detectTier,
  getStatus,
  exceededHard,
  exceededSoft,
  consume,
  refundLastCall,
  recordCost,
  maxAudioSecForUser,
  TIER_DEFAULTS,
};
