# B03 — Voice Chat: Backend Implementation

This doc covers the new modules in **message-svc**, the route shape, the STT/TTS provider implementations, and how voice integrates with the existing AI controller.

## 1. Module layout

```
Backend-JS/message-svc/src/
├── voice/
│   ├── stt.interface.js              NEW — see B02 §3
│   ├── tts.interface.js              NEW
│   ├── stt.factory.js                NEW — resolves active STT
│   ├── tts.factory.js                NEW — resolves active TTS
│   ├── google-stt.provider.js        NEW
│   ├── google-tts.provider.js        NEW
│   └── audio-utils.js                NEW — transcoding, b64 helpers
├── controllers/
│   └── voice.controller.js           NEW — POST /api/voice/chat
├── routes/
│   └── voice.routes.js               NEW
├── services/
│   ├── voice-turn.service.js         NEW — orchestrates STT → AI → TTS
│   ├── voice-cache.service.js        NEW — TTS chunk cache, transcript cache
│   └── voice-quota.service.js        NEW — per-user voice-turn quotas
├── models/
│   └── ai-chat.model.js              EXTENDED — voice fields on messages
└── utils/
    └── sse.js                        EXTENDED — audio event helper
```

Reuses unchanged: `ai-config.service`, `farm-profile.client`, `context-tree.service`, `token-budget.service`, `chat-summarizer.service`, `token-usage.service`, `openai.provider`, `vertex.provider`, the AI factory.

## 2. The voice turn service

`services/voice-turn.service.js` is the orchestrator. Single entry point used by the controller:

```js
async function* run(req, res, params) {
  /*
   * params: {
   *   userId,
   *   chatId? (continue an existing chat),
   *   audioBuffer (Buffer),
   *   mimeType (string),
   *   preferredLanguage (string),
   *   voiceName? (override),
   * }
   *
   * Yields the same normalized event types the AI controller already speaks:
   *   { type: "transcript", text, lang, confidence }
   *   { type: "delta", text }
   *   { type: "audio", seq, mime, lang, data }
   *   { type: "done", chatId, usage, voice: {...} }
   *   { type: "error", code, message }
   */
}
```

The controller pipes these events into the SSE response (`utils/sse.js`).

### Pseudocode

