# A07 — Today's Action Card: Task Breakdown & Estimates

Concrete tickets grouped by sprint. Estimates in engineer-days (ed) for a mid-level engineer who has read A01–A06. Add 25% buffer for review cycles. Dependencies are explicit.

**Team assumed:** 1 backend (BE), 1 mobile (MO), 0.25 agronomy/content (AG), 0.1 SRE, 0.1 PM/QA. Sprints are 2 weeks.

## Sprint 1 — Foundations (weeks 1–2)

Goal: models in prod, rule engine running on staging, content pipeline live for top-10 crops.

| # | Ticket | Owner | Est (ed) | Depends on |
|---|--------|-------|----------|------------|
| AC01 | `CropTaskTemplate`, `DailyActionCard`, `ActivityJournal` models + indexes + unit tests | BE | 1.5 | — |
| AC02 | Migration `m-A1` — create collections + indexes (idempotent) | BE | 0.5 | AC01 |
| AC03 | Migration `m-A2` — seed templates from `CropCalendar.Activity` (dry-run first) | BE | 1 | AC01 |
| AC04 | Migration `m-A3` — backfill `FarmProfile.notifyPrefs` defaults | BE | 0.5 | — |
| AC05 | Verb glossary (en/hi/mr × 13 verbs) — `verb-glossary.js` | AG + BE | 0.5 | AC01 |
| AC06 | `recommendation.engine.js` — stage detector + template matching + cooldown + scoring | BE | 2 | AC01, AC03 |
| AC07 | `localizer.js` — placeholder substitution + missing-key metric | BE | 0.5 | AC05 |
| AC08 | `card.builder.js` — orchestration + DailyActionCard upsert + Redis write-through | BE | 1 | AC06, AC07 |
| AC09 | Top-10 crop templates curated (en + hi + mr translations + safety notes signed off) | AG | 2 (parallel) | AC05 |
| AC10 | `WeatherSnapshotClient` for main-service (HTTP to message-svc OR shared mongo) | BE | 0.5 | — |
| AC11 | `farm-profile.client` extension: `getActiveCrops(userId)` | BE | 0.25 | — |
| AC12 | Internal AI endpoint on message-svc: `POST /api/ai/internal/chat` + HMAC | BE | 0.5 | — |
| AC13 | `ai-fallback.service.js` — strict-JSON prompt + safe parse + per-user daily cap | BE | 1 | AC08, AC12 |
| AC14 | Smoke fixture: 5 synthetic farmers across 3 stages with weather variants → snapshot test | BE + AG | 1 | AC08 |
| AC15 | Staging deploy + dry-run cron (logs only, no DB write) for 24 h | BE | 0.5 | AC08, AC14 |

**Sprint 1 subtotal:** BE ~9 ed, AG ~2.5 ed.

## Sprint 2 — Cron, API, mobile UI (weeks 3–4)

Goal: full pipeline live in staging, production-ready mobile UI, internal beta to 5 users.

| # | Ticket | Owner | Est (ed) | Depends on |
|---|--------|-------|----------|------------|
| AC16 | `card.cron.js` — 30-min window scheduler + Redis lock + worker pool | BE | 1.5 | AC08 |
| AC17 | Cron progress + Prometheus exporter (`krishi_action_card_*` metrics) | BE | 0.5 | AC16 |
| AC18 | Per-user notify-time scheduling logic (`morningCardLocalTime` honored) | BE | 0.5 | AC16 |
| AC19 | `ActionCardController` — GET /today (Redis-first), GET /history, status mutators | BE | 1.5 | AC08 |
| AC20 | `ActivityJournalController` — list, manual log, by-crop, soft delete | BE | 1 | AC01 |
| AC21 | Pub/sub subscriber: `farm-profile.updated` and `activity.logged` → on-demand regen | BE | 0.5 | AC19 |
| AC22 | Push hook: schedule morning push via existing notification queue + i18n body | BE | 1 | AC18 |
| AC23 | Gateway routes for `/api/action-card/*` and `/api/activity-journal/*` | BE | 0.25 | AC19, AC20 |
| AC24 | Audit endpoint `/api/admin/action-cards/audit` | BE | 0.5 | AC19 |
| AC25 | Mobile: `ActionCard`, `ActionItem`, `ActivityJournalEntry` models | MO | 0.5 | AC19 |
| AC26 | Mobile: `ActionCardRepository` + `ActivityJournalRepository` (incl. ETag) | MO | 0.5 | AC25 |
| AC27 | Mobile: `ActionCardController` w/ optimistic mutation + outbox | MO | 1 | AC26 |
| AC28 | Mobile: `ActionCardWidget` + `ActionItemTile` + urgency styling | MO | 1.5 | AC27 |
| AC29 | Mobile: `EmptyActionCard` states (no profile, no crops, error, offline) | MO | 0.5 | AC28 |
| AC30 | Mobile: home-screen integration — card mounted above weather widget | MO | 0.5 | AC28 |
| AC31 | Mobile: skip-reason bottom sheet + snooze long-press | MO | 0.5 | AC28 |
| AC32 | Mobile: AI chat handoff (`autoSendMessage` arg + chat controller hook) | MO | 0.5 | AC28 |
| AC33 | Mobile: `JournalScreen` + `JournalLogSheet` (manual log) | MO | 1 | AC26 |
| AC34 | Mobile: SharedPreferences cache + offline-first render | MO | 0.5 | AC27 |
| AC35 | Mobile: push-tap deep link → home + scroll-to-card | MO | 0.5 | AC22 |
| AC36 | E2E test (compose stack): seed user → cron → render card → tap done → journal row | BE + MO | 1 | AC30, AC33 |
| AC37 | Internal beta with 5 staff users on staging build | PM | 0.5 | AC36 |

