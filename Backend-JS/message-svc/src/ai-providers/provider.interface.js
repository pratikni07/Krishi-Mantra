/**
 * ProviderInterface — every AI provider module must export a `bind(cfg)` function
 * that returns an object implementing these methods. Inputs/outputs normalized to
 * OpenAI-style shapes so callers never branch on provider.
 *
 *   bind(cfg) -> {
 *     provider:       "openai" | "vertex",
 *     streamChat({ messages, model, userId, maxTokens, temperature, abortSignal }),
 *     chat({ messages, model, userId, maxTokens, temperature }),
 *     analyzeImages({ messages, imageUrls, model, userId }),
 *     embed({ input, model }),
 *     countTokens({ messages, model }),
 *     validate(),
 *   }
 *
 * Normalized stream event shape emitted by streamChat's iterator:
 *   { type: "delta", text: string }
 *   { type: "done",  usage: { prompt_tokens, completion_tokens, prompt_tokens_details?: { cached_tokens } } }
 *   { type: "error", code: string, message: string }
 */

const REQUIRED_METHODS = [
  'streamChat',
  'chat',
  'analyzeImages',
  'embed',
  'countTokens',
  'validate',
];

function assertImplements(instance, provider) {
  const missing = REQUIRED_METHODS.filter(
    (m) => typeof instance?.[m] !== 'function'
  );
  if (missing.length) {
    throw new Error(
      `Provider "${provider}" is missing required methods: ${missing.join(', ')}`
    );
  }
  return instance;
}

class ProviderUnavailable extends Error {
  constructor(provider, reason = 'unavailable') {
    super(`AI provider "${provider}" is unavailable: ${reason}`);
    this.code = 'PROVIDER_UNAVAILABLE';
    this.provider = provider;
    this.reason = reason;
  }
}

module.exports = { REQUIRED_METHODS, assertImplements, ProviderUnavailable };
