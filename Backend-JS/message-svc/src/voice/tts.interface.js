/**
 * TTSProviderInterface — every text-to-speech provider implements this.
 *
 *   bind(cfg) -> {
 *     provider: "google" | "sarvam" | "azure",
 *     synthesizeStream({ text, languageCode, voiceName, sampleRateHz }):
 *        async iterable of { seq, mime, audio: Buffer, durationSec? },
 *     priceFor(charCount) -> number  (USD; pure function, no IO),
 *     async validate() -> { ok, code?, message? },
 *   }
 *
 * For providers that don't natively stream (Sarvam, OpenAI), the impl
 * synthesizes per-sentence and yields one chunk per sentence — same
 * iterable contract.
 */
const REQUIRED_METHODS = ['synthesizeStream', 'priceFor', 'validate'];

function assertImplements(instance, providerName) {
  const missing = REQUIRED_METHODS.filter(
    (m) => typeof instance?.[m] !== 'function'
  );
  if (missing.length) {
    throw new Error(
      `TTS provider "${providerName}" missing methods: ${missing.join(', ')}`
    );
  }
  return instance;
}

class TTSUnavailable extends Error {
  constructor(providerName, reason = 'unavailable') {
    super(`TTS provider "${providerName}" unavailable: ${reason}`);
    this.code = 'TTS_UNAVAILABLE';
    this.provider = providerName;
    this.reason = reason;
  }
}

module.exports = { REQUIRED_METHODS, assertImplements, TTSUnavailable };
