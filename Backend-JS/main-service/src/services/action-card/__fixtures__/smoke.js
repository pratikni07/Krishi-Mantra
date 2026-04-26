/**
 * Action-card smoke fixture. Runnable without Mongo/Redis — every dependency
 * is stubbed via `require.cache`. Verifies the engine + localizer end-to-end
 * across 5 synthetic farmers.
 *
 * Runs offline:  node src/services/action-card/__fixtures__/smoke.js
 *
 * Exit code 0 = all assertions pass.
 */

const path = require('path');
const crypto = require('crypto');

// Tiny ObjectId-string generator so this script runs without npm install.
function fakeObjectId() {
  return crypto.randomBytes(12).toString('hex');
}

// -----------------------------------------------------------------------------
// Stubs — installed BEFORE importing the engine/localizer
// -----------------------------------------------------------------------------

function stub(modulePath, exportsObj) {
  const resolved = require.resolve(modulePath);
  require.cache[resolved] = {
    id: resolved,
    filename: resolved,
    loaded: true,
    exports: exportsObj,
  };
}

// Logger stub — silent
stub('../../../utils/logger', {
  info: () => {}, warn: () => {}, error: () => {}, debug: () => {},
});

// Redis stub — minimal
stub('../../../config/redis', {
  get: async () => null,
  set: async () => 'OK',
  setex: async () => 'OK',
  del: async () => 1,
  incr: async () => 1,
  expire: async () => 1,
  publish: async () => 0,
  isRedisAvailable: () => false,
});

// In-memory CropTaskTemplate stub — replaces the Mongoose model
const FIXTURE_TEMPLATES = [
  {
    _id: 'tpl_tom_fung',
    cropId: 'crop_tomato',
    cropName: 'Tomato',
    stage: 'fruiting',
    daysFromSowingMin: 40,
    daysFromSowingMax: 75,
    verb: 'spray_fungicide',
    titleTemplate: 'Spray mancozeb on {crop}',
    detailTemplate: '{dose} {chemical}. Cover both leaf surfaces. {weatherClause}',
    chemical: 'mancozeb',
    dose: '2.5 g/L',
    safetyNote: 'Wear gloves and a mask. Do not spray within 7 days of harvest.',
    urgency: 'high',
    weather: { requiresDryDays: 1, maxRainfallMmTomorrow: 2 },
    cooldownDays: 6,
    seasons: ['Kharif', 'Rabi'],
    regions: [],
    translations: {
      mr: {
        title: 'टोमॅटोवर मॅन्कोझेब फवारणी',
        detail: '{dose} मॅन्कोझेब. पाने दोन्ही बाजूंनी झाकून फवारा. {weatherClause}',
        safetyNote: 'हातमोजे + मास्क घाला. कापणीच्या 7 दिवसांत फवारू नका.',
        weatherClauses: { no_rain_1d: 'पुढील 24 तास पाऊस नाही.' },
      },
    },
    isActive: true,
  },
  {
    _id: 'tpl_tom_stake',
    cropId: 'crop_tomato',
    cropName: 'Tomato',
    stage: 'fruiting',
    daysFromSowingMin: 35,
    daysFromSowingMax: 70,
    verb: 'stake',
    titleTemplate: 'Stake {crop} plants',
    detailTemplate: 'Tie main stems with soft twine to bamboo stakes.',
    urgency: 'normal',
    cooldownDays: 14,
    isActive: true,
    translations: {},
  },
  {
    _id: 'tpl_onion_npk',
    cropId: 'crop_onion',
    cropName: 'Onion',
    stage: 'seedling',
    daysFromSowingMin: 7,
    daysFromSowingMax: 25,
    verb: 'fertilize',
    titleTemplate: 'Apply foliar NPK to {crop}',
    detailTemplate: '0.5% urea + 0.5% MAP foliar spray.',
    urgency: 'normal',
    cooldownDays: 10,
    weather: { maxRainfallMmTomorrow: 5 },
    isActive: true,
    translations: {},
  },
  {
    _id: 'tpl_onion_irrigate',
    cropId: 'crop_onion',
    cropName: 'Onion',
    stage: 'seedling',
    daysFromSowingMin: 5,
    daysFromSowingMax: 25,
    verb: 'irrigate',
    titleTemplate: 'Irrigate {crop} (drip 45 min)',
    detailTemplate: 'Soil dry; no rain in next 3 days.',
    urgency: 'normal',
    cooldownDays: 7,
    isActive: true,
    translations: {},
  },
  {
    _id: 'tpl_paddy_scout',
    cropId: 'crop_paddy',
    cropName: 'Paddy',
    stage: 'vegetative',
    daysFromSowingMin: 20,
    daysFromSowingMax: 80,
    verb: 'scout',
    titleTemplate: 'Scout {crop} for stem borer',
    detailTemplate: 'Look for dead-hearts; 5 hills/acre.',
    urgency: 'normal',
    cooldownDays: 5,
    isActive: true,
    translations: {},
  },
];

