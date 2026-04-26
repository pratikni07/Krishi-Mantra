let SpeechClient;
try {
  SpeechClient = require('@google-cloud/speech').v2.SpeechClient;
} catch (err) {
  SpeechClient = null;
}

const logger = require('../utils/logger');
const audioUtils = require('./audio-utils');
const { assertImplements } = require('./stt.interface');

// Crop + chemical names that the general STT model often misses. Boosting
// these via Google's adaptation phrases reduces WER on agronomic queries.
const AGRI_VOCAB = [
  // crops
  'tomato', 'टमाटर', 'टोमॅटो', 'onion', 'प्याज', 'कांदा', 'paddy', 'धान', 'भात',
  'wheat', 'गेहूं', 'गहू', 'cotton', 'कपास', 'कापूस', 'sugarcane', 'गन्ना', 'ऊस',
  'soybean', 'सोयाबीन', 'maize', 'मक्का', 'मका', 'chilli', 'मिर्च', 'मिरची',
  // common actives
  'mancozeb', 'मॅन्कोझेब', 'urea', 'यूरिया', 'युरिया', 'NPK',
  'imidacloprid', 'इमिडाक्लोप्रिड', 'cypermethrin', 'सायपरमेथ्रिन',
  // common terms
  'fungicide', 'फफूंदनाशक', 'बुरशीनाशक', 'pesticide', 'कीटनाशक', 'कीटकनाशक',
  'irrigation', 'सिंचाई', 'पाणी', 'sowing', 'बुवाई', 'पेरणी',
  'harvest', 'कटाई', 'कापणी', 'spray', 'छिड़काव', 'फवारणी',
];

const DEFAULT_LANGS = [
  'hi-IN', 'mr-IN', 'en-IN', 'te-IN', 'ta-IN', 'bn-IN', 'gu-IN', 'kn-IN', 'pa-IN',
];

function bind(cfg) {
  if (!SpeechClient) {
    throw new Error(
      '@google-cloud/speech not installed. Run `npm install @google-cloud/speech` in message-svc.'
    );
  }

  const region = cfg?.voice?.stt?.region || cfg?.extras?.location || 'asia-south1';
  const project = cfg?.extras?.project || cfg?.credentials?.serviceAccount?.project_id;
  if (!project) {
    throw new Error('Google STT requires extras.project or service-account project_id');
  }

  const apiEndpoint = `${region}-speech.googleapis.com`;
  const client = new SpeechClient({
    apiEndpoint,
    projectId: project,
    credentials: {
      client_email: cfg?.credentials?.serviceAccount?.client_email,
      private_key: cfg?.credentials?.serviceAccount?.private_key,
    },
  });
  const recognizerName = `projects/${project}/locations/${region}/recognizers/_`;

  function buildAdaptation(extraVocab) {
    const phrases = [...AGRI_VOCAB, ...(extraVocab || [])].slice(0, 100);
    if (!phrases.length) return undefined;
    return {
      phraseSets: [
        {
          inlinePhraseSet: {
            phrases: phrases.map((value) => ({ value, boost: 15 })),
          },
        },
      ],
    };
  }

  async function transcribe({
    audioBuffer,
    mimeType,
    hintedLanguage,
    vocabBoost,
  }) {
    if (!Buffer.isBuffer(audioBuffer) || audioBuffer.length === 0) {
      return { text: '', languageCode: hintedLanguage || 'hi', confidence: 0, durationSec: 0 };
    }
    const encoding = audioUtils.encodingFromMime(mimeType);
    const config = {
      explicitDecodingConfig:
        encoding !== 'ENCODING_UNSPECIFIED'
          ? {
              encoding,
              sampleRateHertz: 16000,
              audioChannelCount: 1,
            }
          : undefined,
      autoDecodingConfig: encoding === 'ENCODING_UNSPECIFIED' ? {} : undefined,
      languageCodes: hintedLanguage
        ? Array.from(new Set([audioUtils.bcp47For(hintedLanguage), 'en-IN']))
        : DEFAULT_LANGS,
      model: 'long',
      features: { enableAutomaticPunctuation: true, profanityFilter: true },
      adaptation: buildAdaptation(vocabBoost),
    };

    let response;
    try {
      const [r] = await client.recognize({
        recognizer: recognizerName,
        config,
        content: audioBuffer,
      });
      response = r;
    } catch (err) {
      logger.warn('google-stt.recognize_failed', { error: err.message, code: err.code });
      throw err;
    }

    const result = response?.results?.[0];
    const alt = result?.alternatives?.[0];
    const billedSec = response?.totalBilledDuration?.seconds
      ? Number(response.totalBilledDuration.seconds)
      : 0;
    return {
      text: (alt?.transcript || '').trim(),
      languageCode: result?.languageCode || hintedLanguage || 'hi',
      confidence: typeof alt?.confidence === 'number' ? alt.confidence : 0,
      durationSec: billedSec,
    };
  }

  function priceFor(durationSec) {
    // V2 logged-call pricing: $0.016 / minute (effective). Update centrally
    // in the cost dashboard when the SKU changes.
    const minutes = Math.max(0, Number(durationSec) || 0) / 60;
    return Number((minutes * 0.016).toFixed(6));
  }

  async function validate() {
    try {
      await client.listRecognizers({
        parent: `projects/${project}/locations/${region}`,
      });
      return { ok: true };
    } catch (err) {
      return { ok: false, code: err?.code || 'unknown', message: err?.message || 'failed' };
    }
  }

  return assertImplements({ provider: 'google', transcribe, priceFor, validate }, 'google');
}

module.exports = { bind, AGRI_VOCAB };
