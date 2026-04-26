/**
 * Pure helpers shared across STT, TTS, and the voice-turn orchestrator.
 *
 *  - encodingFromMime: mime → STT encoding hint
 *  - bcp47For: 2-letter lang code → BCP-47 (Indian variants)
 *  - shortLang: BCP-47 → 2-letter
 *  - estimateDurationSec: cheap audio-length estimate from text + lang
 *  - pluckSentence: streaming sentence-boundary extractor
 *  - pickVoice: per-language default voice name (used by Google TTS)
 */

const TERMINATORS = /([।.?!])\s+/;

const BCP47_MAP = {
  en: 'en-IN',
  hi: 'hi-IN',
  mr: 'mr-IN',
  bn: 'bn-IN',
  gu: 'gu-IN',
  kn: 'kn-IN',
  ml: 'ml-IN',
  or: 'or-IN',
  pa: 'pa-IN',
  ta: 'ta-IN',
  te: 'te-IN',
  ur: 'ur-IN',
  as: 'as-IN',
};

const DEFAULT_VOICES_GOOGLE = {
  en: 'en-IN-Neural2-A',
  hi: 'hi-IN-Neural2-A',
  mr: 'mr-IN-Wavenet-A',
  bn: 'bn-IN-Wavenet-A',
  gu: 'gu-IN-Wavenet-A',
  kn: 'kn-IN-Wavenet-A',
  ml: 'ml-IN-Wavenet-A',
  ta: 'ta-IN-Wavenet-A',
  te: 'te-IN-Standard-A',
  pa: 'pa-IN-Wavenet-A',
};

/**
 * MIME → STT encoding constant (Google Speech V2 names).
 * Returns ENCODING_UNSPECIFIED when we don't recognize the type so the
 * provider can run auto-detect rather than rejecting outright.
 */
function encodingFromMime(mime) {
  const m = String(mime || '').toLowerCase();
  if (/aac|m4a|mp4|audio\/x-m4a/.test(m)) return 'AAC';
  if (/wav|x-wav/.test(m)) return 'LINEAR16';
  if (/ogg|opus/.test(m)) return 'OGG_OPUS';
  if (/webm/.test(m)) return 'WEBM_OPUS';
  if (/mp3|mpeg/.test(m)) return 'MP3';
  if (/flac/.test(m)) return 'FLAC';
  return 'ENCODING_UNSPECIFIED';
}

function bcp47For(langCode) {
  const c = String(langCode || '').toLowerCase().slice(0, 2);
  return BCP47_MAP[c] || 'hi-IN';
}

function shortLang(bcp47) {
  return String(bcp47 || '').toLowerCase().slice(0, 2);
}

/**
 * Cheap text-length-based audio duration estimator. Avoids decoding the
 * synthesized audio just to bill it.
 *   ~3.0 chars/sec  for Devanagari/Indic (consonant clusters take longer)
 *   ~5.5 chars/sec  for Roman (English/Urdu transliteration)
 */
function estimateDurationSec(text, lang = 'hi') {
  const cps = ['en', 'ur'].includes(shortLang(lang)) ? 5.5 : 3.0;
  return Math.max(1, Math.round((String(text || '').length) / cps));
}

/**
 * Extract one sentence from the front of a streaming buffer. Returns null
 * if no terminator is present, else { text: "first sentence.", rest: "..." }.
 *
 * Used by the voice-turn orchestrator to flush sentences to TTS as the LLM
 * streams its reply, so playback can begin within ~250 ms of the first
 * sentence boundary instead of waiting for the full reply.
 */
function pluckSentence(buf) {
  if (!buf) return null;
  const m = TERMINATORS.exec(buf);
  if (!m) return null;
  const idx = m.index + m[0].length;
  return { text: buf.slice(0, idx).trim(), rest: buf.slice(idx) };
}

/**
 * Pick a default Google TTS voice for a language. Caller can override per
 * `AiProviderConfig.voice.tts.voices[lang]`.
 */
function pickVoice(lang, voiceMap) {
  const code = shortLang(lang);
  if (voiceMap && voiceMap[code]) return voiceMap[code];
  return DEFAULT_VOICES_GOOGLE[code] || DEFAULT_VOICES_GOOGLE.hi;
}

module.exports = {
  encodingFromMime,
  bcp47For,
  shortLang,
  estimateDurationSec,
  pluckSentence,
  pickVoice,
  BCP47_MAP,
  DEFAULT_VOICES_GOOGLE,
  TERMINATORS,
};
