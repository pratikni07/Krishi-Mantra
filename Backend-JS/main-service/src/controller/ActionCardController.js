const mongoose = require('mongoose');
const DailyActionCard = require('../model/DailyActionCard');
const FarmProfile = require('../model/FarmProfile');
const ActivityJournal = require('../model/ActivityJournal');
const CardBuilder = require('../services/action-card/card.builder');
const { asyncHandler } = require('../utils');
const { HTTP_STATUS } = require('../utils/constants');

let redis;
try {
  redis = require('../config/redis');
} catch (err) {
  redis = null;
}

const FARMER_INPUT_RATE_LIMIT_PER_HOUR = 6;
const MAX_FARMER_INPUT_IMAGES = 3;
const PRESIGNED_BUCKET_HOSTS = (process.env.PRESIGNED_BUCKET_HOSTS || '')
  .split(',')
  .map((s) => s.trim())
  .filter(Boolean);

function userIdOf(req) {
  return req.user?.id || req.user?._id || req.user?.userId;
}

function isFromOurUploader(url) {
  if (!url || typeof url !== 'string') return false;
  if (PRESIGNED_BUCKET_HOSTS.length === 0) {
    // Dev mode: accept any https URL. In prod the env var pins to our buckets.
    return /^https?:\/\//i.test(url);
  }
  try {
    const u = new URL(url);
    return PRESIGNED_BUCKET_HOSTS.includes(u.host);
  } catch (err) {
    return false;
  }
}

async function rateLimitedFarmerInput(userId) {
  if (!redis) return false;
  try {
    const hour = new Date().toISOString().slice(0, 13);
    const key = `farmer-input:${userId}:${hour}`;
    const cur = parseInt((await redis.get(key)) || '0', 10);
    if (cur >= FARMER_INPUT_RATE_LIMIT_PER_HOUR) return true;
    await redis.incr(key);
    await redis.expire(key, 60 * 60);
    return false;
  } catch (err) {
    return false;
  }
}

exports.today = asyncHandler(async (req, res) => {
  const userId = userIdOf(req);
  if (!userId) {
    return res
      .status(HTTP_STATUS.UNAUTHORIZED)
      .json({ success: false, message: 'Authentication required' });
  }

  const profile = await FarmProfile.findOne({ userId }).select('timezone preferredLanguage onboardingStatus').lean();
  const localDate = CardBuilder.todayLocalDate(profile?.timezone);

  const cached = redis ? await redis.get(`action-card:${userId}:${localDate}`).catch(() => null) : null;
  if (cached) {
    return res.json({
      success: true,
      localDate,
      items: typeof cached === 'string' ? JSON.parse(cached) : cached,
      cached: true,
    });
  }

  const card = await DailyActionCard.findOne({ userId, localDate });
  if (card) {
    return res.json({
      success: true,
      cardId: card._id,
      localDate,
      items: card.items,
      farmerInput: card.farmerInput,
      cached: false,
    });
  }

  // Cold path — build on demand.
  const built = await CardBuilder.buildCardForUser(userId, { localDate, generator: 'on_demand' });
  if (built.skipped) {
    return res.json({
      success: true,
      localDate,
      items: [],
      empty: true,
      reason: built.skipped,
    });
  }
  return res.json({
    success: true,
    cardId: built.cardId,
    localDate,
    items: built.items || [],
    cached: false,
    generatedOnDemand: true,
  });
});

exports.history = asyncHandler(async (req, res) => {
  const userId = userIdOf(req);
  if (!userId) {
    return res.status(HTTP_STATUS.UNAUTHORIZED).json({ success: false, message: 'Authentication required' });
  }
  const limit = Math.min(parseInt(req.query.limit, 10) || 14, 30);
  const cards = await DailyActionCard.find({ userId })
    .sort({ localDate: -1 })
    .limit(limit)
    .select('localDate items farmerInput aiBuilder generatedAt')
    .lean();
  return res.json({ success: true, cards });
});

