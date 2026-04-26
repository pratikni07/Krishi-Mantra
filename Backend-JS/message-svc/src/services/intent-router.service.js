const crypto = require('crypto');
const redis = require('../config/redis');
const logger = require('../utils/logger');

const INTENTS = [
  'weather',
  'plant-health',
  'nutrition',
  'irrigation',
  'market',
  'crop-general',
  'general',
];

// Regex patterns are conservative. ASCII + common Indian-English spellings only;
// Indic-script matches are handled by crop-name contains-check below.
const PATTERNS = [
  {
    intent: 'weather',
    re: /\b(weather|forecast|rain|rainfall|temperature|humidity|barish|varsha|paus|monsoon|thunder|storm|hail)\b/i,
    needsWeather: true,
    needsCropBlock: false,
  },
  {
    intent: 'plant-health',
    re: /\b(disease|diseases|wilt|wilting|blight|rot|rust|mildew|spot|spots|yellow|yellowing|leaf curl|pest|pests|insect|bug|bugs|fungus|fungal|mosaic|virus|aphid|whitefly|mealybug|caterpillar|larva|borer)\b/i,
    needsWeather: true,
    needsCropBlock: true,
  },
  {
    intent: 'nutrition',
    re: /\b(fertili[sz]er|fertili[sz]e|nutrient|nutrients|urea|dap|mop|npk|nitrogen|phosphorus|potash|potassium|micronutrient|zinc|boron|manure|compost|vermicompost|biofertili[sz]er)\b/i,
    needsWeather: false,
    needsCropBlock: true,
  },
  {
    intent: 'irrigation',
    re: /\b(irrigat|water(ing)?|drip|sprinkler|moisture|drought|flood|furrow|pani|paani)\b/i,
    needsWeather: true,
    needsCropBlock: true,
  },
  {
    intent: 'market',
    re: /\b(market|mandi|price|rate|sell|selling|sale|buyer|msp|apmc|procurement)\b/i,
    needsWeather: false,
    needsCropBlock: true,
  },
];

function hashMessage(s) {
  return crypto.createHash('sha1').update(String(s).toLowerCase()).digest('hex');
}

function detectCrops(message, profileCrops = []) {
  if (!message) return [];
  const lower = String(message).toLowerCase();
  const matches = [];
  for (const c of profileCrops) {
    const names = [c.cropName, c.variety].filter(Boolean).map((s) => String(s).toLowerCase());
    if (names.some((n) => n && lower.includes(n))) {
      matches.push(c.cropName);
    }
  }
  // Also pick up common crop names even if not in profile — useful for users
  // whose onboarding is incomplete.
  const COMMON = ['tomato', 'onion', 'potato', 'wheat', 'rice', 'paddy', 'cotton', 'sugarcane',
    'soybean', 'maize', 'corn', 'chilli', 'chili', 'pepper', 'groundnut', 'peanut', 'mustard',
    'jowar', 'bajra', 'pulses', 'moong', 'tur', 'chickpea', 'gram', 'brinjal', 'eggplant',
    'cabbage', 'cauliflower', 'okra', 'bhindi', 'banana', 'mango', 'grape', 'pomegranate'];
  const lowered = new Set(matches.map((n) => String(n).toLowerCase()));
  for (const name of COMMON) {
    if (lower.includes(name) && !lowered.has(name)) {
      matches.push(name);
      lowered.add(name);
    }
  }
  return matches;
}

function classifyLocal(message) {
  const msg = String(message || '');
  for (const p of PATTERNS) {
    if (p.re.test(msg)) {
      return {
        intent: p.intent,
        needsWeather: p.needsWeather,
        needsCropBlock: p.needsCropBlock,
      };
    }
  }
  return null;
}

async function classify(message, { profileCrops = [], provider = null, useCache = true } = {}) {
  if (!message || !message.trim()) {
    return {
      intent: 'general',
      cropsOfInterest: [],
      needsWeather: false,
      needsCropBlock: false,
      lowCostOk: true,
    };
  }

  const crops = detectCrops(message, profileCrops);
  const local = classifyLocal(message);

  // Crop-only message ("about tomato?") → crop-general.
  if (!local && crops.length) {
    return {
      intent: 'crop-general',
      cropsOfInterest: crops,
      needsWeather: true,
      needsCropBlock: true,
      lowCostOk: true,
    };
  }

  if (local) {
    return {
      intent: local.intent,
      cropsOfInterest: crops,
      needsWeather: local.needsWeather,
      needsCropBlock: local.needsCropBlock,
      lowCostOk: true,
    };
  }

  // Regex returned nothing + profile has >3 crops → LLM fallback, cached.
  if (provider && profileCrops.length > 3) {
    const cacheKey = `intent-router:${hashMessage(message)}`;
    if (useCache) {
      try {
        const cached = await redis.get(cacheKey);
        if (cached) return JSON.parse(cached);
      } catch (err) {
        // fall through
      }
    }
    try {
      const { text } = await provider.chat({
        messages: [
          {
            role: 'system',
            content:
              'Classify the user message. Return ONE label only from: weather, plant-health, nutrition, irrigation, market, crop-general, general. No punctuation.',
          },
          { role: 'user', content: message },
        ],
        maxTokens: 8,
        temperature: 0,
      });
      const label = String(text || '').trim().toLowerCase().replace(/[^a-z-]/g, '');
      const intent = INTENTS.includes(label) ? label : 'general';
      const result = {
        intent,
        cropsOfInterest: crops,
        needsWeather: ['weather', 'plant-health', 'irrigation', 'crop-general'].includes(intent),
        needsCropBlock: intent !== 'weather' && intent !== 'general',
        lowCostOk: true,
      };
      try {
        await redis.setex(cacheKey, 24 * 60 * 60, JSON.stringify(result));
      } catch (err) {
        // best-effort
      }
      return result;
    } catch (err) {
      logger.warn('intent-router LLM fallback failed', { error: err.message });
    }
  }

  return {
    intent: 'general',
    cropsOfInterest: crops,
    needsWeather: false,
    needsCropBlock: crops.length > 0,
    lowCostOk: true,
  };
}

module.exports = { classify, INTENTS, _internal: { classifyLocal, detectCrops } };
