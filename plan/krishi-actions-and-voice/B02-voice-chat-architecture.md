# B02 — Voice Chat: Architecture (STT → AI → TTS)

## 1. End-to-end flow (one voice turn)

```
Mobile                Gateway                  message-svc                       Providers
──────                ───────                  ───────────                       ─────────
[hold mic]
record AAC ────────►  POST /api/voice/transcribe ───► VoiceService
                      (multipart, 30 KB)              ├─ STT.transcribe(audio) ─► Cloud STT
                                                      │      ↓
                                                      │   text + lang
                                                      │      ↓
                                                      │   active provider (chat)
                                                      │      ↓ context-tree assemble (existing)
                                                      │      ↓ provider.streamChat (SSE)
                                              ◄─SSE────────────────────────────  AI deltas
[render text]                                         │      ↓ on each sentence break:
                                                      │      TTS.synthesize(sentence) ─► Cloud TTS
                                              ◄─SSE────  audio chunks (b64) interleaved
[buffer + play]
```

The flow is **one HTTP turn** — the client uploads audio, opens an SSE connection on the same response, and consumes both `delta` (text) and `audio` (b64-encoded chunk) events as the AI streams.

Two channels of streaming:
- **Text deltas** — already wired (`utils/sse.js`).
- **Audio chunks** — new event type `{ type: "audio", seq: 0, mime: "audio/mp3", data: "<b64>" }`.

## 2. Why one HTTP turn (vs two)

We **could** split STT + AI + TTS into three round-trips. We don't, because:

- Three round-trips = three TLS handshakes + three RTTs over flaky 4G. P95 latency triples.
- The user's perceived latency is "release to first sound." Combining means we can start the LLM as soon as STT returns, and start TTS as soon as the first sentence emerges.
- The mobile UI is simpler — one promise to await, one stream to consume.

The cost: the mobile client can't show a transcribed-text "are you sure?" step before the AI fires. We don't need that step — Ramesh holds the button and expects an answer; if the transcript is wrong he re-records.

## 3. Provider-pluggable layer

Same pattern as the AI provider registry. Two new interface contracts.

### `STTProvider`
```js
module.exports.STTProviderInterface = {
  // Returns { text, languageCode, confidence, durationSec }.
  async transcribe({ audioBuffer, mimeType, hintedLanguage, vocabBoost }) {},
  async validate() {},
};
```

### `TTSProvider`
```js
module.exports.TTSProviderInterface = {
  // Returns an async iterable of {seq, mime, audio: Buffer} chunks.
  // Engines that don't natively stream simulate by chunking after synth.
  synthesizeStream({ text, languageCode, voiceName, sampleRateHz }) {},
  async validate() {},
};
```

`AiProviderConfig` schema gains an optional `stt` and `tts` block. The factory resolves the active STT/TTS the same way it resolves the chat provider — via `ai-config.service`.

## 4. Provider matrix

### STT candidates

| Provider | Languages (Hindi-area) | WER (rough, on agri-vocab) | Latency from India | Cost ($/min) | Notes |
|----------|------------------------|----------------------------|--------------------|---------------|-------|
| **Google Cloud Speech V2** | hi, mr, bn, gu, kn, ml, ta, te, ur, pa, en-IN | ~12% hi, ~16% mr | low (asia-south1) | $0.024 ($0.016 logged-call) | Solid; auto language detection works |
| **AI4Bharat IndicConformer** | All 13 + Indic-specific | ~10% hi, ~13% mr | self-hosted (we control) | hardware-only ($0 marginal) | Open weights; requires GPU pod |
| **Whisper (large-v3)** | hi/mr/etc. via OpenAI API | ~14% hi, ~20% mr | mid (US-region) | $0.006 | Multilingual but mediocre on Marathi |
| **Sarvam.ai** | All Indian languages | ~10% hi, ~12% mr (their claim; verify) | low (India hosted) | ~$0.012 | India-native; fewer SLAs |

**Launch pick: Google Cloud Speech V2** — best balance of language coverage + asia-south1 latency + operational maturity. Move to AI4Bharat self-hosted later for cost optimisation if volume justifies.

### TTS candidates

| Provider | Voices | Latency (text → first audio) | Cost ($/1M chars) | Notes |
|----------|--------|------------------------------|-------------------|-------|
| **Google Cloud TTS Neural2** | hi-IN-Wavenet-A/B/C/D/E, mr-IN, etc. | ~250 ms first byte | $16 ($4 standard) | Solid quality; native streaming |
| **Sarvam.ai TTS** | Native Indian voices, more natural prosody on Marathi/Tamil | ~200 ms (India region) | ~$10 | Best naturalness on Marathi in our tests; smaller market |
| **OpenAI TTS** | en + a few others | ~600 ms | $15 | Indian-language coverage thin |
| **Azure Neural TTS** | hi-IN, mr-IN, etc. | ~300 ms | $16 | Comparable to Google |

