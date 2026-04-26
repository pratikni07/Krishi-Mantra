const AIShadowLog = require('../models/ai-shadow-log.model');
const AiProviderConfig = require('../models/ai-provider-config.model');
const aiConfigService = require('./ai-config.service');
const openaiProvider = require('../ai-providers/openai.provider');
let vertexProvider = null;
try {
  vertexProvider = require('../ai-providers/vertex.provider');
} catch (err) {
  vertexProvider = null;
}
const secretBox = require('../utils/secret-box');
const { costFor } = require('../utils/cost-table');
const logger = require('../utils/logger');

const SHADOW_TTL_MS = 7 * 24 * 60 * 60 * 1000;

function tokenSet(text) {
  return new Set(
    String(text || '')
      .toLowerCase()
      .split(/\W+/)
      .filter(Boolean)
  );
}

function jaccardSimilarity(a, b) {
  const sa = tokenSet(a);
  const sb = tokenSet(b);
  if (sa.size === 0 && sb.size === 0) return 1;
  if (sa.size === 0 || sb.size === 0) return 0;
  let intersection = 0;
  for (const t of sa) if (sb.has(t)) intersection += 1;
  return intersection / (sa.size + sb.size - intersection);
}

async function inactiveProviders() {
  // The shadow target is any non-active provider config — we pick the most
  // recent for each provider so a stale unused config isn't picked.
  const configs = await AiProviderConfig.find({ isActive: false })
    .sort({ updatedAt: -1 })
    .lean();
  const byProvider = new Map();
  for (const cfg of configs) {
    if (!byProvider.has(cfg.provider)) byProvider.set(cfg.provider, cfg);
  }
  return Array.from(byProvider.values());
}

function decryptCredentials(cfg) {
  return aiConfigService._decryptCredentials(cfg);
}

function moduleFor(provider) {
  if (provider === 'openai') return openaiProvider;
  if (provider === 'vertex') return vertexProvider;
  return null;
}

/**
 * Fire-and-forget: run the same prompt against each non-active provider config
 * and persist a comparison row. Never throws — shadow failures must not
 * affect the user-facing turn.
 */
function runShadow({ chatId, userId, intent, primaryResult, fitted, prefixCtx }) {
  setImmediate(async () => {
    try {
      const others = await inactiveProviders();
      if (!others.length) return;

      for (const cfg of others) {
        const mod = moduleFor(cfg.provider);
        if (!mod) continue;

        let bound;
        try {
          bound = mod.bind(decryptCredentials(cfg));
        } catch (err) {
          logger.warn('shadow bind failed', { provider: cfg.provider, error: err.message });
          continue;
        }

        const startedAt = Date.now();
        let result;
        let error = null;
        try {
          result = await bound.chat({
            messages: fitted.messages,
            model: cfg.models?.chat,
            userId: String(userId),
            maxTokens: fitted.maxOutputTokens,
            temperature: 0.4,
            fingerprint: prefixCtx?.fingerprint,
            prefixTokens: prefixCtx?.prefixTokens,
          });
        } catch (err) {
          error = err.message || 'shadow_error';
        }
        const latencyMs = Date.now() - startedAt;

        const shadowText = result?.text || '';
        const primaryText = primaryResult?.text || '';
        const sim = jaccardSimilarity(primaryText, shadowText);
        const shadowCost = result ? costFor(cfg.models?.chat, result.usage || {}) : 0;

        try {
          await AIShadowLog.create({
            chatId,
            userId: String(userId),
            intent,
            primary: {
              provider: primaryResult?.provider,
              model: primaryResult?.model,
              latencyMs: primaryResult?.latencyMs,
              tokens: primaryResult?.tokens,
              costUsd: primaryResult?.costUsd,
              sample: (primaryText || '').slice(0, 200),
              error: primaryResult?.error || null,
            },
            shadow: {
              provider: cfg.provider,
              model: cfg.models?.chat,
              latencyMs,
              tokens: result?.usage
                ? {
                    prompt: result.usage.prompt_tokens || 0,
                    cached: result.usage.prompt_tokens_details?.cached_tokens || 0,
                    completion: result.usage.completion_tokens || 0,
                  }
                : undefined,
              costUsd: shadowCost,
              sample: (shadowText || '').slice(0, 200),
              error,
            },
            diff: {
              sampleSimilarity: sim,
              latencyDeltaMs: (primaryResult?.latencyMs ?? 0) - latencyMs,
              costDeltaUsd: (primaryResult?.costUsd ?? 0) - shadowCost,
            },
            expiresAt: new Date(Date.now() + SHADOW_TTL_MS),
          });
        } catch (err) {
          logger.warn('shadow log write failed', { error: err.message });
        }
      }
    } catch (err) {
      logger.warn('shadow run failed', { error: err.message });
    }
  });
}

module.exports = { runShadow, jaccardSimilarity };
