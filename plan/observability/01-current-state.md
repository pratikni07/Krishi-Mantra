# 01 — Current State of Engagement / Observability

A factual audit. Everything below was confirmed by reading source.

## Backend — `engagement-service`

**Path:** `Backend-JS/engagement-service/src/`

### Models

- **`event.model.js`** — main event log.
  - Time-series collection: `timeField: timestamp`, `metaField: userId`, `granularity: minutes`.
  - Mongo TTL: 90 days (`expireAfterSeconds: 7776000` on `timestamp`).
  - Compound indexes: `(userId, timestamp)`, `(userId, eventName, timestamp)`, `(sessionId, timestamp)`, `(eventName, eventCategory, timestamp)`, `(properties.contentId, eventName)`.
  - Static methods: `getByUser`, `getEventCounts`, `getTimeSeries`.
  - **Enum-validated `eventName`** (~50 names) and `eventCategory` (9 categories). Unknown names get rejected by Mongoose.
  - Properties bag: `contentId`, `contentType`, `screenName`, `previousScreen`, `duration`, `watchDuration`, `completionRate`, `scrollPosition`, `resultPosition`, `searchQuery`, `filterApplied`, `interactionType`, `value`, `metadata`.
  - Device + location enrichment fields.
- **`session.model.js`** — session per device per user. Tracks `screenFlow`, per-session `eventCounts`, device/location, `isActive`, `duration`.
- **`userMetrics.model.js`** — per-user rollup: sessions, activity (incl. streaks), engagement broken down by feeds/reels/products/etc.
- **`dailyMetrics.model.js`** — daily rollup (likely platform-wide and/or per-user; aggregator writes here).

### Routes

Mounted via `Backend-JS/engagement-service/src/routes/index.js`:

**Events** (`eventRoutes.js`):
- `POST /events` — single event
- `POST /events/batch` — batched events (the SDK should use this)
- `POST /sessions/start`
- `POST /sessions/end`
- `POST /sessions/heartbeat`
- `GET /sessions/active/:userId`
- `GET /stats/realtime`

**Analytics** (`analyticsRoutes.js`, behind `analyticsRateLimiter`):
- `GET /analytics/dashboard` (flexible)
- `GET /analytics/dashboard-summary` (legacy)
- `GET /analytics/realtime`
- `GET /analytics/comparison`
- `GET /analytics/engagement`
- `GET /analytics/features`
- `GET /analytics/content`
- `GET /analytics/sessions`
- `GET /analytics/screens`
- `GET /analytics/hourly`
- `GET /analytics/users/:userId`
- `GET /analytics/leaderboard`
- `GET /analytics/retention`
- `GET /analytics/churn`

### Workers / infra

- `aggregationWorker.js` — rolls events into daily/user metrics.
- Redis used for hot counters and rate-limit windows.
- RabbitMQ wired (consumer/producer present), available for cross-service event sourcing.

### Gateway mount

`Backend-JS/api-gateway-service/index.js`:
- L383–386 builds `engagementServiceProxy` with `pathRewrite: { "^/": "/api/engagement/" }`.
- L415: `app.use("/api/engagement", ...engagementServiceProxy)`.
- So a frontend call to `POST /api/engagement/events/batch` reaches the service correctly.

## Frontend — Flutter app

**SDK path:** `Frontend/krishimantra/lib/data/services/engagement_service.dart` (~600 lines, a substantial implementation).

What it does:
- Singleton (`EngagementService()`).
- Constants: `EventCategory` (9), `EventName` (~40), `ScreenName` (~25).
- Session lifecycle: `startSession`, `endSession`, `heartbeat`, `onAppLifecycleChange`.
- Event batching with offline queue persisted under `_pendingEventsKey = 'pending_engagement_events'`. On reconnect, drains the queue.
- Convenience helpers:
  - `trackScreenView(name, properties)`
  - `trackEvent(name, eventCategory, properties)`
  - `trackFeedView`, `trackFeedLike`, `trackProductView`, `trackChatOpen`, `trackAiChatStart`, etc.
- `_trackScreenTime()` computes `DateTime.now().difference(_screenEnteredAt)` in seconds and emits an event named `screen_time` with `properties.duration` and `properties.screenName`.