**Sprint 2 subtotal:** BE ~7 ed, MO ~7 ed, PM ~0.5 ed.

## Sprint 3 — Rollout, polish, content (weeks 5–6)

Goal: 100% rollout with morning push, telemetry tuned, content team running steady.

| # | Ticket | Owner | Est (ed) | Depends on |
|---|--------|-------|----------|------------|
| AC38 | Feature flag wiring: `FF_ACTION_CARD_ENABLED` (mobile gate) | BE + MO | 0.25 | AC30 |
| AC39 | Stage 1 (5% cohort) — monitor `done`/`skip` ratio, AI fallback rate, cost | BE + PM | 0.5 (over 3d) | AC37 |
| AC40 | Stage 2 (20%) — push notifications enabled for cohort | BE + PM | 0.5 (over 3d) | AC39 |
| AC41 | Stage 3 (50%) — ramp; expand top-10 to top-15 crops | AG | 1 (parallel) | AC40 |
| AC42 | Stage 4 (100%) — flip default | BE | 0.25 | AC41 |
| AC43 | Tone audit + tweak — review 50 cards across en/hi/mr; iterate `translations` | AG | 1 | AC42 |
| AC44 | "Why this action?" expand row — surface `rationaleTags` as human text | MO | 0.5 | AC30 |
| AC45 | Pull-to-refresh on home triggers `regenerate` | MO | 0.25 | AC27 |
| AC46 | `JournalScreen` filters (crop / verb / week) + photo capture for manual log | MO | 1 | AC33 |
| AC47 | Admin UI: action-card audit page (small Next.js view of `/audit` endpoint) | (admin-FE) | 1 | AC24 |
| AC48 | Admin UI: per-template "skip ratio last 7d" leaderboard (drives content roadmap) | (admin-FE) | 1 | AC17 |
| AC49 | Bengali (bn), Gujarati (gu), Punjabi (pa) launches — translations + reviewer signoff | AG | 2 (parallel) | AC42 |
| AC50 | Mobile: bn/gu/pa string sync + render QA on real devices | MO + QA | 1 | AC49 |
| AC51 | Cron capacity test (k6/script) — 100k synthetic users in < 10 min | BE + SRE | 1 | AC42 |
| AC52 | Post-launch retrospective + KPI review | PM | 0.25 | AC42 |

**Sprint 3 subtotal:** BE ~3 ed, MO ~3 ed, AG ~4 ed, admin-FE ~2 ed, SRE ~0.5 ed, PM ~1.25 ed.

## Summary

| Role | Total ed |
|------|---------|
| Backend (BE) | ~19 |
| Mobile (MO) | ~10 |
| Agronomy / content (AG) | ~6.5 |
| SRE | ~0.5 |
| Admin frontend | ~2 |
| PM / QA | ~2 |

**Timeline:** 3 sprints / 6 weeks from kickoff to 100% rollout. Cron + content curation are the long poles.

## Critical path

1. **AC01–AC03, AC09** (models + seed + content) — unblocks everything.
2. **AC06–AC08** (engine + builder) — gates the cron and the API.
3. **AC16** (cron) — gates push + production traffic.
4. **AC19** (controller) — gates the mobile build.
5. **AC30** (home-screen integration) — gates user-visible launch.

Any slip in this path cascades. Content (AC09) and mobile (AC25-AC34) run in parallel after Sprint 1.

## De-scope options (if running behind)

If we need to ship sooner, drop or defer in order:

1. **Push notifications (AC22, AC35)** — ship card-only at first; push is a follow-up. Saves 1.5 ed.
2. **AI fallback (AC13)** — without it, niche-crop users see fewer items but the rule engine still works. Saves 1.5 ed; lose ~5% of cards.
3. **`JournalScreen` (AC33)** — ship card + done/skip only. The journal is captured on the server; we add the screen later. Saves 1 ed.
4. **Audit + admin UI (AC24, AC47, AC48)** — debugging happens via direct DB queries until we ship the UI. Saves ~2 ed.
5. **bn/gu/pa launches (AC49, AC50)** — ship en/hi/mr first, others next sprint. Saves 3 ed.

## Out-of-scope (explicitly deferred)

- Voice readout of the card — that's Build B.
- Family share — same FarmProfile across multiple phones.
- Calendar/weekly view of upcoming actions.
- Yield + revenue prediction tied to actions.
- Automatic input ordering ("Buy mancozeb at the marketplace") — needs Marketplace deep-link work.
- Action-driven AI chat history threading.
- Per-region template overrides (district-level seasonality).

Each of these can be its own epic post-launch.

## Acceptance criteria (Done = Done)

A ticket is done when:

- Code merged to `main` with passing CI.
- Unit tests on changed files ≥ 80% coverage.
- Backend: staging smoke green; cron dry-run shows no per-user errors.
- Mobile: QA pass on iOS + Android (oldest supported OS) with text scale 1.3×.
- Content: native-reviewer sign-off recorded in the template doc's audit log.
- Telemetry: the new metrics show up on Grafana within 2 hours of deploy.
- Docs in this folder updated if implementation diverges.

## Definition of "ready to ship the feature"

The feature itself is ready for 100% production traffic when:

1. Sprint 1 + Sprint 2 ACs all complete.
2. Stage 3 (50% rollout) ran for 5 days with:
   - Daily-active cards/user ≥ 0.6 in the cohort.
   - "Done"/"Skip" ratio per top-10 verbs > 1.0 (more dones than skips).
   - AI fallback rate < 5%.
   - Cron P95 wall-clock < 10 min.
   - Cost-per-card ≤ $0.0002 averaged over the cohort.
3. PMFBY-style support runbook drafted (what to tell users who report a bad recommendation).
4. Killswitch tested (engaged + disengaged on staging in < 30s).
