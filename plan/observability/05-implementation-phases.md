# 05 — Implementation Phases & Privacy/Retention

Sequenced rollout. Each phase is one or more PRs. Don't reorder — earlier phases unblock or invalidate later ones.

## Phase 0 — Verify (½ day)

Before writing code, confirm:

1. The current `/api/engagement/events/batch` endpoint is actually reachable from a release build (not just dev). A quick curl with a valid JWT should return 2xx.
2. `db.events.countDocuments({})` over the last 24h shows traffic. If zero, the integration is broken upstream of any new work — fix that first.
3. Check the engagement-service logs for Mongoose enum-validation errors. Frequency tells you how many `screen_time` events have been silently rejected.
4. Sample 100 recent events: confirm `userId` shape matches what other services use (string vs ObjectId-string drift will break joins on the admin side).
5. Confirm the admin panel can authenticate against the gateway and reach `/api/engagement/analytics/dashboard`. If not, that's a separate bug — can't render anything until fixed.

## Phase 1 — Fix what's broken (1 day)

Goal: stop losing events.

- **1.1** Fix the `screen_time` → `screen_exit` mismatch (file `02` section A). Patch the SDK and observer.
- **1.2** Add `internalAuth` middleware on engagement-service event-write routes. Strip user-supplied `userId` from request body; derive from JWT (`x-user-id`).
- **1.3** Add the SDK-level event-name validation set (file `02` section H) with a debug-build assertion.
- **1.4** Add `properties` size limit + PII regex check (file `02` section I) at backend Joi validator.

After Phase 1: existing events stop being silently dropped, attackers can't pollute other users' analytics, and noisy SDK callers get caught in dev.

## Phase 2 — Backend enum + helper (½ day)

- **2.1** Extend `event.model.js` enum with all new event names listed in `02` section D and `03`.
- **2.2** Extend `properties.contentType` enum with `consultant`.
- **2.3** Add `engagementEmitter.js` helper to each backend service that needs server-side emission (`02` section E). One helper, copy-pasted into 3 services.
- **2.4** Wire `internalAuth` into the helper — service-to-service token, NOT a user JWT.

Acceptance: a server-side event from `main-service` lands in `events` collection without errors.

## Phase 3 — Wire eight unwired controllers (2–3 days)

In order of business value:

- **3.1** `auth_controller` (login / signup / logout + session start/end). Highest value — without this, MAU/DAU is wrong.
- **3.2** `subscription_controller` (revenue funnel) + server-side equivalents in `SubscriptionController.confirmPayment` and `cancelSubscription`.
- **3.3** `marketplace_controller` + `company_controller` (commerce signals).
- **3.4** `crop_controller` + `farm_profile_controller` (onboarding funnel + agronomy engagement).
- **3.5** `disease_detection_controller`, `mandi_controller` (the smaller features — verify which are actually used much).

Each sub-step is independent. After each PR, smoke-check by tailing engagement logs while running the app through that flow.

## Phase 4 — Consultant flow end-to-end (2 days)

Per file `03`:

- **4.1** Frontend events at all four discovery/profile/request/outcome moments.
- **4.2** Server-side authoritative `consultant_chat_request` and `consultant_chat_accepted` from `message-svc` chat creation handler.
- **4.3** `consultantRating` model + endpoint (`POST /api/main/consultants/:id/rating`).
- **4.4** New `/api/engagement/analytics/consultants/leaderboard` aggregation endpoint.
- **4.5** Quick join: confirm `User.accountType === 'consultant'` exists; if not, add field + small backfill migration.

## Phase 5 — Bridge per-service interaction logs (1 day)

`feed-service` and `reel-service` already write their own interaction rows. Have those handlers ALSO call the engagement-emitter so the unified `events` collection sees them. Don't migrate the existing collections — they feed personalization. This is purely additive (file `02` section F).

## Phase 6 — Admin dashboards (3–4 days)

Per file `04`:

- **6.1** Realtime pulse on existing `/analytics` page (mostly polish — wrappers exist).
- **6.2** Feature-interest dashboard with `FEATURE_MAP` constant.
- **6.3** Screen-time heatmap.
- **6.4** Retention / churn pages.
- **6.5** Consultant leaderboard on `/consultants`.
- **6.6** Conversion-funnel page (`/analytics/funnels`) with onboarding + consultant funnels.
- **6.7** Per-user drill-down (`/users/:userId/activity`).

Server-side caching layer in front of every analytics endpoint (60 s Redis TTL) should land in 6.0 before any of the dashboards go live — otherwise admin refreshes will pound the time-series collection.

## Phase 7 — Privacy & retention controls (1–2 days)

Today: events expire after 90 days (TTL), but `userMetrics` and `sessions` retain user-linked data forever.

