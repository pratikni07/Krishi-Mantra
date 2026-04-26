const crypto = require('crypto');
const http = require('http');
const https = require('https');

const PromptBuilder = require('./ai-prompt.builder');
const Validator = require('./ai-response.validator');

let logger;
try {
  logger = require('../../utils/logger');
} catch (err) {
  logger = { info: () => {}, warn: () => {}, error: () => {}, debug: () => {} };
}

const PURPOSE = 'action_card_ai_first';
const REQ_TIMEOUT_MS = parseInt(process.env.ACTION_CARD_AI_TIMEOUT_MS || '15000', 10);

function postJSONWithHmac(urlString, payload, secret, { timeoutMs = REQ_TIMEOUT_MS } = {}) {
  return new Promise((resolve, reject) => {
    const u = new URL(urlString);
    const lib = u.protocol === 'https:' ? https : http;
    const body = JSON.stringify(payload);
    const ts = Math.floor(Date.now() / 1000).toString();
    const sig = crypto
      .createHmac('sha256', secret)
      .update(`${ts}.${body}`)
      .digest('hex');

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
          'X-Internal-Caller': 'main-service.action-card.ai-builder',
        },
        timeout: timeoutMs,
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

function internalUrl(suffix) {
  const base =
    process.env.MESSAGE_SERVICE_URL ||
    process.env.AI_INTERNAL_BASE_URL ||
    'http://message-svc:3000';
  return `${base.replace(/\/+$/, '')}${suffix}`;
}

function readSecret() {
  return (
    process.env.AI_INTERNAL_SHARED_SECRET ||
    process.env.ACTION_CARD_INTERNAL_SHARED_SECRET ||
    null
  );
}

/**
 * Top-level entry. Returns:
 *   {
 *     items: [validated AI items, already crop-resolved],
 *     used: bool,
 *     provider, model, costUsd, latencyMs,
 *     imageCount,
 *     itemsAccepted, itemsRejected, parseFailed,
 *     reasonsHistogram,
 *     fallbackToRule: bool,        // true if we couldn't get any valid AI items
 *     error?: string,
 *   }
 *
 * Never throws. The card builder treats every failure as "fall back to rule".
 */
async function recommend({
  profile,
  weather,
  journal,
  imageContext,
  farmerInputYesterday,
  lang,
}) {
  const secret = readSecret();
  if (!secret) {
    return notUsed('no_internal_secret');
  }

  const { system, userJson, targetLang } = PromptBuilder.buildPrompt({
    profile,
    weather,
    journal,
    imageContext,
    farmerInputYesterday,
    lang,
  });

  const userText = JSON.stringify(userJson);
  const messages = [
    { role: 'system', content: system },
    { role: 'user', content: userText },
  ];

  const imageUrls = (imageContext?.images || []).map((it) => it.url);
  const hasImages = imageUrls.length > 0;
  const url = internalUrl(hasImages ? '/api/ai/internal/vision' : '/api/ai/internal/chat');

  const startedAt = Date.now();
  let response;
  try {
    response = await postJSONWithHmac(
      url,
      hasImages
        ? {
            messages,
            imageUrls,
            maxTokens: 700,
            temperature: 0.2,
            userId: String(profile.userId || profile._id),
            purpose: PURPOSE,
            language: targetLang,
          }
        : {
            messages,
            maxTokens: 700,
            temperature: 0.2,
            userId: String(profile.userId || profile._id),
            purpose: PURPOSE,
            language: targetLang,
          },
      secret
    );
  } catch (err) {
    logger.warn('action-card.ai_first.request_failed', {
      userId: String(profile.userId || profile._id),
      hasImages,
      error: err.message,
      status: err.status,
    });
    return notUsed(`request_failed:${err.message}`);
  }

  const latencyMs = Date.now() - startedAt;

  const parsed = Validator.parseAndValidate(response?.text, profile);

  if (parsed.parseFailed) {
    logger.warn('action-card.ai_first.parse_failed', {
      userId: String(profile.userId || profile._id),
      latencyMs,
      provider: response?.provider,
    });
    return {
      items: [],
      used: true,
      provider: response?.provider,
      model: response?.model,
      costUsd: response?.costUsd || 0,
      latencyMs,
      imageCount: imageUrls.length,
      itemsAccepted: 0,
      itemsRejected: 0,
      parseFailed: true,
      reasonsHistogram: { parse_failed: 1 },
      fallbackToRule: true,
    };
  }

  const enriched = parsed.valid.map((it) => ({
    source: 'ai',
    cropEntryId: it.cropEntryId,
    cropName: it.cropName,
    cropVariety: it.cropVariety,
    verb: it.verb,
    title: it.title,
    detail: it.detail,
    chemical: it.chemical,
    dose: it.dose,
    safetyNote: it.safetyNote,
    urgency: it.urgency,
    rationaleTags: it.rationaleTags,
  }));

  return {
    items: enriched,
    used: true,
    provider: response?.provider,
    model: response?.model,
    costUsd: response?.costUsd || 0,
    latencyMs,
    imageCount: imageUrls.length,
    itemsAccepted: enriched.length,
    itemsRejected: parsed.rejected.length,
    parseFailed: false,
    reasonsHistogram: parsed.reasonsHistogram,
    fallbackToRule: enriched.length === 0,
  };
}

function notUsed(error) {
  return {
    items: [],
    used: false,
    provider: null,
    model: null,
    costUsd: 0,
    latencyMs: 0,
    imageCount: 0,
    itemsAccepted: 0,
    itemsRejected: 0,
    parseFailed: false,
    reasonsHistogram: {},
    fallbackToRule: true,
    error,
  };
}

module.exports = { recommend };
