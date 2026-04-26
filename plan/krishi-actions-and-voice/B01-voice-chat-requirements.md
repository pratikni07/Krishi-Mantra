# B01 — Voice Chat: Requirements & Goals

## 1. Problem statement

The AI chat is our most valuable feature, but it gates on *typing* in a script the farmer often struggles with. Marathi/Hindi/Telugu typing on a budget Android — even with Google's voice keyboard — is a wall.

WhatsApp solved this with **voice notes**: ~70% of rural India's communication is voice-based. Krishi-Mantra should match that ergonomically:

> *Hold a button. Speak in your language. Hear the answer back.*

Everything else stays the same — the existing context tree, provider registry, streaming SSE pipe, FarmProfile, and weather all just work. We add an **STT** (speech-to-text) on the way in and **TTS** (text-to-speech) on the way out.

## 2. Target user (a different cut)

The Action Card user (Sunita) is literate enough to read the card. Voice unlocks a different cohort:

**Ramesh, 54, Wardha district. Functionally illiterate — can spell his name and recognize crop names but can't read a paragraph. Marathi-speaker. Has a smartphone because his son got him one. Uses WhatsApp voice notes daily, never types.**

Ramesh is the user who:
- Uninstalled the app last year because typing was too hard.
- Sends 30-second voice notes to his neighbors asking about pest issues.
- Listens to AIR Krishi Vani every evening.
- Trusts a *spoken* recommendation more than a written one (spoken = neighbor; written = government).

Voice chat is for Ramesh.

## 3. Success criteria (KPIs)

| KPI | Baseline | Target (90 days post-launch) |
|-----|----------|------------------------------|
| % of AI chat sessions started with voice | 0 | ≥ 35% |
| Voice-session completion rate (turn finished cleanly) | n/a | ≥ 90% |
| Median end-of-speech → first audio playback | n/a | < 4 seconds |
| % of voice users who return next week | n/a | ≥ 50% (signal: voice unlocked the audience) |
| STT word-error-rate (WER) on a 100-clip Marathi crop-vocab test set | n/a | ≤ 18% |
| Per-voice-turn cost | — | ≤ $0.012 |
| Crash-free voice sessions | — | ≥ 99.5% |

## 4. In scope

- **Hold-to-talk button** on the AI chat screen (replaces nothing — sits next to the existing send button).
- **Live waveform** during recording for visual feedback.
- **STT** call sends the audio to the backend, which proxies to a configured provider, returns transcribed text + a confidence score.
- **AI streaming** continues using the existing SSE pipeline.
- **Streaming TTS** plays the AI reply as it arrives — sentence-by-sentence (so playback starts ~1 s after the first delta).
- **Auto-language detection** with explicit fallback to the user's `preferredLanguage`.
- **Replay** — every voice reply can be re-played from the chat history.
- **Transcript captions** under the audio for hearing-impaired users (and visual learners).

## 5. Out of scope (deferred)

- Voice for the action card (handled by per-item TTS in a follow-up).
- Multi-speaker / phone-call mode.
- Wake-word activation ("Hey Krishi") — privacy + battery cost; skip.
- On-device STT/TTS — too large for entry-level Androids; we proxy via backend.
- Voice cloning / specific voice persona — future epic.
- Long-form lecture playback / audiobook mode.

## 6. Non-goals

- We will **not** record audio without an explicit press-and-hold gesture.
- We will **not** keep raw audio after transcription unless the user opts in (privacy default).
- We will **not** run STT on the device — the audio is uploaded to the backend, transcribed via the active STT provider, and the audio is discarded by default.
- We will **not** stream audio uplink during recording. Record → upload completed file → transcribe. Simpler ops; better quality. (Streaming uplink is a phase-2 optimization if first-token latency becomes the user pain point.)

## 7. Constraints

| Constraint | Why |
|-----------|-----|
| End-of-speech to first audio playback **< 4 s on 4G** | Anything slower feels broken; voice users expect WhatsApp-level latency. |
| Voice-turn cost **≤ $0.012** ($0.005 STT + $0.005 LLM + $0.002 TTS at typical lengths) | Hard cap to keep AI subscription tiers viable. |
| Audio file ≤ 20 s default, hard cap 60 s | Long uploads on 2G/flaky 4G are unreliable; nudges users to ask focused questions. |
| Audio format: AAC at 16 kbps mono (~32 KB / 20s) | Tiny upload size; fits in a slow handover. |
| Language coverage at launch: hi, mr, en | Matches Build A's launch set. Other languages follow the same pattern. |
| Works offline-cached transcripts/audio for replay | Users may revisit a recommendation without connectivity. |

