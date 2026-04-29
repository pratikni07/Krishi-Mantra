# 02 — Gaps & Instrumentation Plan

This file enumerates every gap and prescribes the concrete change to close it. The largest body of work; everything below is additive, no rewrites.

## A. Fix the screen-time / screen-exit event mismatch (CRITICAL — 30 min)

**Problem.** Frontend `engagement_service.dart:_trackScreenTime()` emits `eventName: 'screen_time'`. Backend `event.model.js:26-92` enum allows `screen_view` and `screen_exit` but **not** `screen_time`. Mongoose silently rejects with a validation error → user time-on-screen has been silently lost since day one.

**Fix.** Pick one and apply consistently.

**Recommended:** Use `screen_exit` (already in the BE enum) and put duration in `properties.duration`.

Frontend change in `engagement_service.dart::_trackScreenTime()`:
```dart
trackEvent(
  EventName.screenExit,            // add: static const screenExit = 'screen_exit';
  eventCategory: EventCategory.navigation,
  properties: {
    'screenName': _currentScreen,
    'previousScreen': _previousScreen,
    'duration': duration,           // seconds
  },
);
```

Add `EventName.screenExit = 'screen_exit'` constant. Remove the `screen_time` literal everywhere.

**Where to call from:** the observer must trigger `_trackScreenTime` on `didPop` and `didReplace` for the *outgoing* route, not just track the incoming one. The current `engagement_observer.dart` only fires `_trackScreenView` for the previous/new route — it never closes the prior screen-time window. Patch:

```dart
@override
void didPush(Route route, Route? previousRoute) {
  super.didPush(route, previousRoute);
  _engagementService.markScreenExit();   // close previous window
  _engagementService.trackScreenView(_getScreenName(route) ?? 'unknown');
}

@override
void didPop(Route route, Route? previousRoute) {
  super.didPop(route, previousRoute);
  _engagementService.markScreenExit();   // close popped screen's window
  if (previousRoute != null) {
    _engagementService.trackScreenView(_getScreenName(previousRoute) ?? 'unknown');
  }
}
```

`markScreenExit()` is a thin public wrapper around the existing private `_trackScreenTime`. Also call it from `EngagementLifecycleObserver` on `AppLifecycleState.paused` so background-ing the app closes the active window.

**Acceptance:** after one app session, `db.events.countDocuments({ eventName: 'screen_exit' })` is roughly equal to `screen_view` count, and `properties.duration` is non-zero.

## B. Wire the eight unwired controllers

For each controller, add an `EngagementService` reference (or `with EngagementTrackingMixin`) and emit events at the right call sites. Constants are already declared in `engagement_service.dart` for most of these.

### B1. `auth_controller.dart`
- `login()` success → `EventName.userLogin` (category `system`); properties `{ method: 'phone' | 'password' | 'admin' }`. Also call `engagementService.startSession(userId)` after token storage.
- `signupWithPhone()` success → `EventName.userSignup`; properties `{ withImage: bool }`.
- `logout()` → `EventName.userLogout`; then `engagementService.endSession()`.
- Failed login (wrong OTP, account locked) → `EventName.userLogin` with `properties.success = false` and `failureReason`.

### B2. `marketplace_controller.dart`
- Product list opened → `EventName.productView` w/ `contentType: 'product'` and the productId.
- Search submitted → `EventName.productSearch`; properties `{ searchQuery, resultsCount }`.
- Filter applied → `productView` won't capture this; emit a custom `product_filter` event (already in the BE enum at `event.model.js:66`). Add a `productFilter` constant on the FE.
- Add product flow opened → `custom` event `marketplace_create_started`. On success → `marketplace_create_completed`.
- Comment posted on listing → reuse `feed_comment` is wrong; use a custom `marketplace_comment` event. Add to BE enum.
- Contact-seller tap → `EventName.productInquiry` (already declared).