```js
async function* run({ userId, chatId, audioBuffer, mimeType, preferredLanguage, voiceName }) {
  // 0. quota
  if (await VoiceQuota.exceeded(userId)) {
    yield { type: "error", code: "VOICE_QUOTA" };
    return;
  }

  // 1. STT
  const stt = await STTFactory.active();
  const tts = await TTSFactory.active();
  const sttResult = await stt.transcribe({
    audioBuffer, mimeType,
    hintedLanguage: preferredLanguage,
    vocabBoost: AGRI_VOCAB,    // crop names + chemical actives
  });
  if (!sttResult.text || sttResult.confidence < 0.25) {
    yield { type: "error", code: "STT_EMPTY", message: "couldn't_catch_that" };
    await VoiceQuota.refundLastCall(userId, "stt_only");
    return;
  }
  yield {
    type: "transcript",
    text: sttResult.text,
    lang: sttResult.languageCode,
    confidence: sttResult.confidence,
  };

  // 2. AI
  const provider = await AiFactory.active();
  const profile = await FarmProfileClient.get(userId);
  const chat = chatId
    ? await AIChat.findOne({ _id: chatId, userId })
    : new AIChat({ userId, metadata: { preferredLanguage: sttResult.languageCode } });
  const routing = await IntentRouter.classify(sttResult.text, {
    profileCrops: profile?.crops || [],
    provider,
  });
  const assembled = await ContextTree.assemble({
    chat, profile, userId,
    message: sttResult.text,
    routing,
    preferredLanguage: sttResult.languageCode || preferredLanguage,
  });
  const fitted = TokenBudget.fit(assembled);
  const aiStream = await provider.streamChat({
    messages: fitted.messages,
    model: fitted.model,
    userId, maxTokens: fitted.maxOutputTokens, temperature: 0.4,
    fingerprint: assembled.prefixFingerprint,
    prefixTokens: assembled.totalSystemTokens,
  });

  // 3. AI deltas + sentence-aware TTS streaming
  let textBuffer = "";
  let sentenceBuf = "";
  let seq = 0;
  const ttsLang = sttResult.languageCode || preferredLanguage || "hi";
  const voice = voiceName || pickVoice(ttsLang);
  let aiUsage = null;
  let totalAudioSec = 0;

  for await (const ev of aiStream) {
    if (ev.type === "delta") {
      textBuffer += ev.text;
      sentenceBuf += ev.text;
      yield { type: "delta", text: ev.text };

      const sentence = pluckSentence(sentenceBuf);
      if (sentence) {
        sentenceBuf = sentence.rest;
        for await (const chunk of tts.synthesizeStream({
          text: sentence.text,
          languageCode: ttsLang,
          voiceName: voice,
        })) {
          totalAudioSec += chunk.durationSec || 0;
          yield {
            type: "audio",
            seq: seq++,
            mime: chunk.mime,
            lang: ttsLang,
            data: chunk.audio.toString("base64"),
          };
        }
      }
    } else if (ev.type === "done") {
      aiUsage = ev.usage;
    } else if (ev.type === "error") {
      yield ev;
      return;
    }
  }
  // tail
  if (sentenceBuf.trim()) {
    for await (const chunk of tts.synthesizeStream({
      text: sentenceBuf.trim(),
      languageCode: ttsLang,
      voiceName: voice,
    })) {
      yield {
        type: "audio",
        seq: seq++,
        mime: chunk.mime,
        lang: ttsLang,
        data: chunk.audio.toString("base64"),
      };
    }
  }

  // 4. persist + cost
  const sttCostUsd = stt.priceFor(sttResult.durationSec || 0);
  const ttsCostUsd = tts.priceFor(textBuffer.length);
  const aiCostUsd  = costFor(fitted.model, aiUsage || {});
  recordVoiceTurn(chat, sttResult, textBuffer, aiUsage, sttCostUsd, ttsCostUsd, aiCostUsd, ttsLang, voice);
  await chat.save();
  await VoiceQuota.consume(userId);

  yield {
    type: "done",
    chatId: chat._id,
    title: chat.title,
    usage: aiUsage,
    voice: {
      sttCostUsd, ttsCostUsd, totalAudioSec,
      voiceName: voice, languageCode: ttsLang,
    },
  };
}
```

### `pluckSentence`

```js
const TERMINATORS = /([।.?!])\s+/;
function pluckSentence(buf) {
  const m = TERMINATORS.exec(buf);
  if (!m) return null;
  const idx = m.index + m[0].length;
  return { text: buf.slice(0, idx).trim(), rest: buf.slice(idx) };
}
```

The function returns at most one sentence; if more arrive in one delta, the loop handles them across iterations.

## 3. Voice controller

`controllers/voice.controller.js`:

```js
const multer = require("multer");
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 1 * 1024 * 1024 }, // 1 MB hard cap, 60s of AAC well under
});

const voiceTurn = require("../services/voice-turn.service");
const SSE = require("../utils/sse");

exports.middleware = upload.single("audio");

exports.chat = asyncHandler(async (req, res) => {
  const userId = req.user._id || req.user.id;
  if (!req.file?.buffer) {
    return res.status(400).json({ error: "audio file required" });
  }

  const stream = voiceTurn.run({
    userId,
    chatId: req.body?.chatId,
    audioBuffer: req.file.buffer,
    mimeType: req.file.mimetype || "audio/mp4",
    preferredLanguage: req.body?.preferredLanguage,
    voiceName: req.body?.voiceName,
  });

  SSE.open(res);
  try {
    for await (const ev of stream) SSE.data(res, ev);
  } catch (err) {
    SSE.data(res, { type: "error", code: "VOICE_TURN_FAILED", message: err.message });
  } finally {
    SSE.close(res);
  }
});

// Cached audio replay: 24h TTS cache; serves audio chunks for a previous message
exports.replay = asyncHandler(async (req, res) => {
  const { messageId } = req.params;
  const { voice = "default" } = req.query;
  const cached = await VoiceCache.getReplay(messageId, voice);
  if (!cached) return res.status(404).json({ error: "no_audio" });
  res.setHeader("Content-Type", cached.mime || "audio/mp3");
  res.setHeader("Cache-Control", "private, max-age=86400");
  return res.end(cached.buffer);
});
```

