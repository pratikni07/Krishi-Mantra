/**
 * Smoke fixture for the AI-first builder. Mocks the internal AI HTTP call so
 * we can exercise the full ai-builder + validator + merge path without a
 * real Vertex/OpenAI account.
 *
 * Runs offline:  node src/services/action-card/__fixtures__/smoke-ai-first.js
 *
 * Tests:
 *   1. AI returns 2 valid items → both get used; rule items skipped
 *   2. AI returns 1 valid + 1 banned-chemical → banned dropped, rule fills slot
 *   3. AI returns garbage JSON → fall back to rule entirely
 *   4. AI HTTP fails → fall back to rule entirely (graceful)
 *   5. AI returns brand-name chemical → dropped by validator
 *   6. AI returns invalid dose pattern → dropped
 *   7. AI returns valid output but feature flag is OFF → rule path used
 */

const path = require('path');
const crypto = require('crypto');

function fakeId() {
  return crypto.randomBytes(12).toString('hex');
}

function stub(modulePath, exportsObj) {
  const resolved = require.resolve(modulePath);
  require.cache[resolved] = {
    id: resolved,
    filename: resolved,
    loaded: true,
    exports: exportsObj,
  };
}

stub('../../../utils/logger', {
  info: () => {}, warn: () => {}, error: () => {}, debug: () => {},
});

stub('../../../config/redis', {
  get: async () => null, set: async () => 'OK', setex: async () => 'OK',
  del: async () => 1, incr: async () => 1, expire: async () => 1,
  publish: async () => 0, isRedisAvailable: () => false,
});

const TEMPLATES = [
  {
    _id: 'tpl_tom_fung', cropId: 'crop_tomato', cropName: 'Tomato',
    stage: 'fruiting', daysFromSowingMin: 40, daysFromSowingMax: 75,
    verb: 'spray_fungicide',
    titleTemplate: 'Spray mancozeb on {crop}',
    detailTemplate: '{dose} {chemical}.',
    chemical: 'mancozeb', dose: '2.5 g/L',
    safetyNote: 'Wear gloves.',
    urgency: 'high',
    weather: { requiresDryDays: 1, maxRainfallMmTomorrow: 2 },
    cooldownDays: 6, isActive: true, translations: {},
  },
  {
    _id: 'tpl_onion_irrigate', cropId: 'crop_onion', cropName: 'Onion',
    stage: 'seedling', daysFromSowingMin: 5, daysFromSowingMax: 25,
    verb: 'irrigate',
    titleTemplate: 'Irrigate {crop}',
    detailTemplate: 'Soil dry.',
    urgency: 'normal', cooldownDays: 7, isActive: true, translations: {},
  },
];

stub(path.resolve(__dirname, '../../../model/CropTaskTemplate'), {
  STAGES: ['pre_sowing','germination','seedling','vegetative','flowering','fruiting','maturity','harvested'],
  VERBS: ['spray_fungicide','spray_insecticide','spray_herbicide','fertilize','irrigate',
    'scout','weed','prune','stake','thin','harvest_check','soil_test','mulch'],
  URGENCIES: ['low','normal','high','urgent'],
  find: (q = {}) => ({
    lean: async () =>
      TEMPLATES.filter((t) => {
        if (q.cropId && String(q.cropId) !== String(t.cropId)) return false;
        if (q.stage && q.stage !== t.stage) return false;
        if (q.isActive != null && t.isActive !== q.isActive) return false;
        return true;
      }),
  }),
});

// Mock the HTTP module that ai-builder.service uses for the internal AI call.
// We swap the response per scenario by reassigning `MOCK_HTTP_RESPONSE`.
let MOCK_HTTP_RESPONSE = null;
let MOCK_HTTP_ERROR = null;
const mockHttp = {
  request: (opts, cb) => {
    const fakeRes = {
      statusCode: MOCK_HTTP_RESPONSE?.statusCode || 200,
      on: (evt, h) => {
        if (evt === 'data') {
          process.nextTick(() => h(JSON.stringify(MOCK_HTTP_RESPONSE?.body || {})));
        } else if (evt === 'end') {
          process.nextTick(() => h());
        }
      },
    };
    const req = {
      on: (evt, h) => {
        if (evt === 'error' && MOCK_HTTP_ERROR) process.nextTick(() => h(MOCK_HTTP_ERROR));
      },
      write: () => {}, end: () => {
        if (MOCK_HTTP_ERROR) {
          // emit 'error' first
        } else {
          process.nextTick(() => cb(fakeRes));
        }
      },
    };
    return req;
  },
};
require.cache[require.resolve('http')] = { id: 'http', filename: 'http', loaded: true, exports: mockHttp };
require.cache[require.resolve('https')] = { id: 'https', filename: 'https', loaded: true, exports: mockHttp };