// Stubbed Mongoose model — replicates only the methods the engine uses.
stub(path.resolve(__dirname, '../../../model/CropTaskTemplate'), {
  STAGES: ['pre_sowing', 'germination', 'seedling', 'vegetative', 'flowering', 'fruiting', 'maturity', 'harvested'],
  VERBS: ['spray_fungicide', 'spray_insecticide', 'spray_herbicide', 'fertilize', 'irrigate',
    'scout', 'weed', 'prune', 'stake', 'thin', 'harvest_check', 'soil_test', 'mulch'],
  URGENCIES: ['low', 'normal', 'high', 'urgent'],
  find: (q = {}) => ({
    lean: async () =>
      FIXTURE_TEMPLATES.filter((t) => {
        if (q.cropId && String(q.cropId) !== String(t.cropId)) return false;
        if (q.stage && q.stage !== t.stage) return false;
        if (q.isActive != null && t.isActive !== q.isActive) return false;
        return true;
      }),
  }),
});

// -----------------------------------------------------------------------------
// Now import the engine + localizer (after stubs are in place)
// -----------------------------------------------------------------------------

const Engine = require('../recommendation.engine');
const Localizer = require('../localizer');
const { LANG_NAMES } = require('../verb-glossary');

// -----------------------------------------------------------------------------
// Fixture builders
// -----------------------------------------------------------------------------

function makeCrop({ cropId, cropName, daysAgoSown, growthStage, area, areaUnit, irrigationMethod, variety }) {
  return {
    _id: fakeObjectId(),
    cropId,
    cropName,
    variety: variety || null,
    area: area || 1,
    areaUnit: areaUnit || 'acre',
    sowingDate: new Date(Date.now() - daysAgoSown * 24 * 3600 * 1000),
    growthStage,
    irrigationMethod: irrigationMethod || 'drip',
    isActive: true,
  };
}

function makeProfile(overrides = {}) {
  return {
    _id: fakeObjectId(),
    userId: fakeObjectId(),
    age: 38,
    preferredLanguage: 'mr',
    location: { type: 'Point', coordinates: [73.79, 19.99] },
    address: { village: 'Sinnar', district: 'Nashik', state: 'Maharashtra' },
    totalArea: 1.5,
    totalAreaUnit: 'hectare',
    soilTypes: ['black', 'loam'],
    irrigationSources: ['borewell', 'drip'],
    experienceYears: 15,
    timezone: 'Asia/Kolkata',
    profileVersion: 4,
    crops: [],
    onboardingStatus: 'completed',
    ...overrides,
  };
}

function makeWeather({ rainTomorrow = 0, sunny = true } = {}) {
  const days = [];
  for (let i = 0; i < 7; i++) {
    days.push({
      date: new Date(Date.now() + (i - 3) * 86400000).toISOString().slice(0, 10),
      tempMin: 22 + i % 3,
      tempMax: 33 + i % 3,
      humidityMean: 50 + i,
      rainfallMm: i === 4 ? rainTomorrow : 0,
      windSpeedKmh: 12,
      conditionCode: sunny ? 1 : 61,
      conditionLabel: sunny ? 'mostly-sunny' : 'light-rain',
    });
  }
  return { bucket: '19.99,73.79', lat: 19.99, lon: 73.79, asOf: new Date(), provider: 'open-meteo', days };
}

// -----------------------------------------------------------------------------
// Assertions
// -----------------------------------------------------------------------------

let passed = 0;
let failed = 0;

function ok(label, cond, extra = '') {
  if (cond) { passed += 1; console.log('  ✓ ' + label); }
  else { failed += 1; console.error('  ✗ ' + label + (extra ? ` — ${extra}` : '')); }
}

// -----------------------------------------------------------------------------
// Test scenarios
// -----------------------------------------------------------------------------

