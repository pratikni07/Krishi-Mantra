const logger = require('../utils/logger');

let prom;
try {
  prom = require('prom-client');
} catch (err) {
  prom = null;
}

const namespace = 'krishi_ai_';

const noop = () => {};
const noopHistogram = { observe: noop, startTimer: () => noop };
const noopCounter = { inc: noop };
const noopGauge = { set: noop, inc: noop, dec: noop };

let registry = null;
let metrics = {
  turnDuration: noopHistogram,
  tokensTotal: noopCounter,
  costUsdTotal: noopCounter,
  cacheHitRatio: noopGauge,
  errors: noopCounter,
  budgetEscalations: noopCounter,
  shadowComparisons: noopCounter,
  voiceTurnDuration: noopHistogram,
  voiceTurnTotal: noopCounter,
  voiceSttCost: noopCounter,
  voiceTtsCost: noopCounter,
  voiceAudioSeconds: noopCounter,
  voiceQuotaExhausted: noopCounter,
  voiceProviderErrors: noopCounter,
};

function init() {
  if (!prom || registry) return registry;
  registry = new prom.Registry();
  prom.collectDefaultMetrics({ register: registry, prefix: namespace });

  metrics = {
    turnDuration: new prom.Histogram({
      name: `${namespace}turn_duration_seconds`,
      help: 'AI turn latency by phase',
      labelNames: ['provider', 'model', 'intent', 'phase'],
      buckets: [0.1, 0.3, 0.6, 1, 2, 4, 8, 15, 30],
      registers: [registry],
    }),
    tokensTotal: new prom.Counter({
      name: `${namespace}tokens_total`,
      help: 'Tokens by provider/model/kind',
      labelNames: ['provider', 'model', 'kind'],
      registers: [registry],
    }),
    costUsdTotal: new prom.Counter({
      name: `${namespace}cost_usd_total`,
      help: 'Estimated cost by provider/model',
      labelNames: ['provider', 'model'],
      registers: [registry],
    }),
    cacheHitRatio: new prom.Gauge({
      name: `${namespace}cache_hit_ratio`,
      help: 'Per-turn cache-hit ratio sample',
      labelNames: ['provider', 'model'],
      registers: [registry],
    }),
    errors: new prom.Counter({
      name: `${namespace}turn_errors_total`,
      help: 'Errors by provider/reason',
      labelNames: ['provider', 'reason'],
      registers: [registry],
    }),
    budgetEscalations: new prom.Counter({
      name: `${namespace}budget_escalations_total`,
      help: 'Number of token-budget escalations',
      labelNames: ['model'],
      registers: [registry],
    }),
    shadowComparisons: new prom.Counter({
      name: `${namespace}shadow_comparisons_total`,
      help: 'Shadow-mode comparison runs by primary/shadow pair',
      labelNames: ['primary', 'shadow'],
      registers: [registry],
    }),
    voiceTurnDuration: new prom.Histogram({
      name: `${namespace}voice_turn_duration_seconds`,
      help: 'Voice turn latency by phase',
      labelNames: ['phase'], // stt | ai_first_token | ai_total | tts_total | total
      buckets: [0.3, 0.6, 1, 2, 4, 8, 15, 30],
      registers: [registry],
    }),
    voiceTurnTotal: new prom.Counter({
      name: `${namespace}voice_turn_total`,
      help: 'Voice turn outcomes',
      labelNames: ['result'], // success | stt_empty | ai_error | tts_error | quota
      registers: [registry],
    }),
    voiceSttCost: new prom.Counter({
      name: `${namespace}voice_stt_cost_usd_total`,
      help: 'STT spend in USD',
      labelNames: ['provider'],
      registers: [registry],
    }),
    voiceTtsCost: new prom.Counter({
      name: `${namespace}voice_tts_cost_usd_total`,
      help: 'TTS spend in USD',
      labelNames: ['provider'],
      registers: [registry],
    }),
    voiceAudioSeconds: new prom.Counter({
      name: `${namespace}voice_audio_seconds_total`,
      help: 'Total seconds of TTS audio synthesized',
      labelNames: ['provider'],
      registers: [registry],
    }),
    voiceQuotaExhausted: new prom.Counter({
      name: `${namespace}voice_quota_exhausted_total`,
      help: 'Voice turns rejected due to quota cap',
      labelNames: ['reason'], // hard_count | daily_cost
      registers: [registry],
    }),
    voiceProviderErrors: new prom.Counter({
      name: `${namespace}voice_provider_errors_total`,
      help: 'STT/TTS provider errors',
      labelNames: ['provider', 'kind'], // kind = stt | tts
      registers: [registry],
    }),
  };
  logger.info('prom-client metrics initialized', { namespace });
  return registry;
}

