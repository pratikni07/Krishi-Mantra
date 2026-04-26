const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const redis = require('../config/redis');
const logger = require('../utils/logger');
const WeatherService = require('./weather.service');
const FarmProfileClient = require('./farm-profile.client');

const PROMPT_DIR = path.resolve(__dirname, '..', 'prompts');

const TREE_VERSION = 'v1';

const LANG_NAMES = {
  en: 'English',
  hi: 'Hindi',
  mr: 'Marathi',
  bn: 'Bengali',
  gu: 'Gujarati',
  kn: 'Kannada',
  ml: 'Malayalam',
  or: 'Odia',
  pa: 'Punjabi',
  ta: 'Tamil',
  te: 'Telugu',
  ur: 'Urdu',
  as: 'Assamese',
};

function sha1(s) {
  return crypto.createHash('sha1').update(s).digest('hex');
}

function approxTokens(text) {
  if (!text) return 0;
  return Math.ceil(String(text).length / 4);
}

const PROMPT_FILE_CACHE = new Map();

function readPromptFile(lang) {
  if (PROMPT_FILE_CACHE.has(lang)) return PROMPT_FILE_CACHE.get(lang);
  try {
    const file = path.join(PROMPT_DIR, `core.${lang}.md`);
    if (fs.existsSync(file)) {
      const text = fs.readFileSync(file, 'utf8').trim();
      PROMPT_FILE_CACHE.set(lang, text);
      return text;
    }
  } catch (err) {
    // fall through
  }
  PROMPT_FILE_CACHE.set(lang, null);
  return null;
}

// L0 — core/persona/rules, per language, byte-identical across all users.
// Sourced from src/prompts/core.{lang}.md if present, else inlined fallback
// (English-language template with the language name substituted in).
function coreText(lang) {
  const fromFile = readPromptFile(lang);
  if (fromFile) return fromFile;
  const langName = LANG_NAMES[lang] || LANG_NAMES.en;
  return (
    `You are Krishi-Mantra AI, an agronomy assistant for Indian farmers. Follow these rules:\n` +
    `1. Use plain, practical language. No jargon without explanation.\n` +
    `2. Ground every recommendation in the farmer's profile, crops, and weather below.\n` +
    `3. Cite typical local units (acre, bigha, kg, litre) and INR for prices.\n` +
    `4. When suggesting chemicals, include safe application rate AND safety note.\n` +
    `5. If critical data is missing, ask ONE clarifying question first.\n` +
    `6. Keep responses under 250 words unless the user asks for detail.\n` +
    `7. Respond in: ${langName}.\n` +
    `Sections you may use: Diagnosis, Why, Action, Caution, Follow-up.`
  );
}

async function buildCore(lang) {
  const normalizedLang = lang && LANG_NAMES[lang] ? lang : 'en';
  const cacheKey = `ctx-layer:${TREE_VERSION}:core:${normalizedLang}`;
  try {
    const cached = await redis.get(cacheKey);
    if (cached) {
      return { name: 'core', text: cached, fp: sha1(cached), tokens: approxTokens(cached) };
    }
  } catch (err) {
    // fall through to rebuild
  }
  const text = coreText(normalizedLang);
  try {
    await redis.setex(cacheKey, 24 * 60 * 60, text);
  } catch (err) {
    // best-effort
  }
  return { name: 'core', text, fp: sha1(text), tokens: approxTokens(text) };
}

