/**
 * M-A2 — seed `CropTaskTemplate` from existing `CropCalendar.Activity` rows.
 *
 * Strategy:
 *   1. For every active `CropCalendar` doc, walk its `activities[]`.
 *   2. Resolve each `activityId` to its `Activity` document.
 *   3. Map `Activity.category + name` → a CropTaskTemplate `verb`.
 *   4. Compute the day-from-sowing window from the calendar's month + week.
 *   5. Insert a CropTaskTemplate with `seedSource: "calendar_seed"` and
 *      `isActive: false` so the agronomy team has to flip it on after review.
 *   6. Idempotent: re-running upserts on a stable composite key
 *      `(cropId, verb, daysFromSowingMin, daysFromSowingMax, stage)`.
 *
 * Usage:
 *   node src/scripts/migrations/m-A2-seed-templates.js [--dry-run]
 *
 * Recommended: run with --dry-run first, eyeball the planned inserts, then
 * run for real.
 */
const path = require('path');
const dotenv = require('dotenv');
dotenv.config({ path: path.resolve(__dirname, '../../../.env.development') });
dotenv.config({ path: path.resolve(__dirname, '../../../.env') });

const mongoose = require('mongoose');
const Crop = require('../../model/CropCalendar/Crop');
const CropCalendar = require('../../model/CropCalendar/CropCalendar');
const Activity = require('../../model/CropCalendar/Activity');
const CropTaskTemplate = require('../../model/CropTaskTemplate');

const DRY_RUN = process.argv.includes('--dry-run');

// Loose name matchers; ordered most-specific first.
const NAME_PATTERNS = [
  { re: /(fung|blight|powdery|downy|rust)/i,           verb: 'spray_fungicide',   urgency: 'high',   weather: { requiresDryDays: 1 } },
  { re: /(insect|pest|aphid|whitefly|thrips|mealybug|caterpillar|borer|larva)/i, verb: 'spray_insecticide', urgency: 'high', weather: { requiresDryDays: 1 } },
  { re: /(weed|herbic|pre[- ]?emerg|post[- ]?emerg)/i, verb: 'spray_herbicide',   urgency: 'normal' },
  { re: /(npk|urea|dap|potash|fert|nutrient|nitrogen|phosphor|micro)/i, verb: 'fertilize', urgency: 'normal' },
  { re: /(irrigat|water|drip|sprinkl|sinch|sinchai|paani|pani)/i,        verb: 'irrigate', urgency: 'normal', weather: { requiresMoistSoil: false } },
  { re: /(scout|inspect|monitor|niri|paahani|paachani|observation)/i,  verb: 'scout', urgency: 'normal' },
  { re: /(weed(?!.*kill)|niraai|niranee|hoeing)/i,                       verb: 'weed', urgency: 'normal' },
  { re: /(prune|chhaant|chhantni|trim)/i,                                verb: 'prune', urgency: 'normal' },
  { re: /(stake|tying|trellis|support)/i,                                verb: 'stake', urgency: 'normal' },
  { re: /(thin|gap fill|seedling thinning|virlni)/i,                     verb: 'thin', urgency: 'low' },
  { re: /(harvest|pick|cutting|kapni|katai)/i,                           verb: 'harvest_check', urgency: 'high' },
  { re: /(soil test|maati pariksha|miti par)/i,                           verb: 'soil_test', urgency: 'low' },
  { re: /(mulch|achchhadan|achadan)/i,                                    verb: 'mulch', urgency: 'low' },
];

const CATEGORY_FALLBACK = {
  'Pre-planting': { verb: 'soil_test', urgency: 'low' },
  Planting: { verb: 'fertilize', urgency: 'normal' },
  'Growth Management': { verb: 'scout', urgency: 'normal' },
  'Nutrient Management': { verb: 'fertilize', urgency: 'normal' },
  Maintenance: { verb: 'weed', urgency: 'normal' },
  Fertilization: { verb: 'fertilize', urgency: 'normal' },
  'Pest Control': { verb: 'spray_insecticide', urgency: 'high', weather: { requiresDryDays: 1 } },
  Harvest: { verb: 'harvest_check', urgency: 'high' },
};