### B3. `crop_controller.dart`
- Crop list opened → `EventName.cropCalendarView`.
- Crop detail opened → `EventName.cropCalendarView` with `contentId: cropId` and `contentType: 'crop'`.
- Activity item tapped → custom event `crop_activity_view` with `properties.activityType`.
- Calendar exported / shared → `crop_share` (custom; add to BE enum).

### B4. `company_controller.dart`
- Company list view → `company_view` (already in BE enum).
- Company detail view → `company_view` with `contentId`.
- Search → `company_search`.
- Contact tap → `company_contact`.

Add the FE constants in the `EventName` class.

### B5. `farm_profile_controller.dart`
- Onboarding step viewed → `screen_view` (covered by observer if routes are named).
- Step completed → custom event `onboarding_step_completed` with `properties.step` (basics/farm/crops/review). Helps measure drop-off.
- Onboarding finish → `onboarding_completed` with `properties.totalSeconds`.
- Profile edit → `EventName.userProfileUpdate`.
- Crop add/remove from farm → custom `farm_crop_added` / `farm_crop_removed`.

Add to BE enum: `onboarding_step_completed`, `onboarding_completed`, `farm_crop_added`, `farm_crop_removed`.

### B6. `disease_detection_controller.dart`
- Image picked → `ai_crop_scan` started.
- Inference returned → `ai_crop_scan` completed; properties `{ resultDisease, confidence, durationMs }`. **Do not log the image bytes** — only diagnostic metadata.
- Failure → same event with `properties.success = false` and `errorCode`.

### B7. `mandi_controller.dart`
- Mandi list opened → custom `mandi_list_view`.
- Search by product or mandi → `search_query` (already in BE enum) with `properties.searchType: 'mandi'`.
- Price-check on a product → custom `mandi_price_check` with `productId`, `mandiId`.

Add to BE enum.

### B8. `subscription_controller.dart`
- Plans screen opened → custom `subscription_plans_view`.
- Plan selected → custom `subscription_plan_selected` with `planName`, `billingCycle`.
- Checkout started → `subscription_checkout_start`.
- Payment confirmed → `subscription_purchase` with `planName`, `billingCycle`, `amount`, `currency`. Server-side equivalent should also fire (defense in depth).
- Cancel flow → `subscription_cancel_start` and `subscription_cancel_confirmed`.
- Resume → `subscription_resume`.

Add all to BE enum.

## C. Consultant tracking — see `03-consultant-analytics.md`

Consultant tracking has its own file because it's the user's primary new requirement and touches both chat and discovery flows.

## D. Backend event-enum updates (one PR)

Add the new event names to `event.model.js` enum. Group:

```js
// Onboarding
'onboarding_step_completed', 'onboarding_completed',
// Farm profile
'farm_crop_added', 'farm_crop_removed',
// Subscription
'subscription_plans_view', 'subscription_plan_selected', 'subscription_checkout_start',
'subscription_purchase', 'subscription_cancel_start', 'subscription_cancel_confirmed', 'subscription_resume',
// Marketplace extras
'marketplace_create_started', 'marketplace_create_completed', 'marketplace_comment',
// Crop calendar extras
'crop_activity_view', 'crop_share',
// Mandi
'mandi_list_view', 'mandi_price_check',
// Disease scan failure variant - same event, properties carry success
// Consultant (see 03-consultant-analytics.md)
'consultant_directory_view', 'consultant_profile_view', 'consultant_chat_request',
'consultant_chat_accepted', 'consultant_chat_completed', 'consultant_rating_submitted',
```

Plus extend the `eventCategory` enum if needed (introduce `consultant` or fold into `communication`/`commerce`).

Single migration: just edit the schema. Time-series collections allow schema changes; existing docs are unaffected.

## E. Sender-side events from backend services (defense in depth)

Frontend events are best-effort — the user can lose connection, the app can crash, the SDK can be circumvented. For business-critical metrics (subscription purchase, consultant requests, ai_image_analyze cost-bearing events), emit a server-side event from the controller that handled the action.