## 4. Routes

`routes/voice.routes.js`:

```js
const express = require("express");
const router = express.Router();
const auth = require("../middlewares/auth.middleware");
const limit = require("../middleware/rate-limit.middleware");
const VoiceController = require("../controllers/voice.controller");

const voiceLimiter = limit({
  windowMs: 60 * 1000,
  max: 30,
  message: { error: "voice_rate_limited", retryAfter: 60 },
});
const replayLimiter = limit({
  windowMs: 60 * 1000,
  max: 60,
});

router.post(
  "/chat",
  auth,
  voiceLimiter,
  VoiceController.middleware,
  VoiceController.chat
);
router.get("/replay/:messageId", auth, replayLimiter, VoiceController.replay);

module.exports = router;
```

Mounted at `/api/voice` in `index.js`. Gateway proxies `/api/voice/*` to message-svc identically to `/api/ai/*`.

## 5. STT provider — Google Cloud Speech V2

`voice/google-stt.provider.js`:

```js
const { SpeechClient } = require("@google-cloud/speech").v2;

function bind(cfg) {
  const region = cfg?.voice?.stt?.region || "asia-south1";
  const project = cfg?.extras?.project; // re-uses Vertex GCP creds
  const client = new SpeechClient({
    apiEndpoint: `${region}-speech.googleapis.com`,
    projectId: project,
    credentials: {
      client_email: cfg?.credentials?.serviceAccount?.client_email,
      private_key: cfg?.credentials?.serviceAccount?.private_key,
    },
  });
  const recognizerName = `projects/${project}/locations/${region}/recognizers/_`;

  async function transcribe({ audioBuffer, mimeType, hintedLanguage, vocabBoost }) {
    const config = {
      explicitDecodingConfig: {
        encoding: encodingFromMime(mimeType),
        sampleRateHertz: 16000,
        audioChannelCount: 1,
      },
      languageCodes: hintedLanguage
        ? [bcp47For(hintedLanguage), "en-IN"]
        : ["hi-IN", "mr-IN", "en-IN", "te-IN", "ta-IN", "bn-IN"],
      model: "long",
      features: { enableAutomaticPunctuation: true, profanityFilter: true },
      adaptation: vocabBoost ? buildAdaptation(vocabBoost) : undefined,
    };
    const [response] = await client.recognize({
      recognizer: recognizerName,
      config,
      content: audioBuffer,
    });
    const result = response.results?.[0]?.alternatives?.[0];
    return {
      text: result?.transcript || "",
      languageCode: response.results?.[0]?.languageCode || hintedLanguage || "hi",
      confidence: result?.confidence ?? 0,
      durationSec: response.totalBilledDuration?.seconds || 0,
    };
  }

  function priceFor(durationSec) {
    // V2 pricing; logged-call discount applies in production with logging on.
    const minutes = durationSec / 60;
    return minutes * 0.024;
  }

  async function validate() {
    try {
      await client.listRecognizers({ parent: `projects/${project}/locations/${region}` });
      return { ok: true };
    } catch (err) {
      return { ok: false, code: err.code, message: err.message };
    }
  }

  return { provider: "google", transcribe, priceFor, validate };
}
module.exports = { bind };
```