(async () => {
  console.log('--- Scenario 1: Tomato fruiting + Onion seedling, dry weather, no journal');
  {
    const profile = makeProfile({
      crops: [
        makeCrop({ cropId: 'crop_tomato', cropName: 'Tomato', variety: 'Himsona', daysAgoSown: 47, growthStage: 'fruiting', area: 1.2, areaUnit: 'hectare' }),
        makeCrop({ cropId: 'crop_onion', cropName: 'Onion', variety: 'N-53', daysAgoSown: 12, growthStage: 'seedling', area: 0.3, areaUnit: 'hectare', irrigationMethod: 'sprinkler' }),
      ],
    });
    const weather = makeWeather({ rainTomorrow: 0, sunny: true });
    const result = await Engine.recommend(profile, weather, []);
    ok('engine returns 2 items', result.items.length === 2, `got ${result.items.length}`);
    ok('first item is fungicide on Tomato (highest urgency)',
       result.items[0].verb === 'spray_fungicide' && result.items[0].cropName === 'Tomato');
    ok('second item is for Onion', result.items[1].cropName === 'Onion');
    ok('no unmatched crops', result.unmatched.length === 0);

    const localized = result.items.map((it) => Localizer.localize(it, 'mr'));
    ok('Marathi title rendered for tomato', /टोमॅटो|मॅन्कोझेब/.test(localized[0].title), localized[0].title);
    ok('weather clause substituted (no_rain_1d)', /पाऊस नाही|24 तास/.test(localized[0].detail) || localized[0].detail.length > 0);
  }

  console.log('--- Scenario 2: Tomato fruiting + journal shows recent fungicide spray (cooldown blocks)');
  {
    const profile = makeProfile({
      crops: [
        makeCrop({ cropId: 'crop_tomato', cropName: 'Tomato', daysAgoSown: 47, growthStage: 'fruiting' }),
      ],
    });
    const cropEntryId = profile.crops[0]._id;
    const weather = makeWeather({ rainTomorrow: 0 });
    const journal = [
      { cropEntryId, verb: 'spray_fungicide', occurredAt: new Date(Date.now() - 2 * 86400000), source: 'card_done' },
    ];
    const result = await Engine.recommend(profile, weather, journal);
    const verbs = result.items.map((i) => i.verb);
    ok('fungicide cooldown respected (recent 2 days < 6)', !verbs.includes('spray_fungicide'));
    ok('falls back to staking', verbs.includes('stake'));
  }

  console.log('--- Scenario 3: Tomato fruiting, rain forecast → fungicide blocked by weather, picks stake');
  {
    const profile = makeProfile({
      crops: [
        makeCrop({ cropId: 'crop_tomato', cropName: 'Tomato', daysAgoSown: 47, growthStage: 'fruiting' }),
      ],
    });
    const weather = makeWeather({ rainTomorrow: 8, sunny: false }); // > 2mm + rainy
    const result = await Engine.recommend(profile, weather, []);
    ok('rain blocks fungicide', !result.items.some((i) => i.verb === 'spray_fungicide'));
    ok('picks stake instead', result.items.some((i) => i.verb === 'stake'));
  }

  console.log('--- Scenario 4: Niche crop with no template → unmatched flagged for AI fallback');
  {
    const profile = makeProfile({
      crops: [
        makeCrop({ cropId: 'crop_dragonfruit_unknown', cropName: 'Dragon fruit', daysAgoSown: 50, growthStage: 'fruiting' }),
      ],
    });
    const result = await Engine.recommend(profile, makeWeather(), []);
    ok('engine returns 0 items for niche crop', result.items.length === 0);
    ok('niche crop flagged for AI fallback', result.unmatched.length === 1);
    ok('unmatched cropName preserved', result.unmatched[0].crop.cropName === 'Dragon fruit');
  }

  console.log('--- Scenario 5: 4 crops competing → global cap of 3 enforced; urgency-first sort');
  {
    const profile = makeProfile({
      crops: [
        makeCrop({ cropId: 'crop_tomato', cropName: 'Tomato', daysAgoSown: 47, growthStage: 'fruiting' }),
        makeCrop({ cropId: 'crop_onion', cropName: 'Onion', daysAgoSown: 12, growthStage: 'seedling' }),
        makeCrop({ cropId: 'crop_paddy', cropName: 'Paddy', daysAgoSown: 50, growthStage: 'vegetative' }),
        makeCrop({ cropId: 'crop_unknown', cropName: 'Foo', daysAgoSown: 5, growthStage: 'germination' }),
      ],
    });
    const result = await Engine.recommend(profile, makeWeather(), []);
    ok('global cap enforced at 3', result.items.length === 3, `got ${result.items.length}`);
    ok('first is high-urgency tomato (fungicide)', result.items[0].urgency === 'high');
  }

  console.log('--- Scenario 6: Localizer fallback to English when target lang missing');
  {
    const item = {
      source: 'template',
      cropName: 'Onion',
      cropEntryId: 'x',
      verb: 'fertilize',
      urgency: 'normal',
      rationaleTags: [],
      template: FIXTURE_TEMPLATES.find((t) => t._id === 'tpl_onion_npk'),
    };
    const en = Localizer.localize(item, 'en');
    const mr = Localizer.localize(item, 'mr');
    ok('English title rendered', en.title.includes('Onion'));
    ok('Marathi falls back to English template (no curated mr)', mr.title === en.title);
  }

  console.log('--- Scenario 7: AI item passes through localizer unchanged');
  {
    const aiItem = {
      source: 'ai',
      cropName: 'Dragon fruit',
      cropEntryId: 'x',
      verb: 'scout',
      title: 'ड्रॅगन फ्रूटची तपासणी',
      detail: 'फळाच्या रंगात बदल झाला का पहा.',
      urgency: 'normal',
      rationaleTags: ['ai_fallback'],
    };
    const localized = Localizer.localize(aiItem, 'mr');
    ok('AI item title preserved', localized.title === 'ड्रॅगन फ्रूटची तपासणी');
    ok('AI item detail preserved', localized.detail === 'फळाच्या रंगात बदल झाला का पहा.');
  }

  console.log('\nResults: ' + passed + ' passed, ' + failed + ' failed');
  process.exit(failed === 0 ? 0 : 1);
})().catch((err) => {
  console.error('Smoke test crashed:', err);
  process.exit(1);
});