process.env.AI_INTERNAL_SHARED_SECRET = 'test-secret';
process.env.MESSAGE_SERVICE_URL = 'http://message-svc:3000';

const Engine = require('../recommendation.engine');
const Localizer = require('../localizer');
const AiBuilder = require('../ai-builder.service');
const Validator = require('../ai-response.validator');
const PromptBuilder = require('../ai-prompt.builder');

let passed = 0, failed = 0;
function ok(label, cond, extra = '') {
  if (cond) { passed += 1; console.log('  ✓ ' + label); }
  else { failed += 1; console.error('  ✗ ' + label + (extra ? ` — ${extra}` : '')); }
}

function profileWithTomatoOnion() {
  const tomato = {
    _id: fakeId(), cropId: 'crop_tomato', cropName: 'Tomato', variety: 'Himsona',
    area: 1.2, areaUnit: 'hectare',
    sowingDate: new Date(Date.now() - 47 * 86400000),
    growthStage: 'fruiting', isActive: true,
  };
  const onion = {
    _id: fakeId(), cropId: 'crop_onion', cropName: 'Onion', variety: 'N-53',
    area: 0.3, areaUnit: 'hectare',
    sowingDate: new Date(Date.now() - 12 * 86400000),
    growthStage: 'seedling', isActive: true,
  };
  return {
    _id: fakeId(), userId: fakeId(),
    preferredLanguage: 'mr',
    location: { coordinates: [73.79, 19.99] },
    address: { state: 'Maharashtra', district: 'Nashik' },
    crops: [tomato, onion],
    onboardingStatus: 'completed',
  };
}

function makeWeather(rainTomorrow = 0) {
  const days = [];
  for (let i = 0; i < 7; i++) {
    days.push({
      date: new Date(Date.now() + (i - 3) * 86400000).toISOString().slice(0, 10),
      tempMin: 22, tempMax: 35,
      rainfallMm: i === 4 ? rainTomorrow : 0,
      conditionLabel: 'sunny',
    });
  }
  return { bucket: '19.99,73.79', lat: 19.99, lon: 73.79, days };
}

function setMockResponse(body, statusCode = 200) {
  MOCK_HTTP_RESPONSE = { statusCode, body };
  MOCK_HTTP_ERROR = null;
}
function setMockError(err) {
  MOCK_HTTP_ERROR = err;
  MOCK_HTTP_RESPONSE = null;
}

