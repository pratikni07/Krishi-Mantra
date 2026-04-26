/**
 * STTProviderInterface — every speech-to-text provider implements this.
 *
 *   bind(cfg) -> {
 *     provider: "google" | "sarvam" | "ai4bharat",
 *     async transcribe({ audioBuffer, mimeType, hintedLanguage, vocabBoost }):
 *        { text, languageCode, confidence, durationSec },
 *     priceFor(durationSec) -> number  (USD; pure function, no IO),
 *     async validate() -> { ok, code?, message? },
 *   }
 *
 * Implementations live next to this file. The factory resolves by config.
 */
const REQUIRED_METHODS = ['transcribe', 'priceFor', 'validate'];

function assertImplements(instance, providerName) {
  const missing = REQUIRED_METHODS.filter(
    (m) => typeof instance?.[m] !== 'function'
  );
  if (missing.length) {
    throw new Error(
      `STT provider "${providerName}" missing methods: ${missing.join(', ')}`
    );
  }
  return instance;
}

class STTUnavailable extends Error {
  constructor(providerName, reason = 'unavailable') {
    super(`STT provider "${providerName}" unavailable: ${reason}`);
    this.code = 'STT_UNAVAILABLE';
    this.provider = providerName;
    this.reason = reason;
  }
}

module.exports = { REQUIRED_METHODS, assertImplements, STTUnavailable };