function profileText(profile) {
  if (!profile) return null;
  const addr = profile.address || {};
  const locationBits = [addr.village, addr.taluka, addr.district, addr.state]
    .filter(Boolean)
    .join(', ');
  const coords = profile.location?.coordinates || [];
  const lat = typeof coords[1] === 'number' ? coords[1].toFixed(2) : null;
  const lon = typeof coords[0] === 'number' ? coords[0].toFixed(2) : null;

  const lines = ['FARMER'];
  const bio = [];
  if (profile.age) bio.push(`Age: ${profile.age}`);
  if (profile.gender && profile.gender !== 'prefer_not_to_say') bio.push(`Gender: ${profile.gender}`);
  if (bio.length) lines.push(`- ${bio.join(', ')}`);

  if (locationBits || (lat && lon)) {
    const parts = [];
    if (locationBits) parts.push(locationBits);
    if (lat && lon) parts.push(`(${lat}N, ${lon}E)`);
    lines.push(`- Location: ${parts.join(' ')}`);
  }

  const farmBits = [];
  if (profile.totalArea) farmBits.push(`${profile.totalArea} ${profile.totalAreaUnit || 'acre'}`);
  if (profile.ownership) farmBits.push(profile.ownership);
  if (profile.soilTypes?.length) farmBits.push(`soils: ${profile.soilTypes.join('/')}`);
  if (profile.irrigationSources?.length)
    farmBits.push(`irrigation: ${profile.irrigationSources.join('+')}`);
  if (farmBits.length) lines.push(`- Farm: ${farmBits.join(', ')}`);

  if (profile.experienceYears) lines.push(`- Experience: ${profile.experienceYears} years`);

  return lines.join('\n');
}

function buildProfile(profile) {
  const text = profileText(profile);
  if (!text) return null;
  const fp = sha1(text);
  return { name: 'profile', text, fp, tokens: approxTokens(text) };
}

function daysSince(dateLike) {
  if (!dateLike) return null;
  const then = new Date(dateLike).getTime();
  if (Number.isNaN(then)) return null;
  return Math.max(0, Math.floor((Date.now() - then) / (24 * 60 * 60 * 1000)));
}

function cropLine(c) {
  const header = `- ${String(c.cropName || '').toUpperCase()}${c.variety ? ` (${c.variety})` : ''}`;
  const dsow = daysSince(c.sowingDate);
  const extras = [];
  if (c.area) extras.push(`${c.area} ${c.areaUnit || 'acre'}`);
  if (c.irrigationMethod) extras.push(c.irrigationMethod);
  if (c.plantingMethod && c.sowingDate) {
    const verb =
      c.plantingMethod === 'transplanting'
        ? 'transplanted'
        : c.plantingMethod === 'broadcasting'
        ? 'broadcast'
        : 'sown';
    extras.push(`${verb} ${new Date(c.sowingDate).toISOString().slice(0, 10)}`);
  }
  if (typeof dsow === 'number') extras.push(`${dsow} days ago`);
  if (c.growthStage) extras.push(`${c.growthStage} stage`);
  return `${header}: ${extras.join(', ')}`;
}

function pickCrops(crops, cropsOfInterest, { max = 3 } = {}) {
  const active = (crops || []).filter((c) => c.isActive !== false);
  if (!cropsOfInterest || cropsOfInterest.length === 0) return active.slice(0, max);
  const interested = new Set(cropsOfInterest.map((s) => String(s).toLowerCase()));
  const preferred = active.filter(
    (c) =>
      interested.has(String(c.cropName || '').toLowerCase()) ||
      interested.has(String(c.cropId || ''))
  );
  const rest = active.filter((c) => !preferred.includes(c));
  return [...preferred, ...rest].slice(0, max);
}

function buildCrops(crops) {
  if (!crops || !crops.length) return null;
  const text = ['CROPS', ...crops.map(cropLine)].join('\n');
  return { name: 'crops', text, fp: sha1(text), tokens: approxTokens(text) };
}

function buildWeather(wx, address) {
  if (!wx || !wx.days?.length) return null;
  const todayISO = new Date().toISOString().slice(0, 10);
  const where = address?.village || address?.district || address?.state || 'location';
  const header = `WEATHER (${where}, ±3 days around ${todayISO})`;
  const lines = wx.days.map((d) => {
    const dateStr = new Date(d.date).toISOString().slice(0, 10);
    const marker = dateStr === todayISO ? '  (today)' : '';
    const rain = typeof d.rainfallMm === 'number' ? `${d.rainfallMm} mm` : '— mm';
    const label = d.conditionLabel || 'unknown';
    return `- ${dateStr.slice(5)}: ${Math.round(d.tempMin)}–${Math.round(d.tempMax)}°C, ${rain}, ${label}${marker}`;
  });
  const text = [header, ...lines].join('\n');
  return { name: 'weather', text, fp: sha1(text), tokens: approxTokens(text) };
}