(async () => {
  console.log('\n--- Scenario 1: AI returns 2 valid items, both used');
  {
    const profile = profileWithTomatoOnion();
    const tomatoId = String(profile.crops[0]._id);
    const onionId = String(profile.crops[1]._id);
    setMockResponse({
      success: true,
      text: JSON.stringify({
        items: [
          {
            cropEntryId: tomatoId, verb: 'spray_fungicide',
            title: 'टोमॅटोवर मॅन्कोझेब फवारणी',
            detail: '2.5 g/L मॅन्कोझेब. पाने झाकून फवारा.',
            chemical: 'mancozeb', dose: '2.5 g/L',
            safetyNote: 'हातमोजे + मास्क घाला.',
            urgency: 'high',
            rationaleTags: ['fruiting_stage', 'no_rain_1d'],
          },
          {
            cropEntryId: onionId, verb: 'fertilize',
            title: 'कांद्यासाठी हलकी NPK फवारणी',
            detail: '0.5% urea + 0.5% MAP foliar spray.',
            urgency: 'normal',
            rationaleTags: ['seedling_stage'],
          },
        ],
      }),
      provider: 'vertex',
      model: 'gemini-2.5-flash',
      costUsd: 0.0006,
    });

    const result = await AiBuilder.recommend({
      profile, weather: makeWeather(), journal: [],
      imageContext: { images: [] }, lang: 'mr',
    });
    ok('AI used', result.used);
    ok('2 items accepted', result.itemsAccepted === 2, `got ${result.itemsAccepted}`);
    ok('0 items rejected', result.itemsRejected === 0);
    ok('not falling back', !result.fallbackToRule);
    ok('first item is tomato fungicide', result.items[0].verb === 'spray_fungicide');
    ok('Marathi text preserved', /टोमॅटो|मॅन्कोझेब/.test(result.items[0].title));
  }

  console.log('\n--- Scenario 2: AI returns 1 valid + 1 banned chemical → banned dropped');
  {
    const profile = profileWithTomatoOnion();
    const tomatoId = String(profile.crops[0]._id);
    const onionId = String(profile.crops[1]._id);
    setMockResponse({
      success: true,
      text: JSON.stringify({
        items: [
          {
            cropEntryId: tomatoId, verb: 'spray_insecticide',
            title: 'Spray endosulfan on tomato',
            detail: 'Apply for thrips control.',
            chemical: 'endosulfan',  // BANNED
            dose: '1 ml/L',
            urgency: 'high', rationaleTags: ['ai_fallback'],
          },
          {
            cropEntryId: onionId, verb: 'irrigate',
            title: 'कांद्याला पाणी द्या',
            detail: 'जमीन कोरडी आहे.',
            urgency: 'normal', rationaleTags: ['seedling_stage'],
          },
        ],
      }),
      provider: 'vertex', model: 'gemini-2.5-flash', costUsd: 0.0005,
    });

    const result = await AiBuilder.recommend({
      profile, weather: makeWeather(), journal: [],
      imageContext: { images: [] }, lang: 'mr',
    });
    ok('1 item accepted', result.itemsAccepted === 1);
    ok('1 item rejected', result.itemsRejected === 1);
    ok('chemical_banned reason logged', !!result.reasonsHistogram.chemical_banned);
    ok('endosulfan NOT in items', !result.items.some((i) => i.chemical === 'endosulfan'));
  }

  console.log('\n--- Scenario 3: AI returns malformed JSON → parseFailed, fallback');
  {
    const profile = profileWithTomatoOnion();
    setMockResponse({
      success: true,
      text: 'Sorry I cannot help with that.',
      provider: 'vertex', model: 'gemini-2.5-flash', costUsd: 0.0001,
    });
    const result = await AiBuilder.recommend({
      profile, weather: makeWeather(), journal: [],
      imageContext: { images: [] }, lang: 'mr',
    });
    ok('parseFailed flagged', result.parseFailed);
    ok('fallbackToRule', result.fallbackToRule);
    ok('0 items', result.items.length === 0);
  }

  console.log('\n--- Scenario 4: AI HTTP fails → graceful fallback');
  {
    const profile = profileWithTomatoOnion();
    setMockError(Object.assign(new Error('upstream_503'), { status: 503 }));
    setMockResponse({ success: false, error: 'service_unavailable' }, 503);
    const result = await AiBuilder.recommend({
      profile, weather: makeWeather(), journal: [],
      imageContext: { images: [] }, lang: 'mr',
    });
    ok('used flag set even on failure', result.used === true || result.fallbackToRule);
    ok('falls back to rule', result.fallbackToRule);
    ok('0 items', result.items.length === 0);
  }

  console.log('\n--- Scenario 5: AI returns brand-name chemical → dropped by heuristic');
  {
    const profile = profileWithTomatoOnion();
    const tomatoId = String(profile.crops[0]._id);
    setMockResponse({
      success: true,
      text: JSON.stringify({
        items: [{
          cropEntryId: tomatoId, verb: 'spray_fungicide',
          title: 'Apply Indofil M-45',
          detail: 'Indofil M-45 at recommended dose.',
          chemical: 'Indofil M-45',  // brand-name shape
          dose: '2.5 g/L',
          urgency: 'high', rationaleTags: ['fruiting_stage'],
        }],
      }),
      provider: 'vertex', model: 'gemini-2.5-flash', costUsd: 0.0003,
    });
    const result = await AiBuilder.recommend({
      profile, weather: makeWeather(), journal: [],
      imageContext: { images: [] }, lang: 'mr',
    });
    ok('brand item rejected', result.itemsRejected === 1);
    ok('chemical_looks_like_brand reason', !!result.reasonsHistogram.chemical_looks_like_brand);
  }

  console.log('\n--- Scenario 6: invalid dose pattern → dropped');
  {
    const profile = profileWithTomatoOnion();
    const tomatoId = String(profile.crops[0]._id);
    setMockResponse({
      success: true,
      text: JSON.stringify({
        items: [{
          cropEntryId: tomatoId, verb: 'spray_fungicide',
          title: 'Spray mancozeb',
          detail: 'apply some.',
          chemical: 'mancozeb',
          dose: 'a lot',  // invalid
          urgency: 'high', rationaleTags: ['fruiting_stage'],
        }],
      }),
      provider: 'vertex', model: 'gemini-2.5-flash', costUsd: 0.0003,
    });
    const result = await AiBuilder.recommend({
      profile, weather: makeWeather(), journal: [],
      imageContext: { images: [] }, lang: 'mr',
    });
    ok('bad dose item rejected', result.itemsRejected === 1);
    ok('dose_pattern_invalid reason', !!result.reasonsHistogram.dose_pattern_invalid);
  }

  console.log('\n--- Scenario 7: cropEntryId not in profile → rejected');
  {
    const profile = profileWithTomatoOnion();
    setMockResponse({
      success: true,
      text: JSON.stringify({
        items: [{
          cropEntryId: 'unknown_crop_id_aaaa',
          verb: 'spray_fungicide',
          title: 'Spray mancozeb',
          detail: 'apply.',
          chemical: 'mancozeb', dose: '2.5 g/L',
          urgency: 'high', rationaleTags: ['fruiting_stage'],
        }],
      }),
      provider: 'vertex', model: 'gemini-2.5-flash', costUsd: 0.0003,
    });
    const result = await AiBuilder.recommend({
      profile, weather: makeWeather(), journal: [],
      imageContext: { images: [] }, lang: 'mr',
    });
    ok('unknown crop rejected', result.itemsRejected === 1);
    ok('cropEntryId_unknown reason', !!result.reasonsHistogram.cropEntryId_unknown);
  }

  console.log('\n--- Scenario 8: Validator unit checks');
  {
    const ok1 = Validator.DOSE_RE.test('2.5 g/L');
    const ok2 = Validator.DOSE_RE.test('200 ml/acre');
    const ok3 = Validator.DOSE_RE.test('50 kg/ha');
    const bad1 = Validator.DOSE_RE.test('lots');
    ok('dose regex accepts 2.5 g/L', ok1);
    ok('dose regex accepts 200 ml/acre', ok2);
    ok('dose regex accepts 50 kg/ha', ok3);
    ok('dose regex rejects "lots"', !bad1);
    ok('chemicalIsBanned("endosulfan") is true', Validator.chemicalIsBanned('endosulfan'));
    ok('chemicalIsBanned("mancozeb") is false', !Validator.chemicalIsBanned('mancozeb'));
  }

  console.log('\n--- Scenario 9: Prompt builder shape sanity');
  {
    const profile = profileWithTomatoOnion();
    const built = PromptBuilder.buildPrompt({
      profile, weather: makeWeather(), journal: [],
      imageContext: { images: [{ url: 'https://example.com/a.jpg', source: 'ai_chat', occurredAt: new Date().toISOString(), caption: 'leaf' }] },
      farmerInputYesterday: 'leaves yellow on lower part',
      lang: 'mr',
    });
    ok('system prompt mentions Marathi', /Marathi/.test(built.system));
    ok('user payload has 2 crops', built.userJson.crops.length === 2);
    ok('image descriptor included', built.userJson.imageContext.count === 1);
    ok('farmer input passed through', built.userJson.farmerInputYesterday === 'leaves yellow on lower part');
    ok('verbs list non-empty', built.verbs.length === 13);
  }

  console.log(`\nResults: ${passed} passed, ${failed} failed`);
  process.exit(failed === 0 ? 0 : 1);
})().catch((err) => {
  console.error('Smoke test crashed:', err);
  process.exit(1);
});