## 8. Success scenarios (concrete user stories)

### Story 1 — "Yellow spots on my tomato"
Ramesh holds the mic button.

> *"माझ्या टोमॅटोवर पिवळे डाग आहेत. काय करू?"*

He releases. 1.2 s later he hears:

> *"पिवळे डाग बुरशीमुळे होऊ शकतात. आज सकाळी 2.5 ग्रॅम/लीटर मॅन्कोझेब फवारणी करा. हातमोजे घाला. 7 दिवसांत पुन्हा."*

He taps "Done" on the action that was already on his card. End-to-end < 6 s.

### Story 2 — Code-mixed input
He says *"मेरे onion में thrips है क्या?"*. The STT transcribes mixed Devanagari + Roman; the AI handles it; the reply comes in Hindi.

### Story 3 — Bad mic / silence
He holds the button but there's wind noise / he says nothing audible. The STT returns an empty transcript with low confidence; the UI shows *"Couldn't catch that — try again"* with a re-record button. No charge.

### Story 4 — Long question
He starts asking about a 5-minute scheme application. At 30 s the UI shows *"Almost done — 30s left"*. At 60 s recording stops automatically and uploads what's there.

## 9. Risks & open questions

| Risk | Mitigation |
|------|------------|
| Hindi/Marathi STT word-error-rate too high on agri vocab | Pick provider with the best WER on Indian-language agriculture-domain data; bias prompt toward common crop terms; allow a "wrong transcription" tap to re-record. |
| TTS sounds robotic in Marathi → loss of trust | Pick a provider with neural Marathi voices (Google Cloud, Sarvam.ai). Test with focus group. |
| Voice cost balloons on a viral content moment | Per-user daily voice quota; admin-tunable rate cap; killswitch. |
| Audio upload fails on 2G | Audio < 64 KB at 20 s is small enough that even 2G handles it. Resumable upload via existing presigned-URL flow as a fallback. |
| Privacy — farmers shy about being recorded | Clear visual recording indicator + immediate deletion after STT (default) + setting to opt-in for audio retention. |
| Battery drain on cheap phones | Recording uses the platform `audio_recorder` which is hardware-efficient; don't run a continuous waveform decoder, just poll amplitude every 100ms. |
| Provider lock-in | Both STT and TTS go through a provider abstraction (B02 §3) so we can swap providers without controller-level changes. |

## 10. Voice provider candidates (matrix lives in B02)

We will support multiple STT and TTS providers behind an interface, exactly like the existing AI provider registry. Launch picks one per:

- **STT:** Google Cloud Speech-to-Text V2 (good Indian-language coverage) OR AI4Bharat IndicConformer (open + free, but ops-heavy).
- **TTS:** Google Cloud TTS (Neural2 voices for hi/mr/en) OR Sarvam.ai (Indian-native, lower latency to India region).

Both choices analysed in B02 with a launch recommendation.

## 11. What it should NOT feel like

- A clunky voice-search overlay.
- A Google Assistant-style detour from the chat.
- A separate "voice mode" tab.
- A hidden setting nobody finds.

It should feel like a natural extension of the chat: the existing chat has a send button → it gains a hold-to-speak button to its left. That's it.

## 12. Acceptance criteria (DoD)

A user is considered to have a working voice chat when:
- The chat screen shows a hold-to-speak button to the left of "send".
- Holding the button shows a recording overlay with: live amplitude waveform, elapsed time, "release to send" hint.
- Releasing uploads → transcribes → streams AI reply → speaks it back.
- The user message bubble shows the transcript and a "▶ Replay" button.
- The assistant bubble shows the streaming text and a "▶ Replay" button (audio caches for 24h).
- Network failure mid-record → friendly error + retry.
- Works in en/hi/mr at launch.
- Cost dashboard shows per-turn breakdown by provider.