exports.markStatus = asyncHandler(async (req, res) => {
  const userId = userIdOf(req);
  const { cardId, itemId } = req.params;
  const { status, reason, notes } = req.body || {};

  if (!userId) {
    return res.status(HTTP_STATUS.UNAUTHORIZED).json({ success: false, message: 'Authentication required' });
  }
  if (!['done', 'skipped', 'snoozed'].includes(status)) {
    return res.status(HTTP_STATUS.BAD_REQUEST).json({ success: false, message: 'Invalid status' });
  }

  const card = await DailyActionCard.findOne({ _id: cardId, userId });
  if (!card) {
    return res.status(HTTP_STATUS.NOT_FOUND).json({ success: false, message: 'Card not found' });
  }
  const item = card.items.find((i) => i.itemId === itemId);
  if (!item) {
    return res.status(HTTP_STATUS.NOT_FOUND).json({ success: false, message: 'Item not found' });
  }
  if (item.status !== 'pending' && item.status !== 'snoozed') {
    return res.status(HTTP_STATUS.CONFLICT).json({ success: false, message: `Already ${item.status}` });
  }
  item.status = status;
  item.statusUpdatedAt = new Date();
  if (status === 'skipped') item.skipReason = reason;
  if (notes) item.notes = notes;
  await card.save();

  // Mirror into activity journal so the next-day generator sees the action.
  if (status === 'done' || status === 'skipped') {
    try {
      await ActivityJournal.create({
        userId,
        cropEntryId: item.cropEntryId,
        cropName: item.cropName,
        verb: item.verb,
        chemical: item.chemical,
        dose: item.dose,
        notes,
        source: status === 'done' ? 'card_done' : 'card_skipped',
        cardItemId: item.itemId,
        cardLocalDate: card.localDate,
        localDate: card.localDate,
        timezone: card.timezone,
      });
    } catch (err) {
      // best-effort; the card mutation is the source of truth
    }
  }

  if (redis) {
    try {
      await redis.del(`action-card:${userId}:${card.localDate}`);
      if (typeof redis.publish === 'function') {
        await redis.publish('activity.logged', JSON.stringify({ userId: String(userId), verb: item.verb }));
      }
    } catch (err) {
      // best-effort
    }
  }

  return res.json({ success: true, item });
});

exports.farmerInput = asyncHandler(async (req, res) => {
  const userId = userIdOf(req);
  const { cardId } = req.params;
  const { text, imageUrls } = req.body || {};

  if (!userId) {
    return res.status(HTTP_STATUS.UNAUTHORIZED).json({ success: false, message: 'Authentication required' });
  }

  if (await rateLimitedFarmerInput(userId)) {
    return res.status(429).json({ success: false, message: 'Too many notes; try again in a bit' });
  }

  if ((!text || !text.trim()) && (!Array.isArray(imageUrls) || imageUrls.length === 0)) {
    return res.status(HTTP_STATUS.BAD_REQUEST).json({ success: false, message: 'Provide text or at least one image' });
  }
  if (text && text.length > 500) {
    return res.status(HTTP_STATUS.BAD_REQUEST).json({ success: false, message: 'Text too long (max 500 chars)' });
  }
  const safeImageUrls = Array.isArray(imageUrls) ? imageUrls.slice(0, MAX_FARMER_INPUT_IMAGES) : [];
  for (const url of safeImageUrls) {
    if (!isFromOurUploader(url)) {
      return res.status(HTTP_STATUS.BAD_REQUEST).json({
        success: false,
        message: 'Image must be uploaded via our presigned-URL endpoint',
      });
    }
  }

  const card = await DailyActionCard.findOne({ _id: cardId, userId });
  if (!card) {
    return res.status(HTTP_STATUS.NOT_FOUND).json({ success: false, message: 'Card not found' });
  }

  card.farmerInput = {
    text: text ? text.trim() : card.farmerInput?.text || '',
    imageUrls: [...(card.farmerInput?.imageUrls || []), ...safeImageUrls].slice(0, 5),
    voiceUrl: card.farmerInput?.voiceUrl,
    submittedAt: new Date(),
    acknowledged: false,
  };
  await card.save();

  if (redis && typeof redis.publish === 'function') {
    try {
      await redis.publish(
        'action-card.farmer-input',
        JSON.stringify({ userId: String(userId), cardId: String(card._id) })
      );
    } catch (err) {
      // best-effort
    }
  }

  return res.status(HTTP_STATUS.OK).json({ success: true, farmerInput: card.farmerInput });
});

exports.regenerate = asyncHandler(async (req, res) => {
  const userId = userIdOf(req);
  if (!userId) {
    return res.status(HTTP_STATUS.UNAUTHORIZED).json({ success: false, message: 'Authentication required' });
  }
  // Coarse 1/hour rate limit on the regenerate; cron handles the rest.
  if (redis) {
    const hour = new Date().toISOString().slice(0, 13);
    const key = `action-card:regen:${userId}:${hour}`;
    try {
      const cur = parseInt((await redis.get(key)) || '0', 10);
      if (cur >= 3) {
        return res.status(429).json({ success: false, message: 'Too many regenerations this hour' });
      }
      await redis.incr(key);
      await redis.expire(key, 60 * 60);
    } catch (err) {
      // best-effort
    }
  }

  const built = await CardBuilder.buildCardForUser(userId, { force: true, generator: 'on_demand' });
  if (built.skipped) return res.json({ success: true, skipped: built.skipped });
  return res.json({ success: true, cardId: built.cardId, items: built.items });
});
