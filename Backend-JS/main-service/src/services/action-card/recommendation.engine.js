const crypto = require('crypto');

const CropTaskTemplate = require('../../model/CropTaskTemplate');

let logger;
try {
  logger = require('../../utils/logger');
} catch (err) {
  logger = { info: () => {}, warn: () => {}, error: () => {}, debug: () => {} };
}

let redis;
try {
  redis = require('../../config/redis');
} catch (err) {
  redis = null;
}

const STAGES = CropTaskTemplate.STAGES;
const URGENCY_SCORE = { urgent: 100, high: 70, normal: 40, low: 20 };
const TEMPLATE_CACHE_TTL = 6 * 60 * 60; // 6 h
const PER_CROP_CAP = 1;
const GLOBAL_CAP = 3;

function dayBucket(d) {
  const dt = d ? new Date(d) : new Date();
  return dt.toISOString().slice(0, 10);
}

function daysSinceSowing(sowingDate, now = new Date()) {
  if (!sowingDate) return null;
  const then = new Date(sowingDate).getTime();
  if (Number.isNaN(then)) return null;
  return Math.max(0, Math.floor((now.getTime() - then) / (24 * 60 * 60 * 1000)));
}

function stageFromDays(days) {
  if (days == null) return 'pre_sowing';
  if (days < 0) return 'pre_sowing';
  if (days < 14) return 'germination';
  if (days < 30) return 'seedling';
  if (days < 60) return 'vegetative';
  if (days < 80) return 'flowering';
  if (days < 110) return 'fruiting';
  if (days < 140) return 'maturity';
  return 'harvested';
}

function effectiveStage(crop, days) {
  // Trust the user's manual selection in the FarmProfile crop entry over the
  // date math. Falls back to date math if not explicit.
  if (crop.growthStage && STAGES.includes(crop.growthStage)) return crop.growthStage;
  return stageFromDays(days);
}

function seasonFromSowingMonth(month) {
  // Indian agri seasons keyed off SOWING month — what `CropTaskTemplate.seasons`
  // intends to filter on. A tomato sown in February is a Rabi tomato regardless
  // of when in the season we're asking.
  //   Kharif sowing: Jun–Oct (rains)
  //   Rabi sowing:   Nov–Mar
  //   Zaid sowing:   Apr–May (summer)
  if (month >= 6 && month <= 10) return 'Kharif';
  if (month === 11 || month === 12 || month <= 3) return 'Rabi';
  return 'Zaid';
}

function seasonForCrop(crop, fallbackNow) {
  if (crop?.sowingDate) {
    const m = new Date(crop.sowingDate).getMonth() + 1;
    return seasonFromSowingMonth(m);
  }
  // Fallback: today's month — preserves old behavior for crops without a
  // sowing date.
  return seasonFromSowingMonth((fallbackNow || new Date()).getMonth() + 1);
}

function regionFromProfile(profile) {
  return profile?.address?.state || null;
}

async function loadEligibleTemplates({ cropId, stage, daysSinceSowing: dss, season, region }) {
  if (!cropId) return [];
  const cacheKey = `tpl-cache:${cropId}:${stage}`;
  if (redis) {
    try {
      const cached = await redis.get(cacheKey);
      if (cached) {
        const parsed = JSON.parse(cached);
        return parsed.filter((t) => insideRangeAndScope(t, dss, season, region));
      }
    } catch (err) {
      // fall through
    }
  }
  const docs = await CropTaskTemplate.find({
    cropId,
    isActive: true,
    stage,
  }).lean();
  if (redis) {
    try {
      await redis.setex(cacheKey, TEMPLATE_CACHE_TTL, JSON.stringify(docs));
    } catch (err) {
      // best-effort
    }
  }
  return docs.filter((t) => insideRangeAndScope(t, dss, season, region));
}

function insideRangeAndScope(t, dss, season, region) {
  if (typeof dss === 'number') {
    if (typeof t.daysFromSowingMin === 'number' && dss < t.daysFromSowingMin) return false;
    if (typeof t.daysFromSowingMax === 'number' && dss > t.daysFromSowingMax) return false;
  }
  if (Array.isArray(t.seasons) && t.seasons.length && season && !t.seasons.includes(season)) {
    return false;
  }
  if (Array.isArray(t.regions) && t.regions.length && region && !t.regions.includes(region)) {
    return false;
  }
  return true;
}

