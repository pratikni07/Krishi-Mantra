let textToSpeech;
try {
  textToSpeech = require('@google-cloud/text-to-speech');
} catch (err) {
  textToSpeech = null;
}

const logger = require('../utils/logger');
const audioUtils = require('./audio-utils');
const { assertImplements } = require('./tts.interface');

function bind(cfg) {
  if (!textToSpeech) {
    throw new Error(
      '@google-cloud/text-to-speech not installed. Run `npm install @google-cloud/text-to-speech` in message-svc.'
    );
  }

  const project =
    cfg?.extras?.project || cfg?.credentials?.serviceAccount?.project_id;
  if (!project) {
    throw new Error('Google TTS requires extras.project or service-account project_id');
  }

  const client = new textToSpeech.TextToSpeechClient({
    projectId: project,
    credentials: {
      client_email: cfg?.credentials?.serviceAccount?.client_email,
      private_key: cfg?.credentials?.serviceAccount?.private_key,
    },
  });

  const voicesByLang = (cfg?.voice?.tts?.voices && typeof cfg.voice.tts.voices === 'object')
    ? cfg.voice.tts.voices
    : null;

  /**
   * Phase-1 strategy: synthesize per sentence (single shot per call) and
   * yield one chunk per call. The voice-turn orchestrator calls this once
   * per sentence boundary; the mobile player concatenates chunks for
   * gapless playback.
   *
   * Phase-2 (commented hook below) can swap to native streamingSynthesize
   * for sub-sentence streaming.
   */
  async function* synthesizeStream({
    text,
    languageCode,
    voiceName,
    sampleRateHz = 24000,
  }) {
    const cleanText = String(text || '').trim();
    if (!cleanText) return;
    const targetVoice = voiceName || audioUtils.pickVoice(languageCode, voicesByLang);
    let response;
    try {
      const [r] = await client.synthesizeSpeech({
        input: { text: cleanText },
        voice: {
          languageCode: audioUtils.bcp47For(languageCode),
          name: targetVoice,
        },
        audioConfig: {
          audioEncoding: 'MP3',
          sampleRateHertz: sampleRateHz,
          speakingRate: 1.0,
        },
      });
      response = r;
    } catch (err) {
      logger.warn('google-tts.synth_failed', {
        error: err.message,
        code: err.code,
        voice: targetVoice,
      });
      throw err;
    }
    yield {
      seq: 0,
      mime: 'audio/mp3',
      audio: Buffer.from(response.audioContent, 'binary'),
      durationSec: audioUtils.estimateDurationSec(cleanText, languageCode),
      voiceName: targetVoice,
    };
  }

  function priceFor(charCount) {
    // Neural2 list price: $16/1M chars. Wavenet: $16/1M. Standard: $4/1M.
    // The voice-name picker below leans Neural2/Wavenet, so we bill at $16.
    return Number(((Number(charCount) || 0) / 1_000_000) * 16);
  }

  async function validate() {
    try {
      await client.listVoices({});
      return { ok: true };
    } catch (err) {
      return { ok: false, code: err?.code || 'unknown', message: err?.message || 'failed' };
    }
  }

  return assertImplements({ provider: 'google', synthesizeStream, priceFor, validate }, 'google');
}

module.exports = { bind };
