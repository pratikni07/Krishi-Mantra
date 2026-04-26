const FarmProfile = require('../../model/FarmProfile');
const ActivityJournal = require('../../model/ActivityJournal');
const DailyActionCard = require('../../model/DailyActionCard');

const Engine = require('./recommendation.engine');
const Localizer = require('./localizer');
const ImageContext = require('./image-context.service');
const AiBuilder = require('./ai-builder.service');
const WeatherSnapshotClient = require('../weather-snapshot.client');

let redis;
try {
  redis = require('../../config/redis');
} catch (err) {
  redis = null;
}

let logger;
try {
  logger = require('../../utils/logger');
} catch (err) {
  logger = { info: () => {}, warn: () => {}, error: () => {}, debug: () => {} };
}

const MIN_TARGET_ITEMS = 1;

function todayLocalDate(timezone = 'Asia/Kolkata', now = new Date()) {
  // Cheap & dependency-free local-date computation. Good enough for IST.
  // For full correctness across DSTs we'd swap to luxon/dayjs-tz; not needed
  // for India.
  try {
    const fmt = new Intl.DateTimeFormat('en-CA', {
      timeZone: timezone,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    });
    return fmt.format(now);
  } catch (err) {
    return now.toISOString().slice(0, 10);
  }
}

function addDays(d, days) {
  const r = new Date(d);
  r.setDate(r.getDate() + days);
  return r;
}

function daysAgo(n) {
  return new Date(Date.now() - n * 24 * 60 * 60 * 1000);
}

async function loadProfileForBuild(userId) {
  const profile = await FarmProfile.findOne({ userId }).lean();
  if (!profile) return { skipped: 'no_profile' };
  if (profile.onboardingStatus !== 'completed') return { skipped: 'onboarding_incomplete' };
  if (!Array.isArray(profile.crops) || !profile.crops.some((c) => c.isActive !== false)) {
    return { skipped: 'no_active_crops' };
  }
  return { profile };
}

async function fetchWeather(profile) {
  const coords = profile?.location?.coordinates;
  if (!coords || coords.length < 2) return null;
  try {
    return await WeatherSnapshotClient.get(coords);
  } catch (err) {
    logger.warn?.('action-card.weather_fetch_failed', { error: err.message });
    return null;
  }
}

async function fetchRecentJournal(userId) {
  try {
    return await ActivityJournal.find({
      userId,
      occurredAt: { $gte: daysAgo(30) },
      isDeleted: { $ne: true },
    })
      .sort({ occurredAt: -1 })
      .limit(150)
      .lean();
  } catch (err) {
    logger.warn?.('action-card.journal_fetch_failed', { error: err.message });
    return [];
  }
}

function aiFirstEnabled() {
  const v = process.env.FF_ACTION_CARD_AI_FIRST;
  if (v == null) return true; // default ON post-A08
  return /^(1|true|yes|on)$/i.test(String(v).trim());
}

/**
 * Pull yesterday's farmer input, mark it acknowledged after we read it.
 * Returns just the text for prompt context (the images themselves are
 * already collected by the image-context service).
 */
async function consumeFarmerInputYesterday(userId, todayKey) {
  try {
    const yesterday = await DailyActionCard.findOne({
      userId,
      localDate: { $lt: todayKey },
      'farmerInput.submittedAt': { $exists: true },
    })
      .sort({ localDate: -1 })
      .limit(1);
    if (!yesterday?.farmerInput?.text) return null;
    if (!yesterday.farmerInput.acknowledged) {
      yesterday.farmerInput.acknowledged = true;
      await yesterday.save().catch(() => {});
    }
    return yesterday.farmerInput.text;
  } catch (err) {
    return null;
  }
}

/**
 * Tag each AI item with a stable itemId. AI items use today's local date so
 * a regenerate doesn't duplicate; the verb anchors them to the slot.
 */
function tagAiItemIds(items, localDate) {
  return items.map((it) => ({
    ...it,
    itemId: Engine._internal.makeItemId([
      'ai',
      String(it.cropEntryId),
      localDate,
      it.verb,
    ]),
  }));
}

