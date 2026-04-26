# Krishi-Mantra — Today's Action Card + Voice Chat

> Two farmer-first features that together turn the app from "answer when asked" into a daily ritual. Built directly on top of the krishi-ai stack (FarmProfile, WeatherSnapshot, AI provider registry, context tree, push notification service).

This folder is the engineering plan for the next two builds. Both docs are numbered so subteams (backend, mobile, design, data) can pick up their slice independently.

---

## Index

### Build A — Today's Action Card (priority 1)

| # | File | Audience | Covers |
|---|------|----------|--------|
| A01 | [A01-action-card-requirements.md](A01-action-card-requirements.md) | PM, Eng leads | Problem, KPIs, scope, non-goals |
| A02 | [A02-action-card-data-model.md](A02-action-card-data-model.md) | Backend | `ActivityJournal`, `DailyActionCard`, `CropTaskTemplate` schemas |
| A03 | [A03-action-card-recommendation-engine.md](A03-action-card-recommendation-engine.md) | Backend, Agronomist | Rule engine + AI fallback that picks the day's actions |
| A04 | [A04-action-card-backend.md](A04-action-card-backend.md) | Backend | Cron, services, controllers, push wiring |
| A05 | [A05-action-card-frontend.md](A05-action-card-frontend.md) | Mobile | Home card, done flow, journal screen |
| A06 | [A06-action-card-localization.md](A06-action-card-localization.md) | PM, content | Tone, copy templates, dialect handling |
| A07 | [A07-action-card-tasks.md](A07-action-card-tasks.md) | PM, Eng | Sprint-by-sprint task list |

### Build B — Voice Chat (priority 2)

| # | File | Audience | Covers |
|---|------|----------|--------|
| B01 | [B01-voice-chat-requirements.md](B01-voice-chat-requirements.md) | PM | Problem, target users, KPIs, non-goals |
| B02 | [B02-voice-chat-architecture.md](B02-voice-chat-architecture.md) | All eng | STT → AI → TTS pipeline, provider matrix |
| B03 | [B03-voice-chat-backend.md](B03-voice-chat-backend.md) | Backend | Audio upload, STT proxy, TTS streaming |
| B04 | [B04-voice-chat-mobile.md](B04-voice-chat-mobile.md) | Mobile | Hold-to-talk widget, audio player, streaming UX |
| B05 | [B05-voice-chat-cost.md](B05-voice-chat-cost.md) | Backend, Finance | Cost model, per-user caps, abuse mitigation |
| B06 | [B06-voice-chat-tasks.md](B06-voice-chat-tasks.md) | PM, Eng | Sprint plan |

---

## TL;DR — Why these two, why now

### What Indian farmers actually do at 5 AM
1. Walk the field, look at leaves, check the sky.
2. Decide today's action: spray, irrigate, harvest, scout, do nothing.
3. Buy or fetch the input from the local krishi seva kendra.
4. Spray/irrigate/etc. before the sun climbs.
5. Maybe glance at WhatsApp / mandi rates.

### Where the existing app sits in that flow
- Buried 3 taps deep behind a chat textbox.
- Asks for typed input in a script the farmer struggles to type.
- Knows the farmer's crop & weather but doesn't *push* anything.
- Disease detection is a separate screen with no follow-through.

### What changes
- **Build A:** the home screen *opens* on a Today's Action card. Two crops × 1–2 actions each, in the local language, big buttons. "Done", "Skip", "Tell me more". Each tap feeds the activity journal so the next morning's card is smarter.
- **Build B:** the AI chat gains a hold-to-talk button that records, transcribes, streams the AI reply, and *speaks it back*. Marathi/Hindi/etc. native. Removes the keyboard barrier entirely.

### What's NOT in this plan
- New external integrations beyond STT/TTS (no eNAM, no PMFBY auto-claim, no IoT — separate epics).
- A redesigned home screen — we're adding a card to the existing screen, not rewriting it.
- A new AI model — we re-use the active provider via `factory.active()`.

---

## Glossary

| Term | Meaning in this plan |
|------|---------------------|
| **Action card** | The morning home-screen UI showing today's recommended actions per crop. |
| **Action item** | One row on the action card: `(crop, verb, urgency, details, status)`. |
| **Activity journal** | Per-user log of what the farmer actually did (sprayed, irrigated, scouted, skipped, harvested). Becomes a new context-tree layer for the AI. |
| **Crop task template** | Stage- and crop-specific recommended action with a default time window relative to sowing date. Author-once, reusable across users. |
| **Recommendation engine** | Service that combines crop stage + weather + journal + master CropCalendar to pick today's 1–3 action items. |
| **Voice turn** | One STT→AI→TTS round-trip. Billed and rate-limited like a chat turn but heavier. |
| **STT** | Speech-to-text (audio → text). |
| **TTS** | Text-to-speech (text → audio). |

---

## Status & timeline

- **Plan drafted:** 2026-04-25.
- **Build A target:** 2 sprints (4 weeks). Backend ~3 ed, Mobile ~2 ed, content/agronomy ~1 ed, plus QA.
- **Build B target:** 2 sprints (4 weeks). Backend ~3 ed, Mobile ~3 ed, plus voice-quality QA.

Both builds run on top of the existing krishi-ai backend; no new microservices.

See A07 and B06 for the per-ticket breakdowns.