const STAGE_NORMALIZE = {
  pre_sowing: 'pre_sowing', presowing: 'pre_sowing', pre: 'pre_sowing',
  germination: 'germination',
  seedling: 'seedling', sapling: 'seedling',
  vegetative: 'vegetative', growth: 'vegetative',
  flowering: 'flowering', flower: 'flowering',
  fruiting: 'fruiting', fruit: 'fruiting',
  maturity: 'maturity', mature: 'maturity',
  harvested: 'harvested', harvest: 'harvested',
};

function pickVerb(activity) {
  const text = `${activity.name || ''} ${activity.description || ''}`;
  for (const p of NAME_PATTERNS) if (p.re.test(text)) return { verb: p.verb, urgency: p.urgency, weather: p.weather };
  const fb = CATEGORY_FALLBACK[activity.category];
  if (fb) return fb;
  return null;
}

function normalizeStage(raw) {
  if (!raw) return 'vegetative';
  const k = String(raw).toLowerCase().replace(/[^a-z]/g, '');
  return STAGE_NORMALIZE[k] || 'vegetative';
}

function dayWindow(stage, week) {
  // Convert calendar `month + week` (which we don't know absolutely without
  // the sowing date) into a stage-based default window. The CropCalendar
  // is anchored to month-of-year, not days-from-sowing — so we approximate
  // using the stage's typical day band.
  const STAGE_BANDS = {
    pre_sowing:  [0, 0],
    germination: [0, 14],
    seedling:    [14, 30],
    vegetative:  [30, 60],
    flowering:   [60, 80],
    fruiting:    [80, 110],
    maturity:    [110, 140],
    harvested:   [140, 180],
  };
  const band = STAGE_BANDS[stage] || [30, 60];
  const w = Math.max(1, Math.min(4, Number(week) || 1));
  // Narrow within the band by week index for more granular templates.
  const span = band[1] - band[0];
  const lo = Math.round(band[0] + ((w - 1) / 4) * span);
  const hi = Math.round(band[0] + (w / 4) * span);
  return [Math.max(0, lo), Math.max(lo + 1, hi)];
}

function buildTitleTemplate(activity, verb) {
  if (verb === 'spray_fungicide') return 'Spray fungicide on {crop}';
  if (verb === 'spray_insecticide') return 'Spray insecticide on {crop}';
  if (verb === 'spray_herbicide') return 'Spray herbicide on {crop}';
  if (verb === 'fertilize') return 'Apply fertilizer to {crop}';
  if (verb === 'irrigate') return 'Irrigate {crop}';
  if (verb === 'scout') return 'Scout {crop} for pests/disease';
  if (verb === 'weed') return 'Weed {crop} field';
  if (verb === 'prune') return 'Prune {crop}';
  if (verb === 'stake') return 'Stake {crop} plants';
  if (verb === 'thin') return 'Thin {crop} seedlings';
  if (verb === 'harvest_check') return 'Check {crop} for harvest readiness';
  if (verb === 'soil_test') return 'Send soil sample for testing';
  if (verb === 'mulch') return 'Apply mulch to {crop}';
  return activity.name ? `${activity.name} for {crop}` : `Tend {crop}`;
}

function buildDetailTemplate(activity, verb) {
  // Prefer the CropCalendar's instructions when present.
  const instr = (activity.description || '').trim();
  if (instr) return instr.length > 600 ? `${instr.slice(0, 597)}...` : instr;
  if (verb === 'spray_fungicide') return 'Cover both leaf surfaces. {weatherClause}';
  if (verb === 'spray_insecticide') return 'Spray early morning or evening. {weatherClause}';
  if (verb === 'irrigate') return 'Water based on soil moisture and {weatherClause}.';
  return '';
}