/**
 * AI-first merge with rule fallback safety net. Strategy:
 *   - Start with AI items.
 *   - For any crop that has no AI item, take its top-1 rule item.
 *   - For any global slot still empty, take the next-best rule item.
 *   - Cap at 3 globally.
 * Per-crop dedupe ensures the same (crop, verb) pair doesn't appear twice.
 */
function mergeAiAndRule(aiItems, ruleItems, profile) {
  const out = [];
  const usedKey = new Set();
  const cropsCovered = new Set();

  const keyOf = (it) => `${String(it.cropEntryId)}::${it.verb}`;

  for (const it of aiItems) {
    const k = keyOf(it);
    if (usedKey.has(k)) continue;
    usedKey.add(k);
    cropsCovered.add(String(it.cropEntryId));
    out.push(it);
    if (out.length >= 3) return out;
  }

  // Backfill from rule items, preferring crops not yet covered.
  const ruleByCrop = new Map();
  for (const r of ruleItems) {
    const k = String(r.cropEntryId);
    if (!ruleByCrop.has(k)) ruleByCrop.set(k, []);
    ruleByCrop.get(k).push(r);
  }
  // First pass: fill crops missing from AI
  for (const crop of profile.crops || []) {
    if (out.length >= 3) break;
    const k = String(crop._id);
    if (cropsCovered.has(k)) continue;
    const rs = ruleByCrop.get(k);
    if (!rs?.length) continue;
    const r = rs.shift();
    if (usedKey.has(keyOf(r))) continue;
    usedKey.add(keyOf(r));
    cropsCovered.add(k);
    out.push(r);
  }
  // Second pass: any remaining slot
  if (out.length < 3) {
    for (const rs of ruleByCrop.values()) {
      while (rs.length && out.length < 3) {
        const r = rs.shift();
        if (usedKey.has(keyOf(r))) continue;
        usedKey.add(keyOf(r));
        out.push(r);
      }
      if (out.length >= 3) break;
    }
  }

  return out;
}

/**
 * Build (or re-build) a user's action card for a given local-date.
 *
 * Returns one of:
 *   { skipped: <reason> }
 *   { cardId, items, generated: bool, aiUsageUsd }
 */