`AGRI_VOCAB` (from `voice-turn.service`) is a hard-coded list of crop names + chemical actives in en/hi/mr (e.g. *mancozeb, मॅन्कोझेब, urea, यूरिया, NPK*) — turned into Google's adaptation phrase boost. Improves recognition on terms the general model doesn't know well.

## 6. TTS provider — Google Cloud TTS Neural2

`voice/google-tts.provider.js`:

```js
const textToSpeech = require("@google-cloud/text-to-speech");

function bind(cfg) {
  const project = cfg?.extras?.project;
  const client = new textToSpeech.TextToSpeechClient({
    projectId: project,
    credentials: {
      client_email: cfg?.credentials?.serviceAccount?.client_email,
      private_key: cfg?.credentials?.serviceAccount?.private_key,
    },
  });
  const voices = cfg?.voice?.tts?.voices || {
    hi: "hi-IN-Neural2-A",
    mr: "mr-IN-Wavenet-A",
    en: "en-IN-Neural2-A",
    bn: "bn-IN-Wavenet-A",
    gu: "gu-IN-Wavenet-A",
    ta: "ta-IN-Wavenet-A",
    te: "te-IN-Standard-A",
    kn: "kn-IN-Wavenet-A",
    ml: "ml-IN-Wavenet-A",
    pa: "pa-IN-Wavenet-A",
  };

  async function* synthesizeStream({ text, languageCode, voiceName, sampleRateHz = 24000 }) {
    const targetVoice = voiceName || voices[shortLang(languageCode)] || voices.hi;
    const [response] = await client.synthesizeSpeech({
      input: { text },
      voice: { languageCode: bcp47For(languageCode), name: targetVoice },
      audioConfig: { audioEncoding: "MP3", sampleRateHertz: sampleRateHz, speakingRate: 1.0 },
    });
    yield {
      seq: 0,
      mime: "audio/mp3",
      audio: Buffer.from(response.audioContent, "binary"),
      durationSec: estimateDurationSec(text, languageCode),
    };
  }

  function priceFor(charCount) {
    return (charCount / 1_000_000) * 16; // Neural2 list price
  }

  async function validate() {
    try {
      await client.listVoices({});
      return { ok: true };
    } catch (err) {
      return { ok: false, code: err.code, message: err.message };
    }
  }
  return { provider: "google", synthesizeStream, priceFor, validate };
}
module.exports = { bind };
```

For phase 2, we swap to `streamingSynthesize` for true sub-sentence streaming. Phase 1 is sentence-shot for simplicity — still fast enough (≤ 250 ms/sentence).

## 7. Voice cache (TTS replay)

`services/voice-cache.service.js`:

```js
const KEY = (messageId, voice) => `voice-tts:${messageId}:${voice}`;
const TTL = 24 * 60 * 60;

exports.set = async (messageId, voice, mime, buffer) => {
  await redis.setex(KEY(messageId, voice), TTL, JSON.stringify({
    mime, b64: buffer.toString("base64"),
  }));
};

exports.getReplay = async (messageId, voice) => {
  const raw = await redis.get(KEY(messageId, voice));
  if (!raw) return null;
  const { mime, b64 } = JSON.parse(raw);
  return { mime, buffer: Buffer.from(b64, "base64") };
};
```

The voice-turn service writes to this cache after concatenating the per-sentence audio chunks for the assistant message. Replay endpoint reads from it.

For users who opted into 30-day retention, the cache TTL is bumped to 30 days and a copy is also written to S3 (presigned URL surfaced in `AIChat.messages[].voice.audioUrl`).

## 8. Quota service

`services/voice-quota.service.js`:

