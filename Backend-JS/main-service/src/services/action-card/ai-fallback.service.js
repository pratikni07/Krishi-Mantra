const crypto = require('crypto');
const http = require('http');
const https = require('https');

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

const { LANG_NAMES } = require('./verb-glossary');

const PURPOSE = 'action_card_fallback';
const PER_USER_DAILY_CAP = parseInt(
  process.env.ACTION_CARD_AI_FALLBACK_DAILY_PER_USER || '2',
  10
);
const QUOTA_KEY = (uid, day) => `ai-fallback:${uid}:${day}`;
const VERBS_HINT = [
  'spray_fungicide', 'spray_insecticide', 'spray_herbicide',
  'fertilize', 'irrigate', 'scout', 'weed', 'prune',
  'stake', 'thin', 'harvest_check', 'soil_test', 'mulch',
];
const URGENCIES = ['low', 'normal', 'high', 'urgent'];

function todayKey() {
  return new Date().toISOString().slice(0, 10);
}

async function quotaExceeded(userId) {
  if (!redis) return false;
  try {
    const cur = parseInt(await redis.get(QUOTA_KEY(userId, todayKey())) || '0', 10);
    return cur >= PER_USER_DAILY_CAP;
  } catch (err) {
    return false;
  }
}

async function consumeQuota(userId) {
  if (!redis) return;
  try {
    const cur = await redis.incr(QUOTA_KEY(userId, todayKey()));
    if (cur === 1) await redis.expire(QUOTA_KEY(userId, todayKey()), 48 * 3600);
  } catch (err) {
    // best-effort
  }
}

function buildSystemPrompt(lang) {
  const langName = LANG_NAMES[lang] || LANG_NAMES.en;
  return (
    'You are an agronomist for Indian farmers. Output ONE recommended action ' +
    'for this farmer today as STRICT JSON ONLY (no surrounding text, no fences). ' +
    'Schema: { "verb": one of [' +
    VERBS_HINT.join(', ') +
    '], "title": short string (≤ 80 chars), "detail": ≤ 60 words, ' +
    '"chemical"?: generic active only, "dose"?: e.g. "2.5 g/L", "safetyNote"?: ≤ 25 words, ' +
    '"urgency": one of [' + URGENCIES.join(', ') + '], ' +
    '"rationaleTags": short snake_case strings such as ["fruiting_stage","no_rain_48h"] }.\n' +
    'No brand names. No banned chemicals (endosulfan, monocrotophos, phorate, methyl-parathion). ' +
    `Reply MUST be in: ${langName}.`
  );
}

function snapshotToCompactString(weather) {
  if (!weather?.days?.length) return 'unknown';
  const d = weather.days;
  const today = d[3] || d[0];
  const tomorrow = d[4];
  const parts = [];
  if (today?.tempMin != null && today?.tempMax != null) {
    parts.push(`today ${Math.round(today.tempMin)}-${Math.round(today.tempMax)}°C`);
  }
  const rain48 = d.slice(4, 6).reduce((s, x) => s + (x?.rainfallMm || 0), 0);
  parts.push(`rain48h ${rain48.toFixed(1)}mm`);
  if (tomorrow?.conditionLabel) parts.push(`tomorrow ${tomorrow.conditionLabel}`);
  return parts.join(', ');
}

function compactRecentJournal(rows = []) {
  return rows
    .slice(0, 8)
    .map((r) => `${r.verb}@${r.localDate || ''}`);
}

function postJSONWithHmac(urlString, payload, secret) {
  return new Promise((resolve, reject) => {
    const u = new URL(urlString);
    const lib = u.protocol === 'https:' ? https : http;
    const body = JSON.stringify(payload);
    const ts = Math.floor(Date.now() / 1000).toString();
    const sig = crypto.createHmac('sha256', secret).update(`${ts}.${body}`).digest('hex');

    const req = lib.request(
      {
        hostname: u.hostname,
        port: u.port || (u.protocol === 'https:' ? 443 : 80),
        path: u.pathname + (u.search || ''),
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(body),
          'X-Internal-Auth': sig,
          'X-Internal-Timestamp': ts,
          'X-Internal-Caller': 'main-service.action-card.ai-fallback',
        },
        timeout: 12_000,
      },
      (res) => {
        let chunks = '';
        res.on('data', (c) => (chunks += c));
        res.on('end', () => {
          if (res.statusCode >= 200 && res.statusCode < 300) {
            try {
              resolve(JSON.parse(chunks));
            } catch (err) {
              reject(new Error(`bad_json: ${err.message}`));
            }
          } else {
            reject(
              Object.assign(new Error(`status_${res.statusCode}`), {
                status: res.statusCode,
                body: chunks,
              })
            );
          }
        });
      }
    );
    req.on('error', reject);
    req.on('timeout', () => req.destroy(new Error('timeout')));
    req.write(body);
    req.end();
  });
}