function weatherAllows(template, snapshot) {
  if (!snapshot) return { ok: true, tags: ['no_weather_check'] }; // fail open
  if (!Array.isArray(snapshot.days) || snapshot.days.length < 4) {
    return { ok: true, tags: ['no_weather_check'] };
  }
  const wx = template.weather || {};
  const today = snapshot.days[3];
  const tomorrow = snapshot.days[4];
  const tags = [];

  if (wx.requiresDryDays > 0) {
    const lookahead = snapshot.days.slice(4, 4 + wx.requiresDryDays);
    const anyRain = lookahead.some((d) => Number(d?.rainfallMm || 0) > 1);
    if (anyRain) {
      return { ok: false, tags: ['rain_in_window'] };
    }
    tags.push(`no_rain_${wx.requiresDryDays}d`);
  }
  if (wx.maxRainfallMmTomorrow != null) {
    const r = Number(tomorrow?.rainfallMm || 0);
    if (r > wx.maxRainfallMmTomorrow) {
      return { ok: false, tags: [`heavy_rain_${Math.round(r)}mm_tomorrow`] };
    }
  }
  if (wx.minTempC != null && Number(today?.tempMin ?? 99) < wx.minTempC) {
    return { ok: false, tags: ['cold_today'] };
  }
  if (wx.maxTempC != null && Number(today?.tempMax ?? -99) > wx.maxTempC) {
    return { ok: false, tags: ['hot_today'] };
  }
  if (wx.requiresMoistSoil) {
    const last48 = snapshot.days.slice(1, 4);
    const totalRain = last48.reduce((s, d) => s + Number(d?.rainfallMm || 0), 0);
    if (totalRain < 2) {
      return { ok: false, tags: ['soil_dry_recently'] };
    }
    tags.push('soil_moist');
  }
  return { ok: true, tags };
}

function buildJournalIndex(rows) {
  // Map<`cropEntryId:verb`, mostRecentDate>
  const map = new Map();
  for (const row of rows || []) {
    if (row?.isDeleted) continue;
    const key = `${String(row.cropEntryId)}:${row.verb}`;
    const at = new Date(row.occurredAt || row.createdAt || Date.now()).getTime();
    const prev = map.get(key);
    if (!prev || at > prev) map.set(key, at);
  }
  return map;
}

function passesCooldown(template, cropEntryId, journalIndex) {
  const cd = template.cooldownDays;
  if (!cd || cd <= 0) return true;
  const last = journalIndex.get(`${String(cropEntryId)}:${template.verb}`);
  if (!last) return true;
  const days = (Date.now() - last) / 86_400_000;
  return days >= cd;
}

function recentlySkippedSameVerb(journalIndex, cropEntryId, verb) {
  // Skip-aware boost: if user recently SKIPPED the same verb, the engine
  // promotes a different action over re-suggesting the skipped one. This is
  // a coarse signal from the index alone — we boost by a fixed amount for
  // the dual case (this is a placeholder; full skip detection happens in
  // ActivityJournal.source filter at call site).
  return false;
}

function scoreCandidate(template, ctx) {
  let score = URGENCY_SCORE[template.urgency] || 0;
  // Stage-fit: middle 50% of the day window scores higher.
  if (
    typeof template.daysFromSowingMin === 'number' &&
    typeof template.daysFromSowingMax === 'number' &&
    typeof ctx.daysSinceSowing === 'number'
  ) {
    const lo = template.daysFromSowingMin;
    const hi = template.daysFromSowingMax;
    const span = Math.max(1, hi - lo);
    const pos = (ctx.daysSinceSowing - lo) / span;
    if (pos >= 0.25 && pos <= 0.75) score += 10;
  }
  // Weather pressure: dry-only requirement met → bonus
  if ((template.weather?.requiresDryDays || 0) > 0) score += 20;
  if (recentlySkippedSameVerb(ctx.journalIndex, ctx.cropEntryId, template.verb)) {
    score += 25;
  }
  return score;
}

function makeItemId(parts) {
  return crypto
    .createHash('sha1')
    .update(parts.join('|'))
    .digest('hex')
    .slice(0, 24);
}

function pickPerCropTopK(candidates, k = PER_CROP_CAP) {
  return candidates
    .sort((a, b) => b._score - a._score || a.template.cropName.localeCompare(b.template.cropName))
    .slice(0, k);
}