- **7.1** `POST /api/engagement/me/opt-out` — sets a `tracking.optOut` flag on the user. SDK reads this on init (with caching) and short-circuits all `track*` calls. Existing rows are not deleted but no new rows are written.
- **7.2** `POST /api/engagement/me/delete` (user-initiated data deletion, GDPR-style) — deletes `events` + `sessions` + `userMetrics` rows for that userId. Soft-deletes the user's row in `dailyMetrics` aggregates if those carry a userId; otherwise nothing to do.
- **7.3** Auth flow: on `logout`, the SDK ends the session but does NOT clear local `pending_engagement_events` until they're flushed (otherwise we lose the last few events). After flush, clear.
- **7.4** Retention policy on `sessions` and `userMetrics`: keep `sessions` for 180 days, then delete; keep `userMetrics` for 2 years, then anonymize (replace `userId` with a hash, preserve aggregates for cohort analysis). Document in privacy policy.
- **7.5** Audit `properties` for PII exposure once a quarter — automated script that samples 1k recent events and regex-checks for emails/phones/tokens.

## Phase 8 — Single source of truth for event names (later)

Once the codebase has stabilized after Phase 4, eliminate FE/BE drift permanently:

- One YAML file at `/Backend-JS/engagement-service/events.yaml` listing every event name, category, expected properties, retention.
- A codegen step produces:
  - Mongoose enum (consumed by `event.model.js`).
  - Joi validator for the controller.
  - Dart constants (`event_names.dart` + `event_categories.dart`).
  - Markdown reference doc rendered into the admin panel `/docs/events`.

Run codegen in CI; fail the build if any service references an event not in the YAML. This is the long-term insurance that prevents the next round of drift.

## Phase 9 — Optional: streaming pipeline (only if scale demands)

Today: all events go HTTP → MongoDB time-series. Fine for the audited scale (~100k MAU). When traffic crosses ~5M events/day:

- Add a Kafka topic in front of MongoDB; engagement-service writes to Kafka, a separate consumer drains into Mongo + warm aggregations.
- Consider a columnar store (ClickHouse, BigQuery) for the analytics queries; keep Mongo for the live `/realtime` lookups.

Don't pre-build this. Hits diminishing returns until volumes are real.

---

## Dependency graph

```
Phase 0 (verify)
  └─ Phase 1 (fix broken)
       ├─ Phase 2 (enum + helper)
       │    ├─ Phase 3 (wire controllers) ──┐
       │    └─ Phase 4 (consultant flow)    │
       │         └─ Phase 6.5 (consultant dashboard)
       ├─ Phase 5 (bridge interactions)
       └─ Phase 6 (admin dashboards) ───────┘
              └─ Phase 7 (privacy)
                   └─ Phase 8 (codegen, after stable)
                        └─ Phase 9 (Kafka, when scale demands)
```

Phase 3 sub-steps run in parallel with each other but all gate on Phase 2.

## Effort estimate

Single engineer with no prior context on the codebase:

| Phase | Days |
|---|---|
| 0 | 0.5 |
| 1 | 1 |
| 2 | 0.5 |
| 3 | 2.5 |
| 4 | 2 |
| 5 | 1 |
| 6 | 3.5 |
| 7 | 1.5 |
| **Total to ship phases 0–7** | **~12.5 days** |
| 8 | 2 (deferred) |
| 9 | weeks (deferred indefinitely) |

About 2.5 weeks of focused work to get the entire stack — frontend instrumentation, consultant analytics, admin dashboards, privacy controls — to production.

## Acceptance criteria for "we're done"

- [ ] **No silent drops.** `screen_view` and `screen_exit` counts are within 5% of each other; engagement-service shows zero Mongoose enum validation errors over 24 h.
- [ ] **Coverage.** Every controller in `Frontend/krishimantra/lib/presentation/controllers/` fires at least one event during a normal user journey.
- [ ] **Consultant question answered.** Admin can sort consultants by `consultant_chat_request` count last 7d / 30d. Top-5 list is plausible; a sample profile view → request rate matches manual-trace numbers.
- [ ] **Trust the data.** Server-side and frontend-emitted counts for `subscription_purchase` and `consultant_chat_request` agree within 5%. (Larger gap = SDK losing events; investigate.)
- [ ] **Privacy.** Opt-out works end-to-end. Deletion endpoint actually deletes. Sample 1k events shows zero PII leaks.
- [ ] **Decisions land.** Product/business team uses the feature-interest dashboard and consultant leaderboard at least weekly. (Cultural acceptance criterion — not technical, but it's the actual goal.)

## What this plan deliberately does NOT cover

- A/B test infrastructure (separate concern, but the events here can power experiment readouts later).
- Crash reporting (Sentry/Crashlytics — out of scope; complementary not duplicate).
- Performance / APM (server traces, slow query analysis — different observability axis).
- Marketing attribution (UTM/install referrers — handled at app-store / first-launch layer, not in-app event SDK).

These are valid follow-ons; flag them as separate plans when the core engagement work lands.