function safeParseStrictJson(text) {
  if (!text) return null;
  // strip code fences if the model added any despite instructions
  const cleaned = text
    .trim()
    .replace(/^```(?:json)?\s*/i, '')
    .replace(/```$/i, '')
    .trim();
  try {
    const obj = JSON.parse(cleaned);
    if (!obj || typeof obj !== 'object') return null;
    return obj;
  } catch (err) {
    return null;
  }
}

function validateAiItem(obj) {
  if (!obj) return null;
  if (!VERBS_HINT.includes(obj.verb)) return null;
  if (!obj.title || typeof obj.title !== 'string') return null;
  const urgency = URGENCIES.includes(obj.urgency) ? obj.urgency : 'normal';
  return {
    verb: obj.verb,
    title: String(obj.title).slice(0, 200),
    detail: obj.detail ? String(obj.detail).slice(0, 600) : '',
    chemical: obj.chemical ? String(obj.chemical).slice(0, 80) : undefined,
    dose: obj.dose ? String(obj.dose).slice(0, 80) : undefined,
    safetyNote: obj.safetyNote ? String(obj.safetyNote).slice(0, 200) : undefined,
    urgency,
    rationaleTags: Array.isArray(obj.rationaleTags)
      ? obj.rationaleTags.map(String).slice(0, 8)
      : ['ai_fallback'],
  };
}

/**
 * Returns either a validated action item (already localized; ai source) or null.
 * Quota-capped per user per day; safe to call repeatedly.
 */
async function suggestAction({ profile, crop, weather, recentJournal, lang }) {
  if (!profile || !crop) return null;
  const userId = String(profile.userId || profile._id);

  if (await quotaExceeded(userId)) {
    logger.info('action-card.ai_fallback.quota_exhausted', { userId });
    return null;
  }

  const url =
    process.env.MESSAGE_SERVICE_URL ||
    process.env.AI_INTERNAL_BASE_URL ||
    'http://message-svc:3000';
  const secret =
    process.env.AI_INTERNAL_SHARED_SECRET ||
    process.env.ACTION_CARD_INTERNAL_SHARED_SECRET;
  if (!secret) {
    logger.warn('action-card.ai_fallback.no_secret_configured');
    return null;
  }

  const targetLang = lang && LANG_NAMES[lang] ? lang : 'en';
  const messages = [
    { role: 'system', content: buildSystemPrompt(targetLang) },
    {
      role: 'user',
      content: JSON.stringify({
        crop: {
          name: crop.cropName,
          variety: crop.variety || null,
          daysSinceSowing: crop.daysSinceSowing,
          stage: crop.stage,
          area: crop.area,
          areaUnit: crop.areaUnit,
          irrigationMethod: crop.irrigationMethod,
        },
        farm: {
          totalArea: profile.totalArea,
          totalAreaUnit: profile.totalAreaUnit,
          soils: profile.soilTypes,
          irrigation: profile.irrigationSources,
          state: profile.address?.state,
          district: profile.address?.district,
        },
        weather: snapshotToCompactString(weather),
        recentActivity: compactRecentJournal(recentJournal),
      }),
    },
  ];

  let response;
  try {
    response = await postJSONWithHmac(`${url}/api/ai/internal/chat`, {
      messages,
      maxTokens: 220,
      temperature: 0.2,
      userId,
      purpose: PURPOSE,
      language: targetLang,
    }, secret);
  } catch (err) {
    logger.warn('action-card.ai_fallback.request_failed', {
      userId,
      error: err.message,
      status: err.status,
    });
    return null;
  }

  await consumeQuota(userId);

  const parsed = safeParseStrictJson(response?.text);
  const valid = validateAiItem(parsed);
  if (!valid) {
    logger.warn('action-card.ai_fallback.invalid_payload', { userId });
    return null;
  }

  return {
    source: 'ai',
    cropEntryId: crop._id,
    cropName: crop.cropName,
    cropVariety: crop.variety,
    verb: valid.verb,
    title: valid.title,
    detail: valid.detail,
    chemical: valid.chemical,
    dose: valid.dose,
    safetyNote: valid.safetyNote,
    urgency: valid.urgency,
    rationaleTags: valid.rationaleTags,
    aiCostUsd: response?.costUsd || 0,
  };
}

module.exports = {
  suggestAction,
  // Exported for tests / debug:
  _internal: {
    safeParseStrictJson,
    validateAiItem,
    snapshotToCompactString,
    buildSystemPrompt,
  },
};