function selectGlobal(perCropPicks, cap = GLOBAL_CAP) {
  const flat = perCropPicks.flat();
  // Sort: urgency-first, then score, then crop-name alphabetical for stability.
  const URGENCY_ORDER = { urgent: 0, high: 1, normal: 2, low: 3 };
  flat.sort((a, b) => {
    const u = (URGENCY_ORDER[a.template.urgency] ?? 2) - (URGENCY_ORDER[b.template.urgency] ?? 2);
    if (u !== 0) return u;
    if (b._score !== a._score) return b._score - a._score;
    return (a.template.cropName || '').localeCompare(b.template.cropName || '');
  });
  return flat.slice(0, cap);
}

/**
 * Public entry: produce per-crop candidate items + the selected global items.
 *
 * Inputs:
 *   profile        FarmProfile.lean()
 *   weather        WeatherSnapshot.lean() OR null
 *   journal        recent ActivityJournal rows (last 30d)
 *   now            optional Date for tests
 *
 * Returns:
 *   {
 *     items: [actionItemSeed],
 *     perCrop: { [cropEntryId]: { picks, eligibleCount, droppedReason? } },
 *     unmatched: [cropEntryId]   // crops with 0 eligible — feed AI fallback
 *   }
 */
async function recommend(profile, weather, journal, now = new Date()) {
  const journalIndex = buildJournalIndex(journal);
  const region = regionFromProfile(profile);

  const perCrop = {};
  const unmatched = [];
  const allPicks = [];

  for (const crop of profile.crops || []) {
    if (!crop.isActive && crop.isActive !== undefined) continue;
    const cropEntryId = String(crop._id);
    const dss = daysSinceSowing(crop.sowingDate, now);
    const stage = effectiveStage(crop, dss);
    const season = seasonForCrop(crop, now);

    const templates = await loadEligibleTemplates({
      cropId: crop.cropId,
      stage,
      daysSinceSowing: dss,
      season,
      region,
    });

    const candidates = [];
    for (const t of templates) {
      const wx = weatherAllows(t, weather);
      if (!wx.ok) continue;
      if (!passesCooldown(t, cropEntryId, journalIndex)) continue;
      const ctx = { daysSinceSowing: dss, cropEntryId, journalIndex };
      const _score = scoreCandidate(t, ctx);
      const stageTags = [
        `${dss == null ? 'unknown' : dss}_days_after_sowing`,
        `${stage}_stage`,
      ];
      candidates.push({
        template: t,
        _score,
        rationaleTags: [...stageTags, ...wx.tags],
      });
    }

    perCrop[cropEntryId] = { eligibleCount: candidates.length };

    if (candidates.length === 0) {
      unmatched.push({
        cropEntryId,
        crop,
        daysSinceSowing: dss,
        stage,
        reason: 'no_eligible_template',
      });
      continue;
    }

    const picks = pickPerCropTopK(candidates, PER_CROP_CAP).map((c) => ({
      ...c,
      cropEntryId,
      crop,
      daysSinceSowing: dss,
      stage,
    }));
    perCrop[cropEntryId].picks = picks.length;
    allPicks.push(picks);
  }

  const selected = selectGlobal(allPicks, GLOBAL_CAP);
  const items = selected.map((pick) => {
    const t = pick.template;
    return {
      itemId: makeItemId([
        'tpl',
        String(t._id),
        String(pick.cropEntryId),
        dayBucket(now),
      ]),
      cropEntryId: pick.cropEntryId,
      cropName: pick.crop.cropName,
      cropVariety: pick.crop.variety,
      templateId: t._id,
      template: t, // localizer needs the full template doc
      source: 'template',
      verb: t.verb,
      chemical: t.chemical,
      dose: t.dose,
      urgency: t.urgency,
      rationaleTags: pick.rationaleTags,
    };
  });

  return { items, perCrop, unmatched };
}

module.exports = {
  recommend,
  // Exported for tests:
  _internal: {
    daysSinceSowing,
    stageFromDays,
    effectiveStage,
    seasonFromSowingMonth,
    seasonForCrop,
    weatherAllows,
    buildJournalIndex,
    passesCooldown,
    scoreCandidate,
    pickPerCropTopK,
    selectGlobal,
    makeItemId,
    PER_CROP_CAP,
    GLOBAL_CAP,
  },
};