**Observer:** `Frontend/krishimantra/lib/core/utils/engagement_observer.dart`
- `EngagementNavigatorObserver` extends `NavigatorObserver`, hooked into `MaterialApp.navigatorObservers` in `lib/main.dart:174`.
- Tracks: `didPush`, `didPop`, `didReplace`. Calls `engagementService.trackScreenView(name)` on each.
- `EngagementLifecycleObserver` extends `WidgetsBindingObserver` and forwards `didChangeAppLifecycleState` into the service.
- `EngagementTrackingMixin` for controllers that want to fire events without holding a service reference.

### Wired controllers (10)

Confirmed via grep — these import / use `EngagementService` or its mixin:
- `splash_screen.dart`
- `weather/WeatherScreen.dart`
- `reel_controller.dart`
- `product_controller.dart`
- `notification_controller.dart`
- `message_controller.dart`
- `scheme_controller.dart`
- `feed_controller.dart`
- `video_tutorial_controller.dart`
- `ai_chat_controller.dart`

### NOT wired (8)

- `auth_controller.dart` — no `user_login`/`user_signup`/`user_logout` events fire.
- `marketplace_controller.dart` — no `product_view` / `product_search` / `product_share` from marketplace flow.
- `crop_controller.dart` — crop calendar opens, crop selections.
- `company_controller.dart` — company browse, contact, search.
- `farm_profile_controller.dart` — onboarding completion, profile edits.
- `disease_detection_controller.dart` — `ai_image_analyze` / `ai_crop_scan` not fired.
- `mandi_controller.dart` — mandi browse/search, price-checks.
- `subscription_controller.dart` — plan view, checkout-start, plan-purchase.

## Admin panel — Next.js

**Path:** `Frontend/admin-panel/src/app/`

Existing routes (one `page.tsx` each):
- `analytics/`, `dashboard/`, `users/`, `feeds/`, `reels/`, `videos/`, `products/`, `companies/`, `crop-calendar/`, `subscriptions/`, `notifications/`, `news/`, `schemes/`, `ads/`, `device-registrations/`, `services/`, `auth/`, `settings/`.

**API client:** `Frontend/admin-panel/src/lib/api.ts`
- Has an `engagementApi` axios instance pointed at `${API_BASE}/engagement`.
- `engagementAPI` wrapper exposes: `getDashboard`, `getRealTimeStats`, `getComparison`, `getEngagementBreakdown`, etc. — already calls every analytics endpoint.

**Analytics page:** `analytics/page.tsx` — uses Recharts (`AreaChart`, `BarChart`, `LineChart`, `PieChart`), already imports `engagementAPI`. Skeleton/partially populated.

## What's broken or missing — quick list

1. **Frontend emits `screen_time` event but the backend enum doesn't include it.** Backend has `screen_view` and `screen_exit` only. So every screen-time event gets rejected by Mongoose enum validation. Either (a) emit `screen_exit` with duration in properties, or (b) add `screen_time` to the enum. Pick one.
2. **Eight controllers unwired** (above). Major user actions invisible.
3. **Consultant flow has zero tracking.** No `consultant_*` events in the FE constants, no `consultant_*` in BE enum, no consultant breakdown endpoint, no admin view.
4. **`disease_detection`** events declared (`ai_image_analyze`) but `disease_detection_controller` doesn't call them.
5. **Sender services (feed, reel, message-svc) write their own interaction logs (`/feeds/user/interaction`, `/reels/interaction`)** but don't bridge those to engagement-service. Two parallel sources of truth — risk of drift.
6. **No `event` validation at SDK level** — frontend can emit any string; backend rejects unknown names silently (HTTP 200 or 400 depending on controller). No telemetry on the rejection rate.
7. **Admin analytics page** calls the API but the dashboards for "feature interest", "consultant leaderboard", "screen-time heatmap", and "user journey funnel" aren't built.
8. **Privacy:** no opt-out endpoint, no anonymization on logout, no retention beyond 90-day TTL — fine for events, but `userMetrics` and `sessions` retain user-linked aggregates indefinitely.
9. **Inter-service auth** to engagement-service: routes have `eventRateLimiter`, but anyone who can hit the gateway can post arbitrary events for any `userId` if the SDK passes it in the body without re-derivation from JWT. Needs a check.