```js
const REDIS_KEY = (uid, day) => `voice-quota:${uid}:${day}`;
const SOFT_LIMIT_DAILY = parseInt(process.env.VOICE_DAILY_LIMIT || "30", 10); // free tier
const HARD_LIMIT_DAILY = parseInt(process.env.VOICE_DAILY_HARD_CAP || "100", 10);

exports.exceeded = async (userId) => {
  const day = new Date().toISOString().slice(0, 10);
  const cur = parseInt(await redis.get(REDIS_KEY(userId, day)) || "0", 10);
  return cur >= HARD_LIMIT_DAILY;
};
exports.consume = async (userId) => {
  const day = new Date().toISOString().slice(0, 10);
  const c = await redis.incr(REDIS_KEY(userId, day));
  if (c === 1) await redis.expire(REDIS_KEY(userId, day), 48 * 3600);
  return c;
};
exports.refundLastCall = async (userId, reason) => {
  const day = new Date().toISOString().slice(0, 10);
  await redis.decr(REDIS_KEY(userId, day));
};
```

Limits per subscription tier (final values in B05). Subscription tier read via the existing `subscription.service`.

## 9. AIChat schema extension

```js
// Per-message extension (extends the existing ai-chat.model.js schema)
voice: {
  type: { type: String, enum: ["user", "assistant"] },
  // For user (transcribed)
  transcript: { type: String },
  language: { type: String },
  confidence: { type: Number },
  durationSec: { type: Number },
  // For assistant (synthesised)
  audioCacheKey: { type: String },   // voice-tts:<messageId>:<voice>
  audioMime: { type: String },
  voiceName: { type: String },
  totalAudioSec: { type: Number },
  // Cost ledger
  sttCostUsd: { type: Number, default: 0 },
  ttsCostUsd: { type: Number, default: 0 },
},
```

These fields default to `undefined` for non-voice turns. Migration: lazy on next save.

## 10. Integration with existing AI controller

The voice controller is its own endpoint, but it shares 95% of the AI controller's logic. To avoid duplication, both controllers delegate the AI orchestration to a shared helper:

```js
// services/ai-orchestrator.service.js (refactor — extracted from ai-v2.controller.js)
exports.runChat = async function* ({ userId, chatId, userText, language, ... }) {
  // returns the same { transcript?, delta, done, error } stream we use today
};
```

`ai-v2.controller.js` still owns the HTTP/SSE wrapping for the text path. `voice.controller.js` adds STT before, TTS during. Both call `ai-orchestrator.runChat`.

