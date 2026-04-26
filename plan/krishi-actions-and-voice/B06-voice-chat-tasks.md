# B06 — Voice Chat: Task Breakdown & Estimates

Concrete tickets grouped by sprint. Engineer-days (ed) for a mid-level engineer who has read B01–B05. Add 25% buffer for review cycles.

**Team assumed:** 1 backend (BE), 1 mobile (MO), 0.25 SRE, 0.25 PM/QA, 0.25 content/voice-quality reviewer (VR).

## Sprint 1 — Backend foundations + provider plumbing (weeks 1–2)

Goal: voice turn works end-to-end on staging behind a killswitch. No mobile UI yet.

| # | Ticket | Owner | Est (ed) | Depends on |
|---|--------|-------|----------|------------|
| VC01 | Add `@google-cloud/speech` and `@google-cloud/text-to-speech` to message-svc deps | BE | 0.25 | — |
| VC02 | `voice/stt.interface.js` + `voice/tts.interface.js` (contracts) | BE | 0.5 | — |
| VC03 | `voice/google-stt.provider.js` (transcribe + validate + priceFor) | BE | 1.5 | VC02 |
| VC04 | `voice/google-tts.provider.js` (synthesizeStream + validate + priceFor) | BE | 1 | VC02 |
| VC05 | `voice/audio-utils.js` (encodingFromMime, bcp47For, pluckSentence, estimateDurationSec) + unit tests | BE | 0.5 | — |
| VC06 | `voice/stt.factory.js` + `voice/tts.factory.js` (resolve from `AiProviderConfig.voice`) | BE | 0.5 | VC03, VC04 |
| VC07 | `services/voice-quota.service.js` (per-tier soft + hard limits) | BE | 0.5 | — |
| VC08 | `services/voice-cache.service.js` (24h TTS cache, 30-day opt-in path) | BE | 0.5 | — |
| VC09 | `services/voice-rate-limiter.service.js` (token-bucket per provider, 200ms wait) | BE | 0.5 | — |
| VC10 | Refactor: extract `services/ai-orchestrator.service.js` from `ai-v2.controller.js` (no behavior change) | BE | 1 | — |
| VC11 | `services/voice-turn.service.js` orchestrator (STT → AI orchestrator → sentence-aware TTS) | BE | 2 | VC03, VC04, VC06, VC07, VC08, VC10 |
| VC12 | `controllers/voice.controller.js` (POST /chat with multipart + SSE; GET /replay/:id) | BE | 1 | VC11 |
| VC13 | `routes/voice.routes.js` + mount in `index.js` + gateway proxy `/api/voice/*` | BE | 0.5 | VC12 |
| VC14 | Extend `AIChat.messages[].voice` schema + lazy migration on save | BE | 0.5 | — |
| VC15 | Extend `AiProviderConfig.voice` schema (stt + tts blocks) + admin form fields | BE | 0.5 | — |
| VC16 | Killswitch endpoints extension: voice / voice_stt / voice_tts targets | BE | 0.25 | — |
| VC17 | Prometheus voice metrics + structured `voice.turn` log line | BE | 0.5 | VC11 |
| VC18 | `__fixtures__/google-stt.json` + nock-based contract tests | BE | 0.5 | VC03 |
| VC19 | Voice latency budget unit test (mocked providers, P50 < 2.5s in test env) | BE | 0.5 | VC11 |
| VC20 | Staging deploy + admin smoke endpoint `/api/voice/test` (admin-gated, returns raw STT) | BE | 0.5 | VC13 |

**Sprint 1 subtotal:** BE ~13.5 ed.

## Sprint 2 — Mobile UI + internal beta (weeks 3–4)

Goal: hold-to-talk live in the staff build with full record/upload/playback flow.