**Launch pick: Google Cloud TTS Neural2** — same provider as STT keeps GCP billing single-pane, asia-south1 region, native streaming with `streamingSynthesize`. Sarvam.ai is the strong second-choice for tone — we'll A/B for Marathi quality post-launch.

Both choices live in `AiProviderConfig` and are admin-switchable, exactly like the chat provider.

## 5. Streaming TTS strategy

The AI emits `delta` events with partial text. We can't synthesize per-token (too short for natural prosody) and we can't wait for the full reply (latency too high). Compromise: **synthesize on sentence boundaries.**

```
Buffer text deltas in a sentence accumulator.
When a sentence terminator (। ? ! .) appears, flush the accumulated sentence to TTS.
Stream the resulting audio chunks back to the client interleaved with text deltas.
```

```js
const SENTENCE_RE = /[।.?!]\s*$/;
let sentenceBuf = "";
let seq = 0;

for await (const chunk of providerStream) {
  if (chunk.type !== "delta") continue;
  sse.emit({ type: "delta", text: chunk.text });
  sentenceBuf += chunk.text;
  if (SENTENCE_RE.test(sentenceBuf)) {
    const sentence = sentenceBuf.trim();
    sentenceBuf = "";
    streamSentenceToClient(sentence, seq++); // fire-and-forget, awaits per-byte writes
  }
}
// Flush any tail
if (sentenceBuf.trim()) streamSentenceToClient(sentenceBuf.trim(), seq++);
sse.emit({ type: "done" });
```

`streamSentenceToClient` calls TTS, gets the audio bytes (or chunks for true streaming TTS), b64-encodes, and writes one or more `audio` SSE events.

### Why sentence-level

- Marathi sentences are typically 6–12 words → 2–4 s of audio → enough context for prosody to sound natural.
- Re-synthesising per-token would burn TTS quota AND sound choppy.
- Mobile audio player can queue chunks; gapless playback with a small jitter buffer.

## 6. Streaming TTS — provider gotchas

| Provider | Native streaming? | Chunking strategy |
|----------|-------------------|------------------|
| Google Cloud TTS | Yes — `streamingSynthesize` returns audio chunks as they're generated. | Pass through. Lowest latency. |
| Sarvam.ai | Single-shot; ~200 ms total | Synthesize per sentence; emit one chunk per sentence. |
| Azure | Streaming via SSML chunks | Same as Google. |
| OpenAI TTS | Single-shot (or chunked by their API) | Per-sentence synth; emit single chunk per sentence. |

The `TTSProviderInterface.synthesizeStream` always presents an async iterable to the controller — the difference between native streaming and per-sentence chunking is hidden inside the provider module.

## 7. Audio format on the wire

| Direction | Container | Codec | Sample rate | Bitrate |
|-----------|-----------|-------|-------------|---------|
| Mobile → server (STT) | `.m4a` (AAC in MP4) | AAC-LC | 16 kHz mono | 16 kbps |
| Server → mobile (TTS) | MP3 | MP3 (Google native) or OGG-Opus (cheaper) | 24 kHz mono | 32 kbps |

Why these:
- AAC mono 16k 16kbps: ~32 KB / 20 s — fits in a flaky 4G handover; STT engines are happy with 16 kHz.
- MP3 24k mono 32kbps: universal Android/iOS playback support; no codec install.

If we move to OGG-Opus we save ~30% bandwidth at the same quality, but we need the mobile player to support it (built-in on Android 5+, iOS 17+ — so feasible Phase 2).

## 8. Audio retention & privacy

Default privacy:
- Uplink audio is ephemeral — uploaded to a temp S3 bucket with a 1 h TTL, transcribed, then deleted.
- TTS output is cached for 24 h keyed on `(messageId, voiceName)` so "Replay" doesn't re-bill.
- Transcripts persist in `AIChat.messages[].voice.transcript` (along with `confidence` and `lang`) so the user can see what was heard.

User-controlled:
- A toggle in settings: "Keep my voice notes for 30 days" — for users who want to revisit. Off by default.
- A "Delete all voice notes" button immediately purges the bucket prefix.

We **never** train on user audio.

## 9. SSE event vocabulary (extended)

The existing `delta`/`done`/`error` events stay; we add:

```js
// Transcription preface (sent right after STT, before AI streaming starts)
{ type: "transcript", text: "माझ्या टोमॅटोवर...", lang: "mr", confidence: 0.92 }

// Audio chunk
{ type: "audio", seq: 0, mime: "audio/mp3", lang: "mr", data: "<b64>" }

// Final usage payload (extended)
{ type: "done", chatId, usage, voice: { sttCostUsd, ttsCostUsd, totalAudioSec } }
```