Path: each backend service POSTs to engagement-service `POST /api/engagement/events` (or pushes to the existing RabbitMQ exchange — engagement-service is already wired for it).

- **`message-svc/services/ai.service.js`** after a successful AI completion → emit `ai_message_send` with `properties.tokensUsed`, `model`, `durationMs`.
- **`message-svc/services/message.service.js`** after a successful 1:1 send → emit `chat_message_sent` (server-authoritative, FE-emitted version is opportunistic).
- **`main-service/SubscriptionController.confirmPayment`** after a successful subscription activation → `subscription_purchase` with `planName`, `amount`, `currency`. This is the single source of truth for revenue analytics.
- **`main-service/SubscriptionController.cancelSubscription`** → `subscription_cancel_confirmed`.
- **`main-service` consultant request flow (see file 03)** → `consultant_chat_request`, `consultant_chat_accepted`.

**One helper.** Don't repeat the HTTP call in every service. Add `Backend-JS/<svc>/src/utils/engagementEmitter.js` that takes `{ userId, eventName, eventCategory, properties }` and POSTs to engagement-service with a service-account token (see G below). Each service requires it once.

## F. Bridge existing per-service interaction logs

`feed-service` already logs interactions to its own collection via `/feeds/user/interaction`; `reel-service` does the same via `/reels/interaction`. Two parallel sources of truth.

**Decision:** keep them as feature-internal recommendation signals (they feed the personalization layer) AND emit a parallel engagement-service event so the analytics dashboard sees them.

For each service, after writing the interaction row, additionally call the `engagementEmitter` helper from E. Backfill is not needed — go-forward is sufficient.

## G. Inter-service / SDK auth on engagement endpoints

**Current state:** routes only have `eventRateLimiter`. No auth check. Anyone with the gateway can `POST /api/engagement/events { userId: 'someone-else', eventName: 'app_open' }` and pollute that user's analytics.

**Fix:**
- Frontend SDK does NOT send `userId` in the body. Backend derives `userId` from the JWT (gateway-injected `x-user-id` after JWT verify). Reject if missing.
- Service-to-service emit (E) uses a separate `internalAuth` middleware that requires a `X-Service-Token` header validated against `process.env.INTERNAL_SERVICE_SECRET`. The same pattern is used in `main-service` for `internalAuth` already — copy it.
- Drop any client-supplied `userId` from the body; treat as untrusted.

## H. SDK-level event-name validation (cheap insurance against silent drop)

Add a constant set in `engagement_service.dart` of every valid `eventName`. In `trackEvent`, if `kReleaseMode` is false and the name isn't in the set, log a noisy assertion. Catches typos and stale renames before code review.

Alternatively (preferred): generate `event_names.dart` from a single YAML / JSON file shared by frontend and backend. Single source of truth eliminates drift permanently. See phase plan.

## I. Properties hygiene

Defense against accidental PII leakage and storage bloat:

- Forbid `email`, `phone`, raw image URLs, full lat/long, full message bodies in `properties`.
- Cap `properties.searchQuery` to 200 chars; backend should reject longer.
- Cap entire `properties` JSON to 4 KB; reject larger at the controller.
- Lat/long: round to 2 decimals (~1 km precision) before sending; never log full GPS.

Add a sanitizer pass in the SDK before enqueue and a Joi validator on the backend.

## J. Acceptance checks (per change)

- After A: `screen_view` and `screen_exit` counts are within 5% of each other; `screen_exit.properties.duration` median is plausible (5–60 s).
- After B: each of the 8 controllers fires at least one event in a normal user journey (verify in Mongo: `eventName ∈ { wired set } AND timestamp within last hour`).
- After D: no Mongoose enum errors in engagement-service logs.
- After G: a hand-crafted curl with `userId: 'attacker'` in body cannot pollute another user's analytics.
- After I: a sample 1000-event dump audited for PII shows zero leaks (regex on emails/phones/bearer-tokens).
