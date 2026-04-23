# 12 — Task Breakdown & Estimates

Converts the plan into concrete tickets, grouped by sprint. Estimates are engineer-days (ed) for a mid-level engineer familiar with the codebase. Add 20–30% buffer for review cycles. Dependencies called out explicitly.

**Team assumed:** 2 backend (BE1, BE2), 1 mobile (MO1), 0.5 admin-frontend (AD1), 0.25 SRE, 0.25 PM/design. Sprints are 2 weeks.

## Sprint 1 — Foundations (weeks 1–2)

Goal: new collections in prod, OpenAI provider callable in staging, context tree skeleton.

| # | Ticket | Owner | Est (ed) | Depends on |
|---|--------|-------|----------|-----------|
| T01 | Create `FarmProfile` model + indexes + unit tests | BE1 | 1 | — |
| T02 | Create `WeatherSnapshot` model + TTL index | BE1 | 0.5 | — |
| T03 | Write migration scripts M1, M2, M4; run on staging | BE1 | 1.5 | T01, T02 |
| T04 | `FarmProfile` controller: upsert, patch, crop CRUD | BE1 | 2 | T01 |
| T05 | Validation utilities (area, dates, enum sets) + tests | BE1 | 1 | T04 |
| T06 | Master crop search endpoint + caching | BE1 | 0.5 | — |
| T07 | Redis pub/sub: `farm-profile.updated` → message-svc invalidator | BE1 | 0.5 | T04 |
| T07a | `AiProviderConfig` model + `AiProviderAudit` model + indexes | BE1 | 1 | — |
| T07b | `utils/secret-box.js` — AES-256-GCM with KMS/env key source + tests (round-trip, tamper, rotation) | BE1 | 1.5 | — |
| T07c | `services/ai-config.service.js` (get active, decrypt lazy, Redis cache, pub/sub invalidator) | BE1 | 1 | T07a, T07b |
| T07d | `ai-providers/provider.interface.js` + `factory.js` with kill-switch & auto-fallback | BE2 | 1 | — |
| T08 | `openai.provider.js` — chat/stream/vision/embed/validate + retry + key rotation (reads from AiProviderConfig via factory) | BE2 | 2 | T07c, T07d |
| T09 | `cost-table.js` + per-provider usage accounting helper | BE2 | 0.5 | T08 |
| T10 | `weather.service.js` + Open-Meteo provider + snapshot cache | BE2 | 2 | T02 |
| T11 | `GET /api/weather/7day` route + gateway rule | BE2 | 0.5 | T10 |
| T12 | Gateway routes added for `/api/farm-profile/*` and `/api/weather/*` | BE1 | 0.5 | T04, T11 |
| T13 | Scaffold `context-tree.service.js` with L0+L1 (no crops/weather yet) | BE2 | 1.5 | T08 |
| T14 | Staging deploy + smoke test | BE1+BE2 | 0.5 | all |

**Sprint 1 subtotal:** ~18 ed across 2 BE in 2 wks (tight — push T07b to Sprint 2 if needed; factory can use env-key placeholder).

## Sprint 2 — Context tree + mobile onboarding (weeks 3–4)

Goal: full tree assembling & token-budgeted; mobile onboarding usable in dev.

| # | Ticket | Owner | Est (ed) | Depends on |
|---|--------|-------|----------|-----------|
| T15 | L2 Crops layer + intent-aware filter | BE2 | 1.5 | T13 |
| T16 | L3 Weather layer + fingerprint + Redis cache | BE2 | 1 | T10, T13 |
| T17 | Intent router (regex + LLM fallback) | BE2 | 1.5 | T08 |
| T18 | `token-budget.service.js` + tiktoken integration | BE2 | 1 | T13 |
| T19 | `chat-summarizer.service.js` (async, fire-and-forget) | BE2 | 1 | T08 |
| T20 | L4 summary layer + invalidation | BE2 | 0.5 | T19 |
| T21 | Rewire `ai.controller.sendMessage` to use tree + OpenAI | BE2 | 2 | T15–T20 |
| T22 | SSE support (`Accept: text/event-stream`) | BE2 | 1 | T21 |
| T23 | Rewire vision endpoints (`analyze-image`, `analyze-multi`) | BE2 | 1 | T08, T21 |
| T24 | Extend `AIChat` schema (usage, summary, farmProfileRef) | BE2 | 0.5 | — |
| T25 | Per-turn logging + cost accumulation | BE2 | 0.5 | T09, T21 |
| T26 | Mobile: `FarmProfile` model, `CropEntry`, repo, controllers | MO1 | 1.5 | T04 |
| T27 | Mobile: onboarding Step 1 (location + basics) | MO1 | 2 | T26 |
| T28 | Mobile: onboarding Step 2 (farm) | MO1 | 1.5 | T27 |
| T29 | Mobile: onboarding Step 3 (crops picker + card) | MO1 | 2 | T28 |
| T30 | Mobile: onboarding Step 4 (review) + controller orchestration | MO1 | 1 | T29 |
| T31 | Mobile: draft local persistence | MO1 | 0.5 | T26 |
| T32 | Prompt files: 13 language `core.*.md` — EN/HI/MR first | BE2 + ext reviewer | 1 | — |
| T32a | `vertex.provider.js` — streamChat/chat/analyzeImages/embed/validate + region fallback | BE2 | 2 | T07d |
| T32b | `vertex-adapters.js` (OpenAI↔Vertex format converters incl. S3 presigned fallback) | BE2 | 1 | T32a |
| T32c | Vertex context-cache integration (opportunistic, when prefix ≥4k tokens) | BE2 | 1 | T32a |
| T32d | `AiProviderConfig` admin controller: upsert-openai, upsert-vertex (multipart), validate, activate (Mongo session), rotate, audit log | BE1 | 2 | T07a, T07c, T08, T32a |
| T32e | Admin routes + JWT-admin middleware + per-admin rate-limit + CSRF | BE1 | 1 | T32d |
| T32f | Migration M5: seed OpenAI config from env vars + audit stub | BE1 | 0.5 | T32d |