The mobile client can ignore unknown event types, so older clients fall back to text-only — no breaking change.

## 10. Failure modes

| Failure | Behavior |
|---------|---------|
| STT returns empty transcript | Emit `{ type: "error", code: "STT_EMPTY" }`; UI prompts "Couldn't catch that — try again". No AI/TTS spend. |
| STT returns low confidence (< 0.5) | Emit `transcript` with `confidence`; UI shows the text and a "Wrong? Re-record" button. AI proceeds. |
| AI provider 503 | Emit `error: PROVIDER_UNAVAILABLE`; mobile suggests retry. STT cost was sunk; we mark the turn as `failed`. |
| TTS fails mid-stream | Emit `error: TTS_FAILED` for the affected sentence; subsequent sentences still try TTS; client falls back to text-only for that segment. |
| Mobile drops connection | SSE reconnect via the existing client (if implemented); else mobile shows a "Connection lost" banner with the partial reply. |
| Audio upload > 60 s | Mobile auto-stops at 60 s and uploads what's there (per B01 §7). |
| Network 2G | AAC 16k 16kbps audio (~30 KB) fits; uplink takes ~3 s. SSE response uses chunked transfer; works fine. |

## 11. Language handling

Default language = `FarmProfile.preferredLanguage`. Two override paths:
1. **STT detects a different language** (high confidence) → AI replies in detected language; TTS voice matches.
2. **User force-flips** in settings ("always reply in Hindi") → ignore detection, always use the locked language.

The pattern matches the existing AI chat localisation — we just pipe the language code into the TTS voice selection.

## 12. Provider abstraction in code

```
Backend-JS/message-svc/src/voice/
├── stt.interface.js          NEW
├── tts.interface.js          NEW
├── stt.factory.js            NEW
├── tts.factory.js            NEW
├── google-stt.provider.js    NEW
├── google-tts.provider.js    NEW
├── sarvam-stt.provider.js    NEW (phase 2)
├── sarvam-tts.provider.js    NEW (phase 2)
└── audio-utils.js            NEW (transcoding helpers, base64 streaming)
```

Same pattern as `ai-providers/`. Both factories read from `AiConfig.getActive()` extras to pick the configured provider, falling back to env defaults.

## 13. AiProviderConfig — voice extension

```js
// Extends the existing schema (doc 04 in krishi-ai)
voice: {
  stt: {
    provider: { type: String, enum: ["google", "sarvam", "ai4bharat"] },
    region: String,                      // "asia-south1" / etc.
    extras: mongoose.Schema.Types.Mixed, // model, sampleRate, etc.
    isEnabled: { type: Boolean, default: true },
  },
  tts: {
    provider: { type: String, enum: ["google", "sarvam", "azure"] },
    region: String,
    voices: { type: Map, of: String },   // { hi: "hi-IN-Wavenet-D", mr: "mr-IN-Wavenet-A" }
    extras: mongoose.Schema.Types.Mixed,
    isEnabled: { type: Boolean, default: true },
  },
},
```

Admin UI gets per-provider editor pages just like the chat provider editor (B03 §6).

## 14. Threading model on the server

A voice turn ties up:
- One HTTP request (long — up to ~15 s).
- One open SSE connection.
- Background tasks: STT (~1 s), N TTS calls (~250 ms each).

In Node we run all this on the event loop; no extra workers. Concurrency cap per process: 200 in-flight voice turns (via the existing rate limiter).

## 15. Data flow recap

```
Mobile                                 message-svc                       Providers
──────                                 ───────────                       ─────────
record (AAC) ────►
                  ─audio multipart─►   VoiceController.handle
                                       ├─ presigned-url upload to S3 (1 h TTL)   (existing)
                                       ├─ STT.transcribe(audioBuffer or s3 ref)   ─► Google STT
                                       │      ↓ text, lang
                                       │      [emit SSE: transcript]
                                       ├─ ContextTree.assemble(...)               (existing)
                                       ├─ TokenBudget.fit(...)                    (existing)
                                       ├─ provider.streamChat(...)                ─► OpenAI/Vertex
                                       │      ↓ delta stream
                                       │      [emit SSE: delta]
                                       │      [on sentence: TTS.synthesizeStream] ─► Google TTS
                                       │      ↓ audio chunks
                                       │      [emit SSE: audio]
                                       ├─ persist chat + usage                   (existing pattern)
                                       └─ [emit SSE: done]
                                       ◄─── 24 h cache TTS chunks per messageId
playback ◄────
```

Every "(existing)" piece is what we already built in the krishi-ai sprints. Voice chat is **additive** — no rewrites.