function buildSummary(summary) {
  if (!summary?.text) return null;
  const text = `SUMMARY\n${summary.text}`;
  return { name: 'summary', text, fp: sha1(text), tokens: approxTokens(text) };
}

function buildMinimalProfile(profile) {
  const lang = profile?.preferredLanguage || 'en';
  const text =
    'FARMER\n- Profile not yet completed. Give generic advice; suggest completing onboarding for personalized help.';
  return { name: 'profile', text, fp: sha1(text + lang), tokens: approxTokens(text) };
}

async function assemble({
  chat,
  profile,
  userId,
  message,
  routing = {},
  preferredLanguage,
}) {
  let resolvedProfile = profile;
  if (!resolvedProfile && userId) {
    try {
      resolvedProfile = await FarmProfileClient.get(userId);
    } catch (err) {
      logger.warn('farm-profile fetch failed in context tree', { error: err.message });
    }
  }
  const profileForRender = resolvedProfile;
  const lang =
    preferredLanguage ||
    profileForRender?.preferredLanguage ||
    chat?.metadata?.preferredLanguage ||
    'en';

  const layers = [];

  layers.push(await buildCore(lang));

  if (profileForRender?.onboardingStatus === 'completed') {
    const profileLayer = buildProfile(profileForRender);
    if (profileLayer) layers.push(profileLayer);

    if (routing.needsCropBlock !== false) {
      const chosen = pickCrops(profileForRender.crops, routing.cropsOfInterest, { max: 3 });
      const cropLayer = buildCrops(chosen);
      if (cropLayer) layers.push(cropLayer);
    }

    if (routing.needsWeather !== false && profileForRender.location?.coordinates?.length === 2) {
      try {
        const [lon, lat] = profileForRender.location.coordinates;
        const wx = await WeatherService.get7Day(lat, lon);
        if (wx) {
          const weatherLayer = buildWeather(wx, profileForRender.address);
          if (weatherLayer) layers.push(weatherLayer);
        }
      } catch (err) {
        logger.warn('weather layer build failed', { error: err.message });
      }
    }
  } else {
    layers.push(buildMinimalProfile(profileForRender));
  }

  if (chat?.summary?.text) {
    const summaryLayer = buildSummary(chat.summary);
    if (summaryLayer) layers.push(summaryLayer);
  }

  const systemPrompt = layers.map((l) => l.text).join('\n\n');

  const summarizedUpTo = chat?.summary?.summarizedUpTo || 0;
  const history = Array.isArray(chat?.messages) ? chat.messages : [];
  const window = history
    .slice(summarizedUpTo)
    .slice(-6)
    .map((m) => ({ role: m.role, content: m.content }));

  const messages = [{ role: 'system', content: systemPrompt }, ...window];
  if (message) messages.push({ role: 'user', content: message });

  const fingerprints = Object.fromEntries(layers.map((l) => [l.name, l.fp]));
  const tokenEstByLayer = Object.fromEntries(layers.map((l) => [l.name, l.tokens]));
  const totalSystemTokens = layers.reduce((s, l) => s + l.tokens, 0);
  const prefixFingerprint = sha1(
    [TREE_VERSION, ...layers.map((l) => `${l.name}:${l.fp}`)].join('|')
  );

  return {
    messages,
    systemPrompt,
    layers,
    fingerprints,
    tokenEstByLayer,
    totalSystemTokens,
    prefixFingerprint,
    treeVersion: TREE_VERSION,
    model: routing.lowCostOk === false ? 'gpt-4.1' : 'gpt-4.1-mini',
    maxOutputTokens: routing.intent === 'plant-health' ? 900 : 700,
  };
}

module.exports = {
  assemble,
  TREE_VERSION,
  _internal: { buildCore, buildProfile, buildCrops, buildWeather, buildSummary, pickCrops },
};
