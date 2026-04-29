# Observability & Engagement Tracking — Plan Index

## Goal

Track every meaningful user action across the Krishi-Mantra app — screen views, time-on-screen, feature interactions, consultant requests, marketplace browsing — and surface the data on the admin panel so product decisions can be made from real interest signals.

## TL;DR — what already exists, what's missing

**This is a gap-closing plan, not a build-from-scratch plan.** Most of the stack is already in place:

| Layer | Status |
|---|---|
| Backend `engagement-service` (Express + Mongo time-series + Redis + RabbitMQ + aggregation worker) | **~95% built** |
| Gateway proxy `/api/engagement` → engagement-service | **Done** |
| Mongo collections: `events`, `sessions`, `userMetrics`, `dailyMetrics` (with 90-day TTL on events) | **Done** |
| Analytics endpoints: dashboard, realtime, engagement, features, content, sessions, screens, hourly, leaderboard, retention, churn | **Done** |
| Frontend `EngagementService` (Flutter, batch + offline queue + session lifecycle) | **Done** |
| Frontend `EngagementNavigatorObserver` (auto screen tracking via GetX) | **Done** |
| Frontend integration: 10 / 18 controllers actually call the SDK | **Partial** |
| Admin panel (`Frontend/admin-panel`, Next.js + Tailwind + Recharts) with an `/analytics` page calling `engagementAPI` | **Skeleton** |
| **Consultant interaction tracking** | **Missing entirely** |
| Screen-exit / time-on-screen events accepted by backend | **Broken** (FE emits `screen_time`; BE enum doesn't include it) |
| Privacy controls (opt-out, retention beyond 90 days, PII redaction) | **Missing** |

So the work is: **(1) close eight unwired controllers, (2) add the consultant flow end-to-end, (3) align FE/BE event names so events stop being rejected, (4) finish the admin dashboards, (5) add privacy controls.**

## File index

| File | Purpose |
|---|---|
| `00-README.md` | This file. |
| `01-current-state.md` | Detailed audit of what's already built (so future readers don't reinvent). |
| `02-gaps-and-instrumentation-plan.md` | Frontend wiring for the 8 unwired controllers + event enum alignment + sender-service hooks. |
| `03-consultant-analytics.md` | User's specific ask: which consultants get more requests; full FE↔BE↔admin design. |
| `04-admin-dashboards.md` | Dashboards to add to the existing admin panel: feature usage, consultant leaderboard, screen-time heatmap, funnels. |
| `05-implementation-phases.md` | Phased rollout, dependencies, ordering, privacy/retention, acceptance criteria. |

## Reading order

1. **`01-current-state.md`** — establish what already exists.
2. **`02-gaps-and-instrumentation-plan.md`** — the largest body of work.
3. **`03-consultant-analytics.md`** — the most-requested new capability.
4. **`04-admin-dashboards.md`** — how product/business sees the data.
5. **`05-implementation-phases.md`** — sequencing.

## Non-goals

- Replacing the engagement-service. It's already fit for purpose.
- Building a third-party analytics integration (Mixpanel, Amplitude). The in-house pipeline is intentional and adequate; revisit only if reporting needs outgrow it.
- Rebuilding the admin panel. Add views to the existing one.
- Per-event ML / personalization. That's a downstream consumer of this data — out of scope here, but the schema is designed not to block it.
