const PRICES = {
  'gpt-4.1-mini': { input: 0.15, cachedInput: 0.075, output: 0.6 },
  'gpt-4.1': { input: 2.0, cachedInput: 1.0, output: 8.0 },
  'gpt-4o-mini': { input: 0.15, cachedInput: 0.075, output: 0.6 },
  'gpt-4o': { input: 2.5, cachedInput: 1.25, output: 10.0 },
  'text-embedding-3-small': { input: 0.02, output: 0 },
  'text-embedding-3-large': { input: 0.13, output: 0 },
  'gemini-2.5-flash': { input: 0.075, cachedInput: 0.01875, output: 0.3 },
  'gemini-2.5-pro': { input: 1.25, cachedInput: 0.31, output: 5.0 },
  'text-embedding-005': { input: 0.025, output: 0 },
};

function costFor(model, usage = {}) {
  const p = PRICES[model];
  if (!p) return 0;
  const prompt = usage.prompt_tokens ?? usage.promptTokens ?? 0;
  const cached =
    usage.prompt_tokens_details?.cached_tokens ??
    usage.cached_tokens ??
    usage.cachedTokens ??
    0;
  const completion = usage.completion_tokens ?? usage.completionTokens ?? 0;
  const uncachedPrompt = Math.max(0, prompt - cached);
  const cachedPrice = p.cachedInput ?? p.input;
  return (
    (uncachedPrompt * p.input) / 1_000_000 +
    (cached * cachedPrice) / 1_000_000 +
    (completion * p.output) / 1_000_000
  );
}

function priceFor(model) {
  return PRICES[model] || null;
}

module.exports = { PRICES, costFor, priceFor };