| # | Ticket | Owner | Est (ed) | Depends on |
|---|--------|-------|----------|------------|
| VC21 | pubspec deps: `record`, `just_audio`, `permission_handler`, `audio_session` | MO | 0.25 | — |
| VC22 | `data/services/voice_recorder_service.dart` (start, stop, amplitude stream) | MO | 1 | VC21 |
| VC23 | `data/services/voice_player_service.dart` (gapless concatenating chunked playback) | MO | 1.5 | VC21 |
| VC24 | `data/services/voice_chat_service.dart` (multipart upload + SSE consume) | MO | 1 | VC22, VC12 |
| VC25 | Extract `lib/data/services/_sse.dart` parser (so `ai_stream_service` + `voice_chat_service` share it) | MO | 0.5 | — |
| VC26 | Extend `AIChatMessage` model with `VoiceMeta` (transcript, confidence, messageId, voiceName) | MO | 0.25 | — |
| VC27 | `presentation/controllers/voice_recorder_controller.dart` (record state machine + 60s auto-stop) | MO | 1 | VC22 |
| VC28 | `presentation/widgets/ai_chat/voice_input_button.dart` (hold-to-talk + states) | MO | 0.5 | VC27 |
| VC29 | `presentation/widgets/ai_chat/voice_record_overlay.dart` (waveform + slide-up cancel) | MO | 1 | VC27 |
| VC30 | `presentation/widgets/ai_chat/voice_replay_button.dart` (per-bubble replay) | MO | 0.5 | VC23 |
| VC31 | `presentation/widgets/ai_chat/voice_transcript_chip.dart` ("Wrong? Re-record" pill on low-confidence) | MO | 0.25 | VC26 |
| VC32 | Wire button + overlay into `ai_chat_screen.dart` composer | MO | 0.5 | VC28, VC29 |
| VC33 | Extend `ai_chat_controller.dart` with `appendUserPlaceholder` / `updateUserBubble` / `appendAssistantPlaceholder` / `appendAssistantText` / `finalizeAssistantBubble` | MO | 1 | VC26 |
| VC34 | Permission flow (mic) — first-launch dialog + denied state | MO | 0.5 | VC22 |
| VC35 | Localization strings for voice UI (en/hi/mr launch set) | MO + VR | 0.5 | — |
| VC36 | Settings screen: voice section (replies on/off, gender, retention toggle, "delete all") | MO | 1 | — |
| VC37 | DI registration + feature-flag gate (`VOICE_CHAT_ENABLED`) | MO | 0.25 | VC32 |
| VC38 | Internal beta — staff allowlist via `redis SADD voice-allowlist:userIds` | BE + MO | 0.25 | VC37 |
| VC39 | Real-device matrix QA (low-end Android 8, mid Android 13, iOS 16, iOS 17) | QA + MO | 1 | VC32 |
| VC40 | Latency measurement on staging (P50/P95) — record via engagement events | MO | 0.5 | VC32 |

**Sprint 2 subtotal:** MO ~10.5 ed, BE ~0.25 ed, QA ~1 ed, VR ~0.25 ed.

## Sprint 3 — Cohort rollout, admin UI, content tuning (weeks 5–6)

Goal: 100% rollout, admin tooling for voice spend, second-language reviewer cycle.

| # | Ticket | Owner | Est (ed) | Depends on |
|---|--------|-------|----------|------------|
| VC41 | Stage 1 (5% cohort) + monitor STT/TTS error rate, P95 latency, cost | BE + PM | 0.5 (over 3d) | VC39 |
| VC42 | Stage 2 (20%) — open Marathi voice to 5-farmer focus group, log feedback | PM + VR | 0.5 (parallel) | VC41 |
| VC43 | Voice quality fixes: tune sentence terminator regex, adjust voice pick logic per language | BE + VR | 1 | VC42 |
| VC44 | Stage 3 (50%) | BE + PM | 0.25 (over 3d) | VC43 |
| VC45 | Stage 4 (100%) | BE + PM | 0.25 | VC44 |
| VC46 | Admin UI: voice section on the AI Provider page (turns/day, STT/TTS/AI cost split, lang split) | (admin-FE) | 1 | VC17 |
| VC47 | Admin UI: voice config editor (`AiProviderConfig.voice.{stt,tts}`) on the OpenAI/Vertex pages | (admin-FE) | 1 | VC15 |
| VC48 | Admin UI: per-killswitch toggles (`voice`, `voice_stt`, `voice_tts`) on the ops page | (admin-FE) | 0.5 | VC16 |
| VC49 | Cost dashboard hooks: extend `aiStats` API to expose voice spend; admin renders voice row | BE + (admin-FE) | 0.5 | VC17 |
| VC50 | Mobile: settings copy in en/hi/mr (translations through the existing pipeline) | VR + MO | 0.5 | VC36 |
| VC51 | Cost simulation k6 run (1k users × 5 turns/day × 7 days) — assert spend under target | BE + SRE | 1 | VC45 |
| VC52 | "Voice unavailable" UI fallback when killswitch ON — already gated by feature flag, just polish copy | MO | 0.25 | VC37 |
| VC53 | Tone audit: 50 random Marathi voice replies reviewed, prosody issues filed against `voiceName` choice | VR | 1 (parallel) | VC45 |
| VC54 | Phase-2 language opening (bn/gu/pa) — voice pick mapping + reviewer signoff per language | VR + BE | 1 (parallel) | VC53 |
| VC55 | Post-launch retro + KPI review | PM | 0.25 | VC45 |