**Sprint 2 subtotal:** BE2 ~15 ed, BE1 ~3.5 ed, MO1 ~8.5 ed. Heavy — consider pulling T32a–T32c to Sprint 3 if needed (Vertex isn't critical-path for v1 cutover).

## Sprint 3 — Shadow mode, weather UI, Edit Farm (weeks 5–6)

Goal: shadow traffic live; mobile can edit profile post-onboarding; home weather uses our API.

| # | Ticket | Owner | Est (ed) | Depends on |
|---|--------|-------|----------|-----------|
| T33 | Shadow-mode wiring (parallel OpenAI call + logging) | BE2 | 2 | T21 |
| T34 | `ai_shadow_log` collection + dashboard | BE2 + SRE | 1 | T33 |
| T35 | Kill-switches (Redis keys) + ops runbook | BE2 | 0.5 | T21 |
| T36 | Daily/minute cost caps + enforcement | BE2 | 1 | T25 |
| T37 | Prompt regression harness (50 canned queries) | BE2 | 1 | T21 |
| T38 | Prometheus exporter for AI metrics | BE2 + SRE | 1 | T25 |
| T39 | Grafana dashboards: ops / cost / quality | SRE | 2 | T38 |
| T40 | Alerts + PagerDuty routing | SRE | 0.5 | T39 |
| T41 | Mobile: SSE client `ai_stream_service.dart` | MO1 | 1.5 | T22 |
| T42 | Mobile: AI chat screen streaming + profile banner + crops chip row | MO1 | 1.5 | T41 |
| T43 | Mobile: Edit-Farm screen (3 tabs) | MO1 | 2 | T26 |
| T44 | Mobile: Home weather switched to our API | MO1 | 1 | T11 |
| T45 | Mobile: remote-config flag plumbing (`NEW_AI_ENABLED`, `ONBOARDING_V2_ENABLED`) | MO1 | 0.5 | — |
| T46 | Mobile unit + widget tests for new controllers/screens | MO1 | 2 | T29, T43 |
| T46a | Admin UI: `/settings/ai-provider` list + active card (Next.js page) | AD1 | 1.5 | T32d |
| T46b | Admin UI: OpenAI editor form (keys/models, validate, save+activate) | AD1 | 1.5 | T32d, T46a |
| T46c | Admin UI: Vertex editor form (SA JSON upload, WIF option, regions) | AD1 | 2 | T32d, T46a |
| T46d | Admin UI: activate confirmation modal + health card + audit timeline | AD1 | 1.5 | T46a |
| T46e | Admin UI: usage/cost card for active provider | AD1 | 1 | T38 |
| T46f | Admin E2E test (Cypress): create vertex config → upload SA → validate → activate → verify AI flow | AD1 + BE2 | 1 | T46c |
| T46g | Metrics labels split by provider; dashboards updated | SRE | 1 | T38, T39 |

**Sprint 3 subtotal:** BE2 ~7 ed, MO1 ~8.5 ed, SRE ~4.5 ed, AD1 ~8.5 ed.

## Sprint 4 — Rollout & cleanup (weeks 7–8)

Goal: gradual ramp to 100%, remove legacy, final cleanup.

| # | Ticket | Owner | Est (ed) | Depends on |
|---|--------|-------|----------|-----------|
| T47 | Load test (k6) on staging | BE2 | 1 | T21 |
| T48 | Stage 1 (shadow 10%) launch + monitor 3 days | BE2 + PM | 0.5 | T33–T40 |
| T49 | Stage 2 (5% `openai`) + internal beta group | BE2 + PM | 0.5 | T48 |
| T50 | Stage 3 (20%) ramp | BE2 | 0.5 | T49 |
| T51 | Stage 4 (5% mobile onboarding beta) | MO1 + PM | 0.5 | T45 |
| T52 | Stage 5 (100% backend `registry` mode) | BE2 | 0.5 | T50 |
| T52a | Stage 5.5 — Vertex config seeded; 20-user internal test; Activate rehearsal + rollback rehearsal | BE2 + AD1 + PM | 1 | T46c, T32a |
| T53 | Stage 6 (100% mobile `NEW_AI_ENABLED`) | MO1 | 0.5 | T51 |
| T54 | Remove `groq-sdk`, `@google/generative-ai`, legacy code paths | BE2 | 1 | T52 |
| T55 | Remove OWM direct calls from mobile | MO1 | 0.5 | T44 |
| T56 | Delete obsolete env vars from infra configs | SRE | 0.5 | T54 |
| T57 | Post-mortem doc + lessons learned | PM | 0.5 | T53 |
| T58 | Translate remaining 10 language core prompts with native reviewers | BE2 + ext | 2 (parallel) | T32 |
| T59 | Enable `AI_PROVIDER=openai` default in code, remove flag logic | BE2 | 0.5 | T54 |

**Sprint 4 subtotal:** ~8 ed across team.

## Summary

| Role | Total engineer-days |
|------|---------------------|
| Backend (BE1 + BE2) | ~50 ed (provider registry + Vertex add ~10 ed over the original OpenAI-only plan) |
| Mobile (MO1) | ~22 ed |
| Admin frontend (AD1) | ~9 ed (new role for this plan) |
| SRE | ~6 ed |
| PM / QA | ~3 ed |

**Timeline:** 4 sprints / 8 weeks from kickoff to 100% rollout. Vertex + admin panel can be parallelized with the OpenAI rollout — they're on the same critical path only for Stage 5.5.

## Critical path

1. **T01–T04** (farm profile model + controller) — unblocks mobile onboarding and context tree L1.
2. **T07a–T07d** (AiProviderConfig model + secret-box + factory) — unblocks every provider implementation.
3. **T08** (OpenAI provider) — unblocks entire AI rewrite.
4. **T21** (AI controller rewire) — unblocks shadow mode and rollout stages.
5. **T33** (shadow) — unblocks go/no-go decision for Stage 2.

Vertex (T32a–T32c) and admin UI (T46a–T46f) are **parallel tracks**, not blockers for OpenAI cutover. They are blockers for Stage 5.5 (Vertex rollout) but shippable separately if we need to ship OpenAI-only first.

Any slip in the critical path cascades; everything else can run in parallel or be slightly reordered.

## De-scope options (if running behind)

If needed for date commitment, drop or defer in order:
1. **Vertex provider** (T32a–T32c, T46c, T52a) — ship OpenAI-only at launch; add Vertex as a follow-up epic. Saves ~6 ed. Admin UI still gets built (T46a, T46b) since it's useful with one provider too.
2. **Admin UI for editing configs** (T46a–T46f) — if mega-crunched, expose a single env-backed OpenAI config and punt the admin panel to phase 2. Credentials go back to env vars. Saves ~9 ed but loses the "switch from admin panel" story.
3. **Intent-router LLM fallback** (T17 can stay regex-only). Saves 0.5 ed, slight accuracy hit.
4. **LLM-based chat summarizer** (T19) — defer; cap window to 8 turns instead. Loses a layer but works.
5. **10 non-top-3 language prompts** (T58) — ship EN/HI/MR at launch, others later.
6. **Edit-Farm screen** (T43) — ship onboarding only; users can't edit post-completion. Ugly but shippable.
7. **Shadow mode** (T33) — skip; ramp straight via `ai:provider-override` on small cohorts.

## Out-of-scope (explicitly deferred)

- Retrieval-augmented layer over past chats (vector DB).
- Proactive notifications based on weather + crop stage ("rain tomorrow, delay spraying").
- IoT sensor data integration in the prompt tree.
- Admin UI for editing master crop list.
- Per-farmer cost billing/analytics in the user-facing app.

These can each become their own epics once the foundation is live.

## Acceptance criteria (DoD)

A task is done when:
- Code merged to `main`.
- Unit tests ≥ 80% coverage on changed files.
- For backend: staging smoke run green.
- For mobile: QA pass on iOS + Android on latest supported OS.
- For prompts: regression harness unchanged (or improved) on golden queries.
- Dashboards/alerts for the ticket's feature exist where applicable.
- Docs updated in this `plan/krishi-ai/` folder if anything diverges from plan.
