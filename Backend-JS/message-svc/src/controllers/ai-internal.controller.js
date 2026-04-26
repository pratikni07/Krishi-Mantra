const asyncHandler = require('../utils/asyncHandler');
const { active: activeProvider } = require('../ai-providers/factory');
const { ProviderUnavailable } = require('../ai-providers/provider.interface');
const { costFor } = require('../utils/cost-table');
const TokenUsage = require('../services/token-usage.service');
const Metrics = require('../services/metrics.service');
const logger = require('../utils/logger');

const ALLOWED_PURPOSES = new Set([
  'action_card_fallback',
  'action_card_ai_first',
  'action_card_summary',
  'voice_internal',
]);

/**
 * Server-to-server AI call. Re-uses the active provider registry so the
 * single-active-provider invariant holds. Spend is logged with `purpose` so
 * the admin usage card can break out non-user traffic.
 *
 * Body: { messages, model?, maxTokens, temperature, userId, purpose, language? }
 *   - messages   OpenAI-style chat messages
 *   - userId     end-user this call is on behalf of (for cost attribution)
 *   - purpose    one of ALLOWED_PURPOSES; rejected otherwise
 *   - language   optional hint, passed through to providers that respect it
 */
exports.chat = asyncHandler(async (req, res) => {
  const { messages, model, maxTokens, temperature, userId, purpose, language } =
    req.body || {};

  if (!Array.isArray(messages) || !messages.length) {
    return res.status(400).json({ error: 'messages_required' });
  }
  if (!purpose || !ALLOWED_PURPOSES.has(purpose)) {
    return res.status(400).json({ error: 'unknown_purpose', purpose });
  }
  if (!userId) {
    return res.status(400).json({ error: 'userId_required' });
  }

  let provider;
  try {
    provider = await activeProvider();
  } catch (err) {
    const code = err instanceof ProviderUnavailable ? 'PROVIDER_UNAVAILABLE' : 'AI_INIT_FAILED';
    logger.warn('internal AI provider resolution failed', { code, error: err.message });
    return res.status(503).json({ error: code, message: err.message });
  }

  const startedAt = Date.now();
  try {
    const result = await provider.chat({
      messages,
      model,
      userId: String(userId),
      maxTokens: Math.min(maxTokens || 400, 800),
      temperature: temperature ?? 0.2,
    });
    const cost = costFor(result.model || model, result.usage || {});
    const durationMs = Date.now() - startedAt;

    TokenUsage.recordTurn({
      userId,
      model: result.model || model,
      provider: provider.provider,
      usage: result.usage,
      costUsd: cost,
    });
    Metrics.recordTurn?.({
      provider: provider.provider,
      model: result.model || model,
      intent: purpose,
      durationMs,
      usage: result.usage,
      costUsd: cost,
    });

    logger.info('ai.internal.turn', {
      caller: req.internal?.caller,
      purpose,
      userId: userId ? String(userId).slice(-8) : null,
      provider: provider.provider,
      model: result.model || model,
      tokens: {
        prompt: result.usage?.prompt_tokens || 0,
        cached: result.usage?.prompt_tokens_details?.cached_tokens || 0,
        completion: result.usage?.completion_tokens || 0,
      },
      costUsd: Number(cost.toFixed(6)),
      durationMs,
      language,
    });

    return res.status(200).json({
      success: true,
      text: result.text,
      model: result.model || model,
      provider: provider.provider,
      usage: result.usage,
      costUsd: Number(cost.toFixed(6)),
    });
  } catch (err) {
    logger.warn('internal AI chat failed', {
      purpose,
      caller: req.internal?.caller,
      error: err.message,
    });
    return res.status(502).json({ error: 'AI_CALL_FAILED', message: err.message });
  }
});

/**
 * Server-to-server vision call. Same active provider; routes through
 * provider.analyzeImages so OpenAI and Vertex behave identically from the
 * caller's POV. Image URLs may be public HTTPS or `data:` URLs (for inline
 * base64 from a backend-side fetch).
 *
 * Body:
 *   {
 *     messages,                  // OpenAI-style; the LAST message's text becomes the prompt
 *     imageUrls: string[],       // 1..5 image references
 *     model?,
 *     maxTokens?, temperature?,
 *     userId,
 *     purpose: "action_card_ai_first" | "voice_internal" | ...
 *     language?
 *   }
 */
exports.vision = asyncHandler(async (req, res) => {
  const {
    messages,
    imageUrls,
    model,
    maxTokens,
    temperature,
    userId,
    purpose,
    language,
  } = req.body || {};

  if (!Array.isArray(messages) || !messages.length) {
    return res.status(400).json({ error: 'messages_required' });
  }
  if (!Array.isArray(imageUrls) || !imageUrls.length) {
    return res.status(400).json({ error: 'imageUrls_required' });
  }
  if (imageUrls.length > 5) {
    return res.status(400).json({ error: 'too_many_images', max: 5 });
  }
  if (!purpose || !ALLOWED_PURPOSES.has(purpose)) {
    return res.status(400).json({ error: 'unknown_purpose', purpose });
  }
  if (!userId) return res.status(400).json({ error: 'userId_required' });

  let provider;
  try {
    provider = await activeProvider();
  } catch (err) {
    const code = err instanceof ProviderUnavailable ? 'PROVIDER_UNAVAILABLE' : 'AI_INIT_FAILED';
    return res.status(503).json({ error: code, message: err.message });
  }

  const startedAt = Date.now();
  try {
    const result = await provider.analyzeImages({
      messages,
      imageUrls,
      userId: String(userId),
      model,
    });
    const cost = costFor(result.model || model, result.usage || {});
    const durationMs = Date.now() - startedAt;

    TokenUsage.recordTurn({
      userId,
      model: result.model || model,
      provider: provider.provider,
      usage: result.usage,
      costUsd: cost,
    });
    Metrics.recordTurn?.({
      provider: provider.provider,
      model: result.model || model,
      intent: purpose,
      durationMs,
      usage: result.usage,
      costUsd: cost,
    });

    logger.info('ai.internal.vision', {
      caller: req.internal?.caller,
      purpose,
      userId: userId ? String(userId).slice(-8) : null,
      provider: provider.provider,
      model: result.model || model,
      imageCount: imageUrls.length,
      tokens: {
        prompt: result.usage?.prompt_tokens || 0,
        cached: result.usage?.prompt_tokens_details?.cached_tokens || 0,
        completion: result.usage?.completion_tokens || 0,
      },
      costUsd: Number(cost.toFixed(6)),
      durationMs,
      language,
    });

    return res.status(200).json({
      success: true,
      text: result.text,
      model: result.model || model,
      provider: provider.provider,
      usage: result.usage,
      costUsd: Number(cost.toFixed(6)),
    });
  } catch (err) {
    logger.warn('internal AI vision failed', {
      purpose,
      caller: req.internal?.caller,
      error: err.message,
    });
    return res.status(502).json({ error: 'AI_VISION_FAILED', message: err.message });
  }
});