**Sprint 3 subtotal:** BE ~3.5 ed, MO ~0.75 ed, admin-FE ~3 ed, VR ~3 ed, SRE ~1 ed, PM ~1.75 ed.

## Summary

| Role | Total ed |
|------|---------|
| Backend (BE) | ~17 |
| Mobile (MO) | ~11.5 |
| Admin frontend | ~3 |
| Voice-quality reviewer (VR) | ~3.5 |
| SRE | ~1 |
| QA | ~1 |
| PM | ~2 |

**Timeline:** 3 sprints / 6 weeks from kickoff to 100% rollout. Backend provider plumbing + mobile UI both ride the critical path; admin polish overlaps with rollout.

## Critical path

1. **VC02 + VC10** (interfaces + orchestrator refactor) — every later voice ticket depends on these.
2. **VC03 + VC04** (STT + TTS providers).
3. **VC11** (orchestrator) — the single piece of logic that ties everything together.
4. **VC12 + VC13** (HTTP surface + gateway proxy).
5. **VC22 + VC23** (mobile audio I/O) — gates the mobile build.
6. **VC32** (mobile composer integration) — gates the user-visible launch.

Slip in this path delays everything. Provider extras, admin UI, and language expansion can all be parallelized.

## De-scope options

If running behind, drop or defer in order:

1. **Admin voice config editor (VC47, VC48)** — set the config via `db.aiproviderconfigs.updateOne(...)` for launch; build the UI in Sprint 4. Saves 1.5 ed.
2. **Voice settings screen (VC36, VC50)** — defaults are sensible; ship without per-user voice gender. Saves 1.5 ed.
3. **Replay endpoint (VC12 second handler + VC30)** — no historic replay at launch; users re-ask if they want to hear it again. Saves 1.5 ed (needs a small mobile fallback).
4. **Phase-2 languages (VC54)** — ship en/hi/mr only; bn/gu/pa become a follow-up release. Saves 1 ed.
5. **Sentence-aware TTS streaming (VC11 partial)** — synthesize the full reply once at the end; first-byte latency goes up but plumbing is simpler. Saves 1 ed at the cost of P50 latency.

## Out-of-scope (explicitly deferred)

- On-device STT/TTS — requires a model bundle the entry-level Android can't fit.
- Wake word ("Hey Krishi") — battery + privacy.
- Voice cloning / persona voices — vendor compliance + cost.
- Long-form audio playback (lecture mode).
- Multi-speaker turns ("speaker A: ..., speaker B: ...").
- Voice in the action card (separate epic — uses the same TTS provider but a different surface).

Each can become its own epic post-launch.

## Acceptance criteria (DoD per ticket)

- Code merged to `main` with passing CI.
- Unit tests on changed files ≥ 80% coverage; provider modules have nock-based contract tests.
- Backend: staging smoke green; one real-audio test transcribed correctly.
- Mobile: real-device QA pass on the launch matrix; latency telemetry confirms P95 < 4.5s.
- Voice quality: VR signoff on launch language voices.
- Cost ledger appears in the admin dashboard within 2 hours of deploy.
- Killswitch tested (engaged + disengaged on staging in < 30s).

## Definition of "ready to ship the feature"

The feature is production-ready when:

1. Sprint 1 + Sprint 2 ACs all complete.
2. Stage 3 (50% rollout) ran for 5 days with:
   - Voice turn P50 ≤ 2.5 s, P95 ≤ 4.5 s.
   - Success rate ≥ 97%.
   - Per-turn cost ≤ $0.012 averaged.
   - 0 quota-exhaustion incidents below the configured tier limits.
3. Killswitch tested at each granularity (`voice`, `voice_stt`, `voice_tts`).
4. Admin dashboard shows voice spend split (STT/TTS/AI) and quota utilisation.
5. 5-farmer Marathi focus group reports voice replies as "natural enough" (qualitative).