function recordTurn({ provider, model, intent, durationMs, usage, costUsd, error }) {
  if (!prom) return;
  const labels = { provider: provider || 'unknown', model: model || 'unknown', intent: intent || 'general' };
  metrics.turnDuration.observe({ ...labels, phase: 'total' }, (durationMs || 0) / 1000);
  if (error) {
    metrics.errors.inc({ provider: provider || 'unknown', reason: error });
    return;
  }
  const prompt = usage?.prompt_tokens ?? 0;
  const cached = usage?.prompt_tokens_details?.cached_tokens ?? 0;
  const completion = usage?.completion_tokens ?? 0;
  metrics.tokensTotal.inc({ provider: provider || 'unknown', model: model || 'unknown', kind: 'prompt' }, prompt);
  metrics.tokensTotal.inc({ provider: provider || 'unknown', model: model || 'unknown', kind: 'cached' }, cached);
  metrics.tokensTotal.inc({ provider: provider || 'unknown', model: model || 'unknown', kind: 'completion' }, completion);
  metrics.costUsdTotal.inc({ provider: provider || 'unknown', model: model || 'unknown' }, costUsd || 0);
  if (prompt > 0) {
    metrics.cacheHitRatio.set({ provider: provider || 'unknown', model: model || 'unknown' }, cached / prompt);
  }
}

function recordBudgetEscalation(model) {
  if (!prom) return;
  metrics.budgetEscalations.inc({ model: model || 'unknown' });
}

function recordShadow({ primary, shadow }) {
  if (!prom) return;
  metrics.shadowComparisons.inc({ primary: primary || 'unknown', shadow: shadow || 'unknown' });
}

/**
 * Voice telemetry. Each finished voice turn calls this exactly once with
 * `result` = success | stt_empty | ai_error | tts_error | quota.
 */
function recordVoiceTurn({
  result,
  totalMs,
  sttMs,
  aiMs,
  ttsMs,
  sttProvider,
  ttsProvider,
  sttCostUsd,
  ttsCostUsd,
  audioOutSec,
}) {
  if (!prom) return;
  metrics.voiceTurnTotal.inc({ result: result || 'unknown' });
  if (typeof totalMs === 'number') {
    metrics.voiceTurnDuration.observe({ phase: 'total' }, totalMs / 1000);
  }
  if (typeof sttMs === 'number') metrics.voiceTurnDuration.observe({ phase: 'stt' }, sttMs / 1000);
  if (typeof aiMs === 'number') metrics.voiceTurnDuration.observe({ phase: 'ai_total' }, aiMs / 1000);
  if (typeof ttsMs === 'number') metrics.voiceTurnDuration.observe({ phase: 'tts_total' }, ttsMs / 1000);
  if (sttCostUsd > 0) metrics.voiceSttCost.inc({ provider: sttProvider || 'unknown' }, sttCostUsd);
  if (ttsCostUsd > 0) metrics.voiceTtsCost.inc({ provider: ttsProvider || 'unknown' }, ttsCostUsd);
  if (audioOutSec > 0) {
    metrics.voiceAudioSeconds.inc({ provider: ttsProvider || 'unknown' }, audioOutSec);
  }
}

function recordVoiceQuotaExhausted(reason) {
  if (!prom) return;
  metrics.voiceQuotaExhausted.inc({ reason: reason || 'unknown' });
}

function recordVoiceProviderError(provider, kind) {
  if (!prom) return;
  metrics.voiceProviderErrors.inc({
    provider: provider || 'unknown',
    kind: kind || 'unknown',
  });
}

async function exportMetrics() {
  if (!prom || !registry) return '';
  return registry.metrics();
}

function contentType() {
  return prom?.register?.contentType || 'text/plain; version=0.0.4; charset=utf-8';
}

module.exports = {
  init,
  recordTurn,
  recordBudgetEscalation,
  recordShadow,
  recordVoiceTurn,
  recordVoiceQuotaExhausted,
  recordVoiceProviderError,
  exportMetrics,
  contentType,
  isAvailable: () => prom !== null,
};