This refactor is a small, safe change (T21 already has the orchestration logic; we're just splitting it out).

## 11. Audio utils

```js
// voice/audio-utils.js

const TERMINATORS = /([।.?!])\s+/;

// MIME → STT/encoder hint
exports.encodingFromMime = (mime) => {
  if (/aac|m4a|mp4/i.test(mime)) return "AAC";
  if (/wav/i.test(mime))         return "LINEAR16";
  if (/ogg|opus/i.test(mime))    return "OGG_OPUS";
  return "ENCODING_UNSPECIFIED";
};

exports.bcp47For = (langCode) => {
  // Map our 2-letter codes to BCP-47 expected by Google.
  const map = {
    en: "en-IN", hi: "hi-IN", mr: "mr-IN", bn: "bn-IN", gu: "gu-IN",
    kn: "kn-IN", ml: "ml-IN", or: "or-IN", pa: "pa-IN", ta: "ta-IN",
    te: "te-IN", ur: "ur-IN", as: "as-IN",
  };
  return map[(langCode || "").toLowerCase().slice(0, 2)] || "hi-IN";
};

exports.shortLang = (bcp47) => (bcp47 || "").toLowerCase().slice(0, 2);

// Cheap duration estimator — avoids decoding the audio just to know how long it is.
exports.estimateDurationSec = (text, lang = "hi") => {
  // ~3.0 chars/sec for hi/mr (Devanagari includes vowel marks)
  // ~5.5 chars/sec for en
  const cps = ["en", "ur"].includes(exports.shortLang(lang)) ? 5.5 : 3.0;
  return Math.max(1, Math.round((text || "").length / cps));
};

exports.pluckSentence = (buf) => {
  const m = TERMINATORS.exec(buf);
  if (!m) return null;
  const idx = m.index + m[0].length;
  return { text: buf.slice(0, idx).trim(), rest: buf.slice(idx) };
};
```

## 12. Environment variables

```
# Voice provider extras (used as bootstrap; primary config in AiProviderConfig.voice)
VOICE_STT_PROVIDER=google
VOICE_TTS_PROVIDER=google
VOICE_DAILY_LIMIT=30                # soft, per-user
VOICE_DAILY_HARD_CAP=100            # hard
VOICE_MAX_AUDIO_SEC=60
VOICE_TRANSCRIBE_TIMEOUT_MS=10000
VOICE_TTS_TIMEOUT_MS=8000
VOICE_AUDIO_RETENTION_DAYS=0        # 0 = ephemeral; user-toggle bumps to 30
```

## 13. Observability

Prometheus metrics (extends `services/metrics.service.js`):

```
krishi_voice_turn_duration_seconds{phase}            histogram (phase = stt | ai_first_token | ai_total | tts_total)
krishi_voice_turn_total{result}                       counter (success | stt_empty | ai_error | tts_error)
krishi_voice_stt_cost_usd_total                      counter
krishi_voice_tts_cost_usd_total                      counter
krishi_voice_audio_seconds_total                      counter (output)
krishi_voice_quota_exhausted_total                    counter
krishi_voice_provider_errors_total{provider, kind}    counter
```

Each successful voice turn emits a structured log (mirrors the existing `ai.turn`):

```json
{
  "event": "voice.turn",
  "userId": "hashed",
  "chatId": "...",
  "stt": { "provider": "google", "lang": "mr", "confidence": 0.92, "durationSec": 4.2, "costUsd": 0.0017 },
  "ai":  { "model": "gpt-4.1-mini", "tokens": { ... } },
  "tts": { "provider": "google", "voice": "mr-IN-Wavenet-A", "outSec": 7.4, "costUsd": 0.0016 },
  "totalLatencyMs": 3210
}
```

## 14. Security

- Audio buffer never written to disk — STT consumes the in-memory buffer directly.
- Optional 1 h S3 staging only used if STT provider requires URL input (Google V2 supports inline content; we don't need it).
- All voice routes require `auth`; no public access.
- TTS replay only fetches messages the requesting user owns (`AIChat.userId === req.user.id` check).
- Rate limit + per-user quota + per-provider RPM ceiling at the factory layer.
- Killswitch: `redis SET ai:killswitch:voice 1` → controller short-circuits with 503.

## 15. Testing

- Unit: `audio-utils.pluckSentence`, `bcp47For`, `estimateDurationSec` — pure functions.
- Provider contract: STT and TTS provider modules each have `__fixtures__/` with recorded responses; replayed via nock.
- Integration: compose stack with mocked STT/TTS endpoints serving canned audio + transcripts.
- Latency budget test: end-to-end staging measurement with 50 voice turns; P95 < 4 s.
- Chaos: STT provider returns 503 → controller returns SSE error cleanly + refunds quota.

## 16. Rollout

Phase 1 (week 1): backend deployed, killswitch ON. Internal admin endpoint `/api/voice/test` accepts audio + returns the raw STT result for debugging.

Phase 2 (week 1): mobile internal beta (5 staff) with the killswitch flipped per-user via `redis SADD voice-allowlist:userIds`.

Phase 3 (week 2): 5% mobile rollout.

Phase 4 (week 3): 50% rollout + admin UI for STT/TTS provider switch.

Phase 5 (week 4): 100%.

Killswitch: `redis SET ai:killswitch:voice 1` makes mobile fall back to text input only. Kill is < 1 s after Redis pub/sub propagates.