function buildSafetyNote(activity, verb) {
  if (verb === 'spray_fungicide' || verb === 'spray_insecticide' || verb === 'spray_herbicide') {
    return 'Wear gloves and a mask. Do not spray within 7 days of harvest.';
  }
  return undefined;
}

async function up() {
  await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/farmer-chat');
  console.log(`[M-A2] connected. dryRun=${DRY_RUN}`);

  const crops = await Crop.find({ status: 'active' }).lean();
  const cropById = new Map(crops.map((c) => [String(c._id), c]));
  console.log(`[M-A2] found ${crops.length} active crops`);

  const calendars = await CropCalendar.find({ status: 'active' }).lean();
  console.log(`[M-A2] found ${calendars.length} crop-calendar rows`);

  const activityIds = new Set();
  for (const cal of calendars) {
    for (const a of cal.activities || []) if (a.activityId) activityIds.add(String(a.activityId));
  }
  const activities = await Activity.find({ _id: { $in: Array.from(activityIds) } }).lean();
  const activityById = new Map(activities.map((a) => [String(a._id), a]));

  let inspected = 0;
  let mappedCount = 0;
  let upsertCount = 0;
  let skippedNoVerb = 0;
  let skippedNoCrop = 0;

  for (const cal of calendars) {
    const crop = cropById.get(String(cal.cropId));
    if (!crop) {
      skippedNoCrop += (cal.activities || []).length;
      continue;
    }
    const stage = normalizeStage(cal.growthStage);

    for (const a of cal.activities || []) {
      inspected += 1;
      const activity = activityById.get(String(a.activityId));
      if (!activity) continue;
      const mapping = pickVerb(activity);
      if (!mapping) {
        skippedNoVerb += 1;
        continue;
      }
      mappedCount += 1;
      const [dmin, dmax] = dayWindow(stage, a.timing?.week);
      const titleTemplate = buildTitleTemplate(activity, mapping.verb);
      const detailTemplate = buildDetailTemplate(
        { description: a.instructions || activity.description },
        mapping.verb
      );
      const safetyNote = buildSafetyNote(activity, mapping.verb);

      const filter = {
        cropId: cal.cropId,
        verb: mapping.verb,
        stage,
        daysFromSowingMin: dmin,
        daysFromSowingMax: dmax,
      };
      const update = {
        $setOnInsert: {
          cropId: cal.cropId,
          cropName: crop.name,
          stage,
          daysFromSowingMin: dmin,
          daysFromSowingMax: dmax,
          verb: mapping.verb,
          titleTemplate,
          detailTemplate,
          safetyNote,
          urgency: mapping.urgency || 'normal',
          weather: mapping.weather || {},
          cooldownDays: mapping.verb.startsWith('spray_') ? 6 : 7,
          isActive: false, // requires agronomy signoff before turning on
          seedSource: 'calendar_seed',
          sourceRefs: [`CropCalendar/${cal._id}`, `Activity/${activity._id}`],
        },
      };

      if (DRY_RUN) {
        console.log('[dry-run]', { crop: crop.name, ...filter, titleTemplate });
      } else {
        await CropTaskTemplate.updateOne(filter, update, { upsert: true });
        upsertCount += 1;
      }
    }
  }

  console.log('[M-A2] inspected:', inspected);
  console.log('[M-A2] mapped:   ', mappedCount);
  console.log('[M-A2] skipped (no verb): ', skippedNoVerb);
  console.log('[M-A2] skipped (no crop): ', skippedNoCrop);
  console.log('[M-A2] upserts done:', upsertCount, DRY_RUN ? '(dry run)' : '');
  console.log('[M-A2] reminder: all seeded templates have isActive=false. Agronomy team must signoff per template.');

  await mongoose.disconnect();
  console.log('[M-A2] done');
}

if (require.main === module) {
  up().catch((err) => {
    console.error('[M-A2] failed:', err.message, err.stack);
    process.exit(1);
  });
}

module.exports = { up };
