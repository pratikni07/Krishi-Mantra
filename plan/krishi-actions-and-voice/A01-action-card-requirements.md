# A01 — Today's Action Card: Requirements & Goals

## 1. Problem statement

The current Krishi-Mantra app is **reactive**: it answers questions a farmer types. But the farmer's actual day starts with a question we already have all the data to answer:

> *"What should I do on my farm today?"*

We know the farmer's crops (FarmProfile), the day-since-sowing for each, the local weather (WeatherSnapshot), and the canonical activity calendar per crop (`CropCalendar.Activity` already in the codebase). We have an AI that can phrase recommendations in the farmer's language. We have a push-notification service.

What we **don't** have is the screen that says *"Tomato day 47, fruiting stage. Spray mancozeb 2.5g/L today — no rain forecast. ✓ Done | ⏭ Skip"*.

This plan builds that screen, the engine behind it, and the daily journal that makes it smarter over time.

## 2. Target user

Concrete persona: **Sunita, 38, marginal farmer in Sinnar (Nashik), 1.5 ha mixed cropping (tomato + onion). Speaks Marathi. Phone is a 3-year-old budget Android shared with her son. Wakes at 5 AM, opens the app while drinking morning chai.**

What Sunita needs from the app at 5 AM:
- A 5-second answer to "what's most important today on my farm?"
- The answer phrased like her neighbor would say it, not like a textbook.
- Two-tap acknowledgement: "Done" or "Skip" — no forms, no typing.
- Trust that the recommendation considered today's weather and what she did yesterday.

What Sunita does NOT need at 5 AM:
- A chat interface.
- Navigation through tabs.
- A 200-word essay on early blight pathology.
- Generic "tips of the day" disconnected from her actual crops.

## 3. Success criteria (KPIs)

| KPI | Baseline | Target (90 days post-launch) |
|-----|----------|------------------------------|
| % of DAU who open the action card daily | n/a (new) | ≥ 65% of users with onboarding completed |
| Median time-to-first-tap on home screen | — | < 4 seconds |
| Action items marked "Done" per user per week | 0 | ≥ 6 |
| 7-day retention of users with ≥ 3 action cards completed | n/a | ≥ 55% (vs ~30% today) |
| AI chat sessions started after tapping "Tell me more" | n/a | ≥ 20% of cards |
| Push-notification opt-in rate at signup | ~unknown | ≥ 70% |
| Cost per active user per month | — | < ₹0.50 (~$0.006) for the recommendation pipeline |

## 4. In scope

- **Daily action card on the home screen** (top of `home_screen.dart`).
- **Per-user action items** generated nightly by a cron + on-demand on app open.
- **Activity journal**: every "Done" / "Skip" / "Tell me more" tap is logged.
- **Push notification**: a 7 AM local-time daily nudge for users who opt in.
- **Activity history screen**: scrollable journal of past actions taken.
- **Multi-language copy**: hi, mr, en at launch (matches the krishi-ai prompt set).

## 5. Out of scope (deferred to follow-up epics)

- Voice readout of the action card (handled in Build B).
- Family share / multi-user same-farm (separate epic).
- Linking actions to marketplace input purchases.
- ML-driven personalization beyond the rule + AI engine.
- Calendar/weekly planner view — we ship daily-only first.
- Yield prediction or financial summaries.

## 6. Non-goals (explicit)

- We will **not** generate actions for crops the farmer has never logged. Empty FarmProfile → empty card with a "complete onboarding" nudge.
- We will **not** send notifications without user opt-in.
- We will **not** prescribe specific brand-name pesticides without the farmer's confirmation. Generic actives ("mancozeb", "imidacloprid") only at launch.
- We will **not** override the AI provider switch or context tree. The engine *uses* the active provider but doesn't replace it.

## 7. Constraints

| Constraint | Why |
|-----------|-----|
| Card must render with **zero network calls** if cached | Farmer's morning may be on a flaky 4G/2G hand-off. |
| Backend cron must complete in < 10 min for 100k users | Ops budget; runs on the existing message-svc cluster. |
| Recommendation must work for users with **only 1 crop** and for users with **5+ crops** | Long-tail farmer is rare but real. |
| First card render must work **offline-first** if the user has ever loaded it before | Same flaky-network reality. |
| Per-action-item AI cost ≤ $0.0002 | Otherwise the daily card breaks the cost cap at scale. |

## 8. Why this beats "tips of the day" content

A static tips feed is cheap to build and feels useless within a week. The action card is different because:

- It is **scoped to the farmer's crops** (FarmProfile).
- It **moves with growth stage** (days-since-sowing → CropCalendar lookup).
- It **adapts to weather** ("delay spraying — rain in 36 h").
- It **remembers what was done** (activity journal).
- It is **delivered in the farmer's voice** (re-uses our translated core prompts).

None of those properties are individually new — but combining them daily, automatically, into 1–3 actions is the product.

## 9. Risks & open questions

| Risk | Mitigation |
|------|------------|
| Bad recommendation damages a crop → farmer loses trust | Conservative defaults; always include a safety note; surface "Ask AI" inline on every action. |
| Notification fatigue → uninstalls | Cap at 1 morning push/day + 1 weather-emergency push/day; learn from "Skip" history. |
| Off-season period (no active crops) | Show a "no active crops" state with a CTA to update FarmProfile. |
| User in a niche crop we don't have a calendar for | Fall back to AI-generated action with the same template format. |
| Data quality in `CropCalendar.Activity` is uneven | Phase the rollout: launch with the 10 highest-volume crops where the calendar is good; expand. |
| Farmer doesn't read script well | Build B (voice) addresses this end-to-end; in the meantime keep card copy ≤ 25 words per action. |

## 10. Acceptance criteria (DoD)

A user is considered to have a working action card when:
- The home screen shows an action card on cold open within 1 s if the card was generated in the last 24 h.
- Each action item displays: crop name, action verb, 1-line "why", urgency tag, "Done"/"Skip"/"Tell me more" buttons.
- "Done" persists to the journal and removes the item from today's list (with a green check shown).
- The next-morning card never repeats an item completed in the last 24 h for that crop.
- Tapping "Tell me more" opens the AI chat pre-seeded with the action context.
- The flow works in en/hi/mr at launch with no untranslated strings.