async function buildCardForUser(userId, opts = {}) {
  const { localDate: lateDateOverride, force = false, generator = 'cron' } = opts;

  const loaded = await loadProfileForBuild(userId);
  if (loaded.skipped) return loaded;
  const profile = loaded.profile;

  const localDate = lateDateOverride || todayLocalDate(profile.timezone);
  if (!force) {
    const existing = await DailyActionCard.findOne({ userId, localDate }).lean();
    if (existing) {
      return { cardId: existing._id, items: existing.items, generated: false };
    }
  }

  const [weather, journal, imageContext, farmerInputYesterday] = await Promise.all([
    fetchWeather(profile),
    fetchRecentJournal(userId),
    ImageContext.collect(userId).catch((err) => {
      logger.warn?.('action-card.image_context_failed', { error: err.message });
      return { images: [], totalSeen: 0, sources: {} };
    }),
    consumeFarmerInputYesterday(userId, localDate),
  ]);

  // Run AI builder + rule engine in parallel. Rule engine is cheap; we always
  // have a deterministic safety net even if the AI call returns garbage.
  const [aiResult, ruleResult] = await Promise.all([
    aiFirstEnabled()
      ? AiBuilder.recommend({
          profile,
          weather,
          journal,
          imageContext,
          farmerInputYesterday,
          lang: profile.preferredLanguage,
        })
      : Promise.resolve({
          items: [],
          used: false,
          fallbackToRule: true,
          provider: null,
          model: null,
          costUsd: 0,
          latencyMs: 0,
          imageCount: 0,
          itemsAccepted: 0,
          itemsRejected: 0,
          parseFailed: false,
          reasonsHistogram: {},
          error: 'feature_flag_off',
        }),
    Engine.recommend(profile, weather, journal),
  ]);

  const aiItemsTagged = tagAiItemIds(aiResult.items, localDate);

  // Rule items are template-shaped; localizer needs to render them.
  // AI items are already localized (the model output in target lang).
  const merged = mergeAiAndRule(aiItemsTagged, ruleResult.items, profile);

  const aiCostUsd = aiResult.costUsd || 0;
  const aiBuilderMeta = {
    used: !!aiResult.used,
    provider: aiResult.provider,
    model: aiResult.model,
    itemsAccepted: aiResult.itemsAccepted || 0,
    itemsRejected: aiResult.itemsRejected || 0,
    imageCount: aiResult.imageCount || 0,
    latencyMs: aiResult.latencyMs || 0,
    costUsd: aiResult.costUsd || 0,
    fallbackToRule: aiResult.fallbackToRule || merged.length === 0 || aiItemsTagged.length === 0,
    error: aiResult.error,
  };

  const localized = merged.map((it) => {
    const loc = Localizer.localize(it, profile.preferredLanguage);
    // Strip the embedded template doc — we don't want to persist it on the card.
    // eslint-disable-next-line no-unused-vars
    const { template, _score, _rationaleTagsExtra, aiCostUsd: _ai, ...persistable } = loc;
    return persistable;
  });

  const persistedItems = localized.map((it) => ({
    itemId: it.itemId,
    cropEntryId: it.cropEntryId,
    cropName: it.cropName,
    cropVariety: it.cropVariety,
    templateId: it.templateId,
    source: it.source,
    verb: it.verb,
    title: it.title,
    detail: it.detail,
    chemical: it.chemical,
    dose: it.dose,
    safetyNote: it.safetyNote,
    urgency: it.urgency || 'normal',
    rationaleTags: it.rationaleTags || [],
    status: 'pending',
  }));

  const card = await DailyActionCard.findOneAndUpdate(
    { userId, localDate },
    {
      $set: {
        userId,
        localDate,
        timezone: profile.timezone || 'Asia/Kolkata',
        items: persistedItems,
        generatedAt: new Date(),
        weatherSnapshotBucket: weather?.bucket,
        farmProfileVersion: profile.profileVersion,
        generator,
        aiUsageUsd: aiCostUsd,
        aiBuilder: aiBuilderMeta,
        expiresAt: addDays(new Date(), 30),
      },
    },
    { upsert: true, new: true, setDefaultsOnInsert: true }
  );

  await writeRedisCache(userId, localDate, card.items);
  await maybePublishRegen(userId, localDate);

  const aiItemsCount = persistedItems.filter((it) => it.source === 'ai').length;
  const ruleItemsCount = persistedItems.filter((it) => it.source === 'template').length;

  logger.info?.('action_card.built', {
    userId: String(userId),
    localDate,
    items: card.items.length,
    ai: aiItemsCount,
    rule: ruleItemsCount,
    aiUsed: aiBuilderMeta.used,
    aiProvider: aiBuilderMeta.provider,
    aiAccepted: aiBuilderMeta.itemsAccepted,
    aiRejected: aiBuilderMeta.itemsRejected,
    aiImages: aiBuilderMeta.imageCount,
    aiCostUsd: Number((aiCostUsd || 0).toFixed(6)),
    generator,
  });

  return { cardId: card._id, items: card.items, generated: true, aiUsageUsd: aiCostUsd };
}

async function writeRedisCache(userId, localDate, items) {
  if (!redis) return;
  try {
    await redis.setex(
      `action-card:${userId}:${localDate}`,
      24 * 3600,
      JSON.stringify(items)
    );
  } catch (err) {
    // best-effort
  }
}

async function maybePublishRegen(userId, localDate) {
  if (!redis || typeof redis.publish !== 'function') return;
  try {
    await redis.publish(
      'action-card.regenerated',
      JSON.stringify({ userId: String(userId), localDate })
    );
  } catch (err) {
    // best-effort
  }
}

module.exports = {
  buildCardForUser,
  todayLocalDate,
};
