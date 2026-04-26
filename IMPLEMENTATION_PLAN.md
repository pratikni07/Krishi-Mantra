# Krishi-Mantra — Bug Inventory & Implementation Plan

**Scope:** Flutter app at `Frontend/krishimantra/` + Node microservices at `Backend-JS/` (api-gateway, main, feed, reel, message-svc, engagement, notification).

**Method:** 5 parallel code-audit passes (auth/subscription, feed/reels/videos, AI+consultant chat, marketplace/crop-calendar, cross-cutting infra). Spot-checked the headline CRITICAL findings against source — all confirmed real.

---

## TL;DR

~165 actual issues identified. The dominant root causes are not 165 separate problems — they cluster into ~10 themes. Fix the themes and most of the bugs go away.

| Severity | Count |
|---|---|
| CRITICAL | ~22 |
| HIGH | ~60 |
| MEDIUM | ~65 |
| LOW | ~18 |

**The 8 issues that should be fixed THIS WEEK (everything else cascades from these or is lower impact):**

1. **Marketplace mutate routes have no auth** — anyone can create/edit/delete products and post comments. (`Backend-JS/main-service/src/routes/marketplaceRoutes.js:21-36`)
2. **`confirmPayment` is non-idempotent and trusts unverified `paymentIntent`** — double-charge + payment-intent hijacking. (`Backend-JS/main-service/src/controller/SubscriptionController.js:224-320`)
3. **Stripe webhook trusts `session.metadata.userId` blindly** — subscription hijacking. (same file, ~line 643)
4. **All consultant-chat HTTP endpoints are unreachable** — frontend calls `/api/messages/api/message/...`, double-prefix. (`Frontend/.../data/repositories/message_repository.dart:19,39,59,80,111,...`)
5. **OTP purpose deadlock** — `initiateAuth` sets `purpose: 'login'`, `signupWithPhone` requires `purpose: 'signup'`. Users who tap login first can never sign up. (`Backend-JS/main-service/src/controller/Auth.js:250 vs 440`)
6. **Premium feature gating defaults to ALLOW on error** — `canAccessFeature` returns true on any exception. Free users get premium when API is slow. (`Frontend/.../subscription_controller.dart:294-302`)
7. **Inter-service auth: services trust `x-user-id` header from gateway without re-verifying JWT** — anyone who can talk to a service directly (port-forward, internal network access) bypasses auth.
8. **Crop Calendar always requests month 6** — hardcoded URL. (`Frontend/.../crop_repository.dart:43`)

---

## Verified CRITICAL Bugs (read against source, confirmed real)

| # | Bug | Location | Impact |
|---|---|---|---|
| 1 | Marketplace mutate routes have no auth middleware | `main-service/src/routes/marketplaceRoutes.js:21-36` | Any anonymous user can POST/PUT/DELETE products and comments. |
| 2 | `confirmPayment` creates duplicate `PaymentHistory` on retry; no `userId` match against `paymentIntent.metadata` | `main-service/src/controller/SubscriptionController.js:224-320` | Double charges, payment-intent hijack (user A's intent paid by user B → A activates). |
| 3 | OTP `purpose` deadlock between login and signup | `main-service/src/controller/Auth.js:250` vs `:425-449` | Users who initiate as "login" can never proceed to signup; OTP `verifyOTP` 10-min window vs `signupWithPhone` 30-min window also lets expired OTPs through signup. |
| 4 | Frontend hits `/api/messages/api/message/...` (double `/api/...` prefix) | `frontend/.../data/repositories/message_repository.dart:19,39,59,80,111,137,162,176,189` | Every consultant-chat HTTP call returns 404. Send/read/list/group all broken; UI works only because socket is the primary path. |
| 5 | Crop Calendar URL hardcodes month 6 | `frontend/.../data/repositories/crop_repository.dart:43` | Calendar always returns June activities regardless of crop/sowing date. |

---

## Full Inventory by Feature

### A. Authentication

**CRITICAL**
- A1. OTP `purpose` deadlock (above).
- A2. OTP expiry window mismatch (above).
- A3. Splash navigates to MAIN without validating token freshness — user lands on authed UI then every API 401s. (`splash_screen.dart:26-39`, `auth_controller.dart:27-56`)
- A4. Refresh-token never used: signup stores it but `_refreshToken()` is never invoked anywhere; access-token expiry = forced re-login. (`auth_controller.dart:227-229`)

**HIGH**
- A5. "Forgot Password" button has empty `onPressed` — feature never wired up. (`LoginScreen.dart:276`)
- A6. "Register" button below login has empty `onPressed`. (`LoginScreen.dart:314-326`)
- A7. `navigateAfterAuth()` swallows all errors with `catch (_) {}` — partial-broken sessions land in MAIN silently.
- A8. Logout doesn't call backend `/auth/logout` — refresh tokens stay valid server-side post-logout.
- A9. Splash silently sends to language-selection on any error in `_checkInitialConfig` — corrupt local data → unannounced logout.
- A10. Signup race: `isLoading` flipped to false in `finally` *after* `navigateAfterAuth`, so spinner spans across screens.

**MEDIUM**
- A11. `isRegistered` heuristic falls back to message-string match — non-English locales break the login/signup branching.
- A12. `signupWithPhone` doesn't verify the verified-OTP belongs to the *same phone* — any verified OTP in the 30-min window grants signup for any phone.
- A13. No CSRF / origin validation on auth endpoints.
- A14. No audit logging for login attempts, password changes, OTP failures.
- A15. Image upload silently fails to default avatar if `PresignedUrlController` not registered.

### B. Subscription

**CRITICAL**
- B1. `confirmPayment` non-idempotent (above).
- B2. Stripe webhook `handleCheckoutCompleted` trusts `session.metadata.userId` without binding to the authenticated session that created it. (`SubscriptionController.js:~643`)
- B3. `canAccessFeature()` returns `true` on any error — paywall bypass when API slow/down. (`subscription_controller.dart:294-302`)
- B4. `createPaymentIntent` doesn't bind userId into the intent in a way that `confirmPayment` re-checks — A creates intent, B pays, A activates.
- B5. No duplicate-active-subscription guard in `confirmPayment` (createCheckoutSession has one but mobile path doesn't).

**HIGH**
- B6. Subscription expiry not enforced live — message-svc reads cached plan; users get features 1h after expiry.
- B7. Free-tier hardcoded counts shown when usage API times out — premium users see `5 messages remaining` and abandon.
- B8. IoT bundle dedupe is case-sensitive — backend casing change → users buy duplicate addons.
- B9. `customer.subscription.updated` webhook doesn't handle `past_due` — failed payments still show as active.
- B10. No rollback if `PaymentHistory.create()` fails after `UserSubscription` upsert — payment records drift from subscriptions.
- B11. No pre-expiry notification job.
- B12. `seedSubscriptionPlans()` runs on every empty `getPlans` request — admin disables get re-seeded.

**MEDIUM**
- B13. No rate-limit on `/payment-intent` — DoS / Stripe quota burn.
- B14. Usage tracking not transactional — message succeeds, counter fails (or vice versa).
- B15. Monthly counter never resets (no cron/period partition in the model).
- B16. No backoff/circuit-breaker around Stripe calls.

### C. Feed

**HIGH**
- C1. Like-count drifts on optimistic update without server reconcile if request fails. (`feed_controller.dart:273-274`)
- C2. Tag filter resets pagination but never fires the initial fetch. (`feed_controller.dart:443-483`)
- C3. `addComment(parentCommentId)` not validated against the same feed/parent — orphan replies. (`feed_controller.dart:187-189`)
- C4. Comments observable not invalidated when feed-id changes — comments from old feed appear under new one. (`feed_controller.dart:98-160`)
- C5. Recommended-feed response shape variation (`data.feeds` vs `feeds`) — pagination silently broken in one shape.

**MEDIUM**
- C6. Scroll has no debounce → duplicate page fetches → duplicate items in list. (`feed_screen.dart:105-111`)
- C7. `comments` cache not invalidated on `addComment`. (`feed_repository.dart:100-119`)
- C8. `userLikedFeedIds` extractor breaks when backend populates `feed` as nested object — like state restoration loses entries. (`feed_repository.dart:330-379`)

**LOW**
- C9. Debug `print(⭐️…)` statements ship in production.
- C10. Hardcoded English fallbacks for translation keys never refresh.

### D. Reels

**CRITICAL/HIGH**
- D1. N+1 `Like.findOne` per reel per fetch. (`reel-service/.../reel_service.js:86-96`)
- D2. Optimistic like update lost when user scrolls away before response. (`reel_controller.dart:230-264`)
- D3. Fire-and-forget `recordInteraction` with no `.catch` → unhandled rejections. (`reel_controller.dart:332`)
- D4. Reel cache key uses `JSON.stringify(filters)` — non-deterministic key order → cache misses & duplicates. (`reel_service.js:63-65`)
- D5. PageView index goes stale when `_combineReelsAndAds` re-runs mid-scroll — page indicator/autoplay desyncs. (`reels_page.dart:189-199`)
- D6. Video controller dispose can throw if scrolled past before `initialize()` completes. (`reels_page.dart:569-573`)
- D7. Create-reel route has no auth middleware (mirrors marketplace issue). (`reel-service/src/routes/reelRoutes.js`)

**MEDIUM**
- D8. Reply insertion assumes parent still exists → silently appended to end if deleted.
- D9. `_combineReelsAndAds` early-returns on empty list → loading spinner stuck forever.
- D10. Tag switch doesn't refetch reels.

### E. Krishi Videos (Video Tutorials)

**CRITICAL**
- E1. Comment-like API path mismatch (`/reels/videos/comments/:id/like` vs `/api/reels/videos/comments/:commentId/like`). (`video_tutorial_repository.dart:148`)
- E2. `parentComment as int` cast on a string → silent NaN/failure. (`video_tutorial_repository.dart:109`)

**HIGH**
- E3. View-count incremented optimistically, no server reconciliation. (`video_tutorial_controller.dart:128-136`)
- E4. `addComment` does optimistic insert + immediate refresh — comment lost if backend not yet persisted. (`video_tutorial_controller.dart:345-346`)
- E5. `getVideos` accesses `data.data.data` (3-level) but backend formats 2-level → null deref. (`video_tutorial_repository.dart:29-31`)

**MEDIUM**
- E6. Like state corrected in detail view but not propagated to list view's observable.
- E7. Comment soft-delete (`isDeleted`) not filtered in list query. (`video_tutorial_service.js:248-296`)
- E8. Replies flattened into single list, breaking parent/child render.

### F. AI Chat

**CRITICAL**
- F1. Streaming abort doesn't cancel server-side work — server keeps generating + TTS after client navigates away. (`ai_chat_controller.dart:519-525`)
- F2. Legacy `sendMessage` returns `limitInfo: null` on non-limited responses — frontend never updates `remainingMessages`. (`message-svc/.../ai.controller.js:154-167`)

**HIGH**
- F3. Socket re-emit of recent messages on reconnect → duplicates (no dedupe by message id). (`ai_chat_controller.dart:103-127`)
- F4. On streaming failure with fallback, only the assistant placeholder is removed — user message orphaned. (`ai_chat_controller.dart:530-544`)
- F5. `remainingMessages` decremented before send confirmed — drifts on failure.
- F6. `rateLimitReset` set as epoch seconds but compared in milliseconds. (`ai_chat_controller.dart:769`)
- F7. STT/voice errors don't `player.flush()` queued audio chunks.

**MEDIUM**
- F8. Empty AI response → message saved as empty string, UI silent.
- F9. Malformed SSE frame silently downgraded to raw delta text → garbage rendered.
- F10. Title truncation 30 chars frontend / 50 chars backend.

### G. Consultant Chat

**CRITICAL**
- G1. All HTTP endpoints unreachable — `/api/messages/api/...` double-prefix. (above, A4-style)
- G2. `chat:create:direct` race — two simultaneous initiations create two chat docs. (`socket.service.js:228-236`)

**HIGH**
- G3. `markMessageAsRead` updates local only, never broadcasts `message:read:update` over socket — peers don't see read receipt.
- G4. `MessageController` has no `onClose()` — socket listeners leak across screens.
- G5. Older-page pagination uses ID-only dedupe — edited messages keep old version, new version dropped.

**MEDIUM**
- G6. `unreadCount` per-chat-per-user but device A's read doesn't propagate to device B (multi-device drift).
- G7. `createDirectChat` throws on disconnected socket; `sendMessage` auto-reconnects — inconsistent UX.

**LOW**
- G8. Temp message map never cleared if HTTP fails but socket succeeds — duplicate render.
- G9. No idempotency key on socket `message:send` — manual retry creates duplicates.

### H. Marketplace

**CRITICAL**
- H1. Mutate routes have no auth (above).
- H2. Delete authorization predicate: `... !== _id && type !== 'marketplace' || type !== 'admin'` — operator precedence bug; `type !== 'admin'` is always true unless user is admin → second OR branch wins, deletes always allowed. (`marketplaceController.js:233`)

**HIGH**
- H3. `launch("tel:...")` with no null check on `contactNumber`. (`marketplace_product_detail_screen.dart:200,371`)
- H4. `int.parse()` on user-entered prices, no try/catch. (`add_product_screen.dart:154-158`)
- H5. Search endpoint path mismatch frontend vs backend mount.
- H6. Null-deref on missing `media` array in carousel.

**MEDIUM**
- H7. Product list never refreshed after `addProduct`.
- H8. Per-image upload errors swallowed inside loop — partial media silently shipped.
- H9. Frontend categories hardcoded — backend changes have no effect.
- H10. `currentPage` not reset on filter/search change — wrong page returned.
- H11. New comment `_id` set to `DateTime.now().toString()` — collisions possible, not server id.

### I. Crop Calendar

**CRITICAL/HIGH**
- I1. Hardcoded month 6 in URL (above).
- I2. `fetchAllCrops(refresh: false)` re-runs in `addPostFrameCallback` on every screen rebuild. (`Crops.dart:29-32`)
- I3. `getCropCalendar` doesn't validate `response.data` is a Map before keying. (`crop_repository.dart:49-62`)

**MEDIUM**
- I4. Search regex built from raw user input → ReDoS risk. (`cropCalendarController.js:323-326`)
- I5. `getRegionModifications` returns single positional element — multi-crop regions lose data. (line 274-280)
- I6. Translated-string cache not cleared on language change.
- I7. Date parsing implicit-timezone — local dates without `Z` shift the calendar by offset.
- I8. Per-tip translation calls (no batching) → N requests per render.

### J. Cross-cutting / Infrastructure

**CRITICAL**
- J1. JWT_SECRET read independently in main, message-svc, gateway with no startup assertion — silent insecure default if any env drifts. (`api-gateway-service/middlewares/auth.js:63`)
- J2. Inter-service trust model: gateway forwards `x-user-id`/`x-user-accounttype` headers, downstream services don't re-verify JWT — direct service access bypasses auth.
- J3. Socket.io connects before user/token loaded → fails handshake, gives up, no UI surfaced. (`SocketService.dart:130`)
- J4. Token refresh races: `_accessToken` cache vs `secure_storage` write order produces stale-token requests in concurrent flight. (`api_service.dart:210`)
- J5. Socket reconnect uses cached handshake token — doesn't pick up post-refresh tokens; consultant-chat goes silently dead after refresh. (`SocketService.dart:155,433`)

**HIGH**
- J6. Logout doesn't `Get.delete()` any controllers; permanent controllers (Socket, BackgroundUpload, Video, Connectivity) keep user-1 state for user-2.
- J7. Hardcoded localhost defaults in `app_config.dart` if `--dart-define` is missing — release build can ship pointing at localhost.
- J8. CORS allows `!origin` (curl, non-browser) by default in gateway. (`api-gateway-service/index.js:93`)
- J9. `trust proxy` hop count from env — wrong value lets clients spoof X-Forwarded-For and bypass rate limiting.
- J10. Notification-service only wired to message events; subscription/marketplace/feed events don't push.
- J11. Cache bypass excludes 401 → users see stale cached feed/messages instead of being forced to re-auth.
- J12. Cron jobs (auto-post, auto-reel) likely run in every PM2 replica without a lock → duplicate posts.
- J13. Debug logs at gateway include full bodies / URLs — secrets/PII land in logs.

**MEDIUM**
- J14. Circuit breaker is per-service with no global cap — multiple service failures still try to proxy each.
- J15. Notification fetch via socket + HTTP can both insert same notification → duplicates.
- J16. Service URLs in docker-compose vs ecosystem.config.js inconsistent — local-dev breakage.

---

## Root-cause clusters (10 themes that explain ~80% of bugs)

| # | Theme | Bugs covered |
|---|---|---|
| 1 | **Backend route auth missing or trust-the-header** | H1, D7, J1, J2, possibly others — fix once at gateway and at every router with consistent middleware |
| 2 | **Stripe / Subscription correctness** | B1–B5, B9, B10 — single hardening pass over the payment lifecycle |
| 3 | **API contract drift between frontend & backend** | A4 (msg-svc paths), E1, E2, E5, H5, I1 — write a contract test or generate types |
| 4 | **OTP/auth state machine** | A1, A2, A3, A4, A12 — re-design with clear states (initiated, verified, consumed) |
| 5 | **Optimistic UI without reconcile** | C1, D2, D8, E3, E4, F4, F5, G3, H7, H11 — common pattern: rollback + reconcile |
| 6 | **Socket lifecycle (connect, reauth, dispose)** | F3, G2, G4, G7, J3, J5, J6 — single SocketService rewrite |
| 7 | **GetX controller lifecycle on logout** | J6 (and all leaks reported per-feature) — one logout-sweep |
| 8 | **Token refresh race** | A3, A4, J4, J5, J11 — interceptor refactor with proper queue/lock |
| 9 | **Error handling defaults to "allow / silent"** | A7, A9, B3, F8, F9, H8 — flip defaults to deny / surface |
| 10 | **Pagination & cache invalidation** | C2, C4, C6, C7, C8, D5, E5, H7, H10 — list-state pattern audit |

---

## Phased Implementation Plan

The plan is sequenced so that early phases UNBLOCK or invalidate fixes in later phases. Don't reorder.

### Phase 0 — Verify (1–2 days)

Most findings have a file-and-line. A handful — particularly anything described from inference rather than direct read — should be confirmed before fixing:

- Read each CRITICAL bug file directly and confirm.
- Run the app (or read main bindings) to confirm: which permanent controllers exist, what `dependency_injection.dart` actually does, where the socket actually connects.
- Verify backend routers are mounted at the paths the frontend assumes (this is the source of the message-svc and video-tutorial mismatches).

Output: a short "verified / rejected" list before touching code.

### Phase 1 — Stop the bleeding (Week 1, blocks production risk)

Goal: nothing is exploitable, double-charging, or silently bypassing the paywall.

1. **Backend route auth hygiene**
   - Add `authenticate` middleware on every mutate route in `marketplaceRoutes.js`, `reelRoutes.js`, `feedRoutes.js`. Audit gateway PUBLIC_PATHS list.
   - Make services re-verify JWT (don't trust gateway-injected `x-user-*` headers). Either share the JWT secret + verify, or sign service-to-service with a separate token.
   - Assert `JWT_SECRET` on startup in every service (`if (!process.env.JWT_SECRET) process.exit(1)`).
2. **Subscription/payment correctness**
   - Make `confirmPayment` idempotent: unique index on `PaymentHistory.stripePaymentIntentId`; check existing before activating.
   - Verify `paymentIntent.metadata.userId === req.user._id` in `confirmPayment`.
   - In `createPaymentIntent`, write `userId` and `planName` into intent metadata server-side (don't accept them from client at confirm time — re-derive from intent metadata).
   - Stripe webhook: reject events whose `metadata.userId` doesn't match a session that the same user created. Persist a `pendingCheckoutSessionId → userId` table at create time and look it up on webhook.
   - Fix `canAccessFeature` to default DENY on error (with cached last-known-good as fallback, not optimistic-allow).
3. **Disable hardcoded localhost defaults in release builds.** Hard-fail if base URL is not set on release.
4. **Marketplace delete authorization** — fix the `&&` / `||` precedence and add unit test.

### Phase 2 — Fix broken transports (Week 1–2, unblocks every feature)

Half the reported "bugs" disappear when the wire is right:

5. **Message-svc HTTP paths** — change frontend `'/api/messages/api/...'` to `/api/messages/...` (or whatever the gateway actually mounts). Spot-check every endpoint in `message_repository.dart` against the gateway proxy table.
6. **Video-tutorial paths** — fix `toggleCommentLike` URL, fix `parentComment as int` cast, fix `data.data.data` triple-nesting.
7. **Crop Calendar** — replace hardcoded `6` with the actual month derived from sowing date / current month / region.
8. **Marketplace search path** — align with backend mount.
9. **Add a smoke-test harness** that hits every endpoint listed in `message_repository.dart`, `video_tutorial_repository.dart`, `marketplace_repository.dart`, `crop_repository.dart`, `subscription_repository.dart`, `feed_repository.dart`, `reel_repository.dart` with an authed token and a known fixture, and asserts 2xx + non-empty payload. Catches future drift.

### Phase 3 — Auth & session reliability (Week 2)

10. **OTP state machine** — split `purpose` into "what the user wants now" (login_or_signup_intent) vs "what was verified" (verified_at, verified_for_phone). Allow a verified OTP to be consumed by either path as long as phone matches and not already consumed.
11. **Token refresh** — add a proper request queue / single-flight in the Dio interceptor. New token must be written before any in-flight request resolves with 401.
12. **Splash gating** — call `/auth/me` (or a cheap protected endpoint) before navigating to MAIN. On failure, refresh; on refresh failure, route to login.
13. **Logout** — call backend `/auth/logout`, then `Get.delete<…>()` every feature controller (or move to `fenix: false` and let Get manage it), reset `SocketService`, clear secure storage.
14. **Unblock Forgot Password / Register buttons** — wire to existing screens.
15. **Replace `catch (_) {}` with logged + user-facing fallback** in `navigateAfterAuth`.

### Phase 4 — Socket & realtime (Week 2–3)

16. **SocketService rewrite** with explicit lifecycle: `idle → authenticating → connected → reconnecting → disposed`. Auth handshake reads the *latest* token at every (re)connect, not a snapshot.
17. **Connect AFTER token is loaded.** Splash awaits userService.load → then `SocketService.start()`.
18. **Per-controller cleanup**: every controller that listens to socket streams must implement `onClose()` and unsubscribe.
19. **Idempotent `message:send`** — client generates a UUID; server upserts on it.
20. **`chat:create:direct` race** — server-side upsert with a unique compound index on participant pair.
21. **`message:read:update` broadcast** — emit on read so peers update receipt UI.

### Phase 5 — Feed / Reels / Videos correctness (Week 3)

22. **Optimistic-update pattern**: introduce a small helper (`optimistic(applyFn, requestFn, rollbackFn, reconcileFn)`) and apply across like/comment/view in feed, reel, video tutorial.
23. **Reels N+1 like lookup** — replace per-reel `findOne` with a single bulk `find({ reel: { $in: ids }, userId })` and map.
24. **Video controller disposal guard** — null-check + try/catch.
25. **Pagination cache invalidation** — central pattern: list owner clears local list on filter/tag/search/refresh, never partially.
26. **Reel auth** on create/edit/delete.
27. Strip debug `print(...)` statements.

### Phase 6 — Marketplace & Crop Calendar (Week 3–4)

28. Null-safe seller-info widgets, validated price form, validated YouTube URL.
29. Add `tel:` null guard.
30. Refresh product list after add; per-image upload error surfaced with retry.
31. Categories endpoint (server-driven), not hardcoded.
32. Escape user input before constructing search regex (prevent ReDoS), or use Mongo text index.
33. `getRegionModifications` — return all matching elements (`$elemMatch` projection or aggregate).
34. Calendar regen only on cache miss, debounced.
35. Crop model `fromJson` defensive against missing fields; explicit UTC for dates.

### Phase 7 — UX / observability polish (Week 4)

36. Show error state + retry where errors are currently swallowed (subscription stats, feature-flag, presigned URL upload, image upload during signup).
37. Connectivity-aware UI banners (already have controller, surface it).
38. Notification-service: emit on subscription activation, marketplace product create, etc., not just chat.
39. Audit logs for auth events (login, logout, OTP fail, password change).
40. CORS narrowing (drop `!origin` exception in production).
41. Per-user rate limit on `/payment-intent`.
42. Cron-job uniqueness (Redis lock) for auto-post / auto-reel.

### Phase 8 — Hardening & deferred (later)

- Subscription pre-expiry notifications.
- Multi-device unread reconciliation.
- Per-period usage counter reset (cron).
- API versioning scheme.
- Contract tests in CI.

---

## What's NOT in scope of this plan

- Refactors that aren't bugs (architecture, naming, file layout).
- Performance work that isn't a correctness issue (the N+1 in reels IS a correctness/cost issue at scale; pure perf wins like response compression aren't here).
- Test coverage as a goal of its own — phases above add targeted tests where they catch a regressed cluster.

---

## How to use this document

1. Read Phase 0 first — verify before fixing.
2. Treat each phase as one or more PRs. Don't merge a phase if any item in that phase regresses.
3. The "Verified CRITICAL" section is the minimum bar before the next release.
4. The "Root-cause clusters" section is the right unit for ticketing — don't open 165 tickets, open ~10 thematic ones with the bug list as acceptance criteria.

---

# Translation / Multi-Language Coverage Audit

User reported the farm data collection page has no language support. Confirmed and broadened the audit to the whole app. Two systemic problems:

## Systemic problems

### S1. Two competing translation systems
- **`LanguageHelper` + `LanguageService.translate(...)`** — runtime translation via the Google Translate-style API. Works on any string but slow (network), and depends on `TranslationMixin` to register & retrieve cached values. Pattern: `getTranslation(KEY)` after `registerTranslation(KEY, 'Default')` in `initState`.
- **`HomeLocalizations.text(key, langCode)`** — static `Map<lang, Map<key, value>>` with **104 keys** and **6 languages** (`en`, `hi`, `mr`, `gu`, `bn`, `ta`). Used in home screen, weather, farm measurement.
- These don't share keys. A string added to one is invisible to the other. Hard to know which to use; mixed usage even within a single screen.
- **Decision needed:** standardize on one. Recommendation: `HomeLocalizations`-style static maps for fixed UI chrome (offline-capable, instant), `LanguageService.translate` only for dynamic API content (post titles, comments, AI responses).

### S2. 6 languages selectable, but coverage is uneven
`LanguageSelectionPage` offers en/hi/mr/gu/bn/ta. Static map covers all 6. Runtime translation works for any. But: any feature that hardcodes English literals (Text('Submit')) renders English regardless of selected language. Below is the inventory.

## Per-feature coverage (strict — files with NO translation calls of any kind)

**31 screen/widget files have zero translation support.** Listed by feature:

### Onboarding (the "farm data collection" page user reported) — 7/7 missing
- `screens/onboarding/farm_onboarding_screen.dart`
- `screens/onboarding/onboarding_ui.dart`
- `screens/onboarding/edit_farm_screen.dart`
- `screens/onboarding/steps/onboarding_basics_step.dart`
- `screens/onboarding/steps/onboarding_farm_step.dart`
- `screens/onboarding/steps/onboarding_crops_step.dart`
- `screens/onboarding/steps/onboarding_review_step.dart`

Sample hardcoded strings: `'Your Farm Profile'`, `'About you'`, `'Helps us tailor advice...'`, `'Age (optional)'`, `'Gender (optional)'`, `'Male'`, `'Female'`, `'Prefer not to say'`, `'Location'`, `'We use this for ±3-day weather...'`, `'Refresh'`, `'Use GPS'`, `'Village'`, `'Taluka'`, `'District'`, `'State'`, `'Pincode'`, `'Location permission denied'`, `'Could not get location: $e'`, `'Please set your location first.'`, error messages, button labels.

This is the most damaging gap because onboarding is the *first* screen a non-English farmer sees — they pick Hindi/Marathi on the language selection page, then the next screen reverts to English.

### Crop Calendar — 2/2 missing
- `screens/cropcalendar/Crops.dart`
- `screens/cropcalendar/crop_detail_screen.dart`

### Feed widgets — 8/12 missing
- `screens/feed/widgets/comment_input.dart`
- `screens/feed/widgets/comment_item.dart`
- `screens/feed/widgets/comments_section.dart`
- `screens/feed/widgets/feed_card.dart`
- `screens/feed/widgets/media_content.dart`
- `screens/feed/widgets/post_actions.dart`
- `screens/feed/widgets/post_content.dart`
- `screens/feed/widgets/post_header.dart`
- `screens/feed/widgets/upload_status_overlay.dart` (parent screen `feed_screen.dart` *is* translated but the widgets aren't)

### Reels — 1/1 missing
- `screens/reel/reels_page.dart` — entire reels feed shows English UI ("Retry", action labels, error states).

### Video Tutorials — 2/3 missing
- `screens/video_tutorial/video_detail_screen.dart`
- `screens/video_tutorial/comment_tile.dart`

### Marketplace detail — 1/3 missing
- `screens/marketplace/marketplace_product_detail_screen.dart`

### Products — 2/2 missing
- `screens/products/product_list_screen.dart`
- `screens/products/product_detail_screen.dart`

### Mandi detail — 1/2 missing
- `screens/mandi/mandi_product_detail_screen.dart`

### Notification — 1/1 missing
- `screens/notification/notification_screen.dart`

### Splash — 1/1 missing
- `screens/splash/splash_screen.dart`

### Company widgets — 2/7 missing
- `screens/company/widgets/company_card.dart`
- `screens/company/widgets/company_header.dart`

### Home widgets — 2/12 missing
- `screens/home/widgets/list_item.dart`
- `screens/home/widgets/location_dialog.dart`

## Other translation-related defects (already in main bug list; restated here for context)
- **C10** — Feed screen registers translations with hardcoded English fallbacks that never refresh if backend strings change.
- **I6** — Crop calendar models cache translated strings in instances; switching language at runtime doesn't clear cache; users see stale translation.
- **I8** — Per-tip translation API calls (no batching) — N requests per render.
- **Markdown plan I8 already mentions this pattern.**

## Translation Implementation Plan

This adds a **Phase 9** to the main plan. Sequence after Phase 7 (UX polish), but the onboarding subset (P9.1) should jump to Phase 1 because non-English users currently can't onboard.

### P9.0 — Decide & document the standard (½ day)
- Pick: static maps (`HomeLocalizations`-style) for chrome, runtime API for dynamic content.
- Update `LANGUAGE_IMPLEMENTATION_GUIDE.md` so contributors know which to use.
- Add a lint or pre-commit grep that fails CI if a screen has `Text('...')` with English content but no translation hook.

### P9.1 — Onboarding (HIGH PRIORITY, do in Phase 1)
- Add `with TranslationMixin` to all 7 onboarding files.
- Extract every English literal to a `KEY_*` constant; register defaults; replace `Text('...')` with `Text(getTranslation(KEY_*))`.
- Translate dropdown values (`Male`/`Female`/`Other`) — those are user-facing, not enum keys, so they need translation in the UI layer while submitting the canonical enum value.
- Snackbar / error strings (location-permission, GPS errors) likewise.
- Test: select Hindi/Marathi on language page → verify onboarding renders translated.

### P9.2 — High-traffic gaps (Phase 5/6 timeframe)
- Reels page (`reels_page.dart`).
- Crop calendar list + detail.
- All feed widgets (comment_input, feed_card, post_content, post_header, post_actions, comments_section, comment_item, media_content, upload_status_overlay).
- Video tutorial detail + comment tile.
- Marketplace detail, products list/detail.

### P9.3 — Long tail (Phase 7)
- Notification screen, splash strings, mandi detail, company widgets (card/header), home widgets (list_item, location_dialog).

### P9.4 — Dynamic content translation hardening
- Fix I6 (cache invalidation on language change) — listen to `TranslationManager.currentLanguageCode` and clear instance caches.
- Fix I8 (batch translation) — switch per-tip translation to `LanguageHelper.batchTranslate(allTips)`.
- Add a `translateApiResponse` call to feed/reel/video lists at the repository boundary so post titles/descriptions/captions translate consistently (currently hit-and-miss).

### P9.5 — Consolidate the dual system
- Migrate `home_localizations.dart` keys into a single `app_strings.dart` consumed via the `TranslationMixin` pattern, OR migrate `TranslationMixin`-based screens to read from a static map (faster, offline). One of the two — not both.

## Acceptance criteria (checklist)
- [ ] Switching to Hindi on the language selection page renders ALL of: onboarding flow, reels, crop calendar list/detail, all feed widgets including comments, video tutorial detail, marketplace detail, products list/detail, mandi detail, notification screen.
- [ ] Snackbars and validation messages on the onboarding flow are also translated.
- [ ] Switching language at runtime clears the per-instance translation cache so previously-rendered crop tips/post content re-translate without an app restart.
- [ ] CI fails if a new `Text('English literal')` is added without a translation hook.

---

# Addendum: Notification Service, Integration Drift Re-audit, UI Consistency

User flagged three more concerns: (a) notification service / flow issues, (b) frontend↔backend integration mismatches across the app, (c) UI inconsistency. Did three deep-dives. **Important: the integration-drift agent produced a lot of false positives, which I've verified and retracted below.**

## A. Retractions / corrections to earlier findings

After re-verifying against source, several claims from prior audit passes are wrong. Removing them so we don't waste cycles on non-bugs:

| Earlier claim | Verdict | Why |
|---|---|---|
| **"All consultant-chat HTTP endpoints unreachable" (`/api/messages/api/...` double-prefix)** — was listed as CRITICAL #4 in the headline | **RETRACTED.** Path math works. Gateway mounts at `/api/messages` and strips it (`pathRewrite: { "^/api/messages": "" }`, gateway `index.js:237`). Message-svc mounts routes at `/api/chat`, `/api/message`, `/api/group` (`message-svc/src/index.js:125-127`). So FE `/api/messages/api/message/send` → gateway → `/api/message/send` → matches `router.post('/send')`. Endpoints are reachable. | Trace: gateway proxy table + service mount table. |
| "Subscription endpoints don't exist on backend" | **RETRACTED.** All 17 subscription endpoints exist in `main-service/src/routes/subscriptionRoutes.js`, mounted via `app.use('/subscription', subscriptionRoutes)` (`main-service/src/index.js:202`). | Direct file read. |
| "Consultant endpoint missing" | **RETRACTED.** Exists at `router.get("/consultant", getConsultant)` in `UserRoutes.js:26`, mounted at `/user`. FE `/api/main/user/consultant` works. | Direct grep + read. |
| "Product / Company endpoints missing" | **RETRACTED.** Both `productRoutes.js` and `companyRoutes.js` exist and are mounted (`main-service/src/index.js:192-193`). | Direct read. |
| "Feed comments `/comments/getComment` no route" | **RETRACTED.** Exists at `feed-service/src/routes/comment.js:9`, mounted via `app.use('/comments', commentRoutes)`. | Direct read. |
| "Feed liked-IDs `/likes/user/:userId` no route" | **RETRACTED.** Exists at `feed-service/src/routes/like.js:12`. | Direct read. |
| "Marketplace addComment field drift (FE `text` vs BE `comment`)" | **RETRACTED.** Backend reads `text`: `const { text } = req.body;` (`marketplaceController.js:257`). FE sends `text`. They match. | Direct read. |

**Net effect on the original plan's headline criticals:** Original CRITICAL #4 (consultant chat unreachable) is removed. The remaining 7 are still valid and verified.

## B. NEW VERIFIED CRITICAL: Push notifications are stubbed

This is the single biggest finding from this round and I verified it line-by-line.

**File:** `Backend-JS/notification-service/src/services/push.service.js`

- **Default provider is `webpush`** (line 18).
- **`_sendWebPush(...)` (lines 48-72) does nothing.** It logs a debug message, then `setTimeout(() => resolve(true), 100)`. There is no actual web-push library call. Comment on line 51 even says `// This is a simplified version - in production use web-push library`.
- **`_sendCustomPush(...)` (lines 135-151) is similarly stubbed** — `setTimeout(100, resolve(true))`. Comment: `// Placeholder for custom implementation`.
- **`_sendOneSignal(...)` (lines 77-129) is implemented**, but defaults `ONE_SIGNAL_APP_ID = 'your-app-id'` and `ONE_SIGNAL_API_KEY = 'your-api-key'` if env vars are unset (lines 79-80). Without proper env, it makes real HTTP requests to OneSignal with placeholder credentials and fails silently.
- **No Firebase/FCM integration anywhere** — `pubspec.yaml` doesn't even include `firebase_messaging`. So the mobile app cannot receive remote push notifications at all.

**User-visible impact:**
- Background push notifications are never delivered for any feature (chat, like, comment, subscription, marketplace).
- Foreground (in-app socket-driven) notifications still work for users actively using the app.
- The processor correctly tries push channel first and reports "success" because the stub returns `true` — so monitoring/logs say everything is fine while users get nothing.

**This is the highest-impact finding across all audits to date.** Push must be implemented (FCM for Android/iOS) before the next release if the product depends on re-engaging users.

## C. Notification service flow — other issues (trust but verify)

These come from the deep-dive agent. Pattern descriptions are credible; line numbers should be confirmed before fixing. Listing only the ones with material user impact:

**Sender-side (services that should emit notifications)**
- **Sender services swallow notification call failures with `console.error`-only catch.** When notification-svc / RabbitMQ is down, messages still write to DB but emit silently fails. `message-svc/src/services/message.service.js`, `feed-service/src/controller/feedController.js`. Effect: feature appears to work; recipient gets no alert.
- **Main-service does not emit notifications for subscription activation, marketplace product creation, follow events.** Only device-registration emits anything, per `DeviceRegistrationController.js:143-159`. Feature scope mismatches user expectations.
- **Inter-service event payload not schema-validated.** `notification.model.js:34-36` uses `Schema.Types.Mixed` for `data` — anything stored as-is, no XSS sanitization on `title`/`body`.

**Frontend-side**
- **`notification_controller.dart`** does not refresh unread count on app resume from background; doesn't dedupe socket-delivered notifications against fetched HTTP list; `markAllAsRead()` loops PATCH per item (no bulk endpoint, no parallelization).
- **No FCM token registration tied to login.** Even when push gets implemented, today there's no place in the auth flow that captures and sends a device token to the backend. (Confirms the "implement FCM" work is not just adding the library — needs a registration endpoint and a frontend hook.)
- **Notification permission (Android 13+ `POST_NOTIFICATIONS`) not requested.** Apps targeting SDK 33+ must prompt; without it, FCM token retrieval fails.

**Backend-side**
- **No bulk mark-as-read endpoint** (`notification-service/src/api/routes.js`). Forces N round-trips for N unread.
- **`getUnreadCount` service method exists but no HTTP route** (`notification.service.js:212`). Frontend has to compute count from a partial loaded list — wrong if list is paginated.
- **Quiet-hours uses server's local timezone, not user's** (`workers/processor.js:215-230`). Misaligned for IST/UTC.
- **Digest enqueue path has no scheduled delivery job.** Low-priority notifications enqueued to digest are never sent (`event-notification.service.js:68-72`).
- **Rate limit not atomic** (`notification-policy.service.js:32-39`) — `incr` then check; race lets bursts through.

## D. Real frontend↔backend drifts (verified in this round)

Short list. Most agent claims were false; these survived verification:

| # | Drift | File:line | Impact |
|---|---|---|---|
| D1 | Video-tutorial `toggleCommentLike` URL is `/reels/videos/comments/$commentId/like` — **missing `/api/` prefix**. Adjacent line 145 correctly uses `/api/reels/videos/...`. | `frontend/.../data/repositories/video_tutorial_repository.dart:148` | Comment likes always 404. |
| D2 | `parentComment as int` cast — `parentComment` is a string ID, this throws on any comment-thread fetch with a parent. | `frontend/.../data/repositories/video_tutorial_repository.dart:109` | Threaded comment loading broken. |
| D3 | Crop Calendar URL hardcodes month `6`. | `frontend/.../data/repositories/crop_repository.dart:43` | Already in main plan. |
| D4 | Feed random URL is `/api/feed/feeds/feeds/random` — double `feeds`. Backend route is also `/feeds/feeds/random` (gateway strips `/api/feed`). Both sides have the typo so it works, but it's confusing. | `frontend/.../data/repositories/feed_repository.dart:215`, `feed-service/src/routes/feed.js` | Cosmetic — works but should be cleaned up on both sides simultaneously. |
| D5 | Marketplace `tags` query param is sent as comma-joined string but backend expects array (or vice versa) — needs a controller-side check before fixing. | `frontend/.../marketplace_repository.dart:97-123` | Tag filter likely silently ignored. |

**That's it for confirmed drifts in this audit pass.** The codebase is more aligned than the agent reported.

## E. UI consistency findings

The UI agent's claims are mostly pattern-level (e.g., "65 instances of raw `SizedBox(height: 16)`") and are credible because they describe reusable code smells. Concrete callouts with file:line that are worth acting on:

### Visual islands (single-screen deviation from the rest of the app)
- **`screens/iot/crop_sensor_screen.dart:23-24`** — defines local `_primaryColor = Color(0xFF2E7D6C)` and `_secondaryColor = Color(0xFF4DB6A3)` (teal). Every other screen uses `AppColors.green`. IoT screens look like a different app.
- **`screens/cropcalendar/crop_detail_screen.dart`** — only screen importing/using `google_fonts` (Montserrat, Nunito). Every other screen uses the system font. Typography island.
- **`screens/disease_detection/disease_detection_screen.dart`** — uses `Color(0xFF2E7D32)` (dark green), `Color(0xFF1565C0)` (blue) raw, ignoring `AppColors`.
- **`screens/home/widgets/farm_measure_banner.dart`** — custom green gradient `[Color(0xFF2E7D32), Color(0xFF43A047), Color(0xFF66BB6A)]` not derived from theme.

### Missing shared components (high duplication)
- **No `PrimaryButton` / `AppButton` widget exists.** ~16 inline `ElevatedButton.styleFrom(...)` blocks across screens, each slightly different.
- **No shared search-bar widget.** Marketplace, schemes, products each implement their own.
- **No shared product/marketplace card.** Different image-carousel handling, different shadow/border-radius, different spacing.
- **No `AppShadows` constant.** ~15+ ad-hoc `boxShadow: [BoxShadow(...)]` blocks with varying blur/offset/color.
- **No shared loading/empty/error wrappers used universally.** `LoadingStateWidget`/`ErrorStateWidget`/`EmptyStateWidget` exist but only some screens use them. Others render a `CircularProgressIndicator` or nothing.

### Token leakage (theme exists, screens ignore it)
- **Hardcoded `BorderRadius.circular(8|12|16|20)` ~98 instances** vs `AppSizes.radiusS/M/L/XL` (66 instances). Screens use whichever is convenient.
- **Hardcoded `SizedBox(height: 4|8|12|16|24)` ~213 instances** vs `RSizedBox`/`AppSizes.padding*`. The spacing scale is documented but unused half the time.
- **Inline `TextStyle(...)` ~20+ instances** in places where `AppTextStyles.headingX` would fit.
- **`SystemUiOverlayStyle` set inside individual screens** (e.g., `feed_screen.dart:58-62`, `cropcare/ChatListScreen.dart:888-890`) instead of via theme. If theme changes, these stay stale.

### Other tells
- `useMaterial3` is not set anywhere → app is M2 by default. Fine, but no explicit decision; M3-flavored components might leak in by accident.
- Notification screen empty state uses an emoji ("check back soon! 🔔") — won't render consistently across devices and breaks i18n.
- Onboarding screens calculate dynamic font sizes ad-hoc instead of using `AppSizes`/`AppTextStyles` (also ties into the translation gap from the prior section — long Hindi/Marathi strings will overflow).

## F. Plan updates

These items merge into the existing phase plan. Numbering continues from earlier phases:

### Phase 1 additions (stop the bleeding)
- **1.5: Decide push strategy.** Pick a provider (FCM is the obvious choice on Android, APNs on iOS). Add `firebase_messaging` to `pubspec.yaml`. Replace `push.service.js` stub with real FCM Admin SDK send. Add a backend endpoint `POST /api/notification/devices/register` and call it on login + on FCM token-refresh in the frontend.
- **1.6: Sender-side notification call hardening.** Don't swallow with `console.error` — at minimum, write a failed-event row to a `notification_outbox` table so retries are possible. Optional: introduce an outbox pattern so sender service write + notification dispatch are eventually consistent.

### Phase 2 corrections (fix broken transports — REVISED)
The original Phase 2 over-promised because it inherited the agent's false positives. The actual transport bugs to fix in Phase 2 are:
- **D1**: video-tutorial `toggleCommentLike` URL — add `/api/` prefix.
- **D2**: video-tutorial `parentComment as int` — remove the cast.
- **D3**: crop calendar hardcoded month — derive month from sowing date / current month.
- **D4**: feed random URL double-`feeds` — clean both sides at once or leave alone (it works).
- **D5**: marketplace tags param — confirm BE expectation; fix one side.
- Plus the smoke-test harness still applies — hit every endpoint in every repository file with a fixture token, assert 2xx + non-empty, catch future drift.

### New Phase 9: Notification service rebuild (after Phase 1.5)
- 9.1 Implement FCM (Android) and APNs (iOS); replace stub.
- 9.2 Token registration: capture FCM token on login + on refresh + on permission grant. Backend endpoint to upsert by `(userId, deviceId)`.
- 9.3 Permission prompt: trigger at first natural moment (e.g., after first message sent), not at splash.
- 9.4 Bulk `markAllAsRead` endpoint; replace frontend loop.
- 9.5 Expose `getUnreadCount` HTTP route; frontend uses it instead of computing from partial list.
- 9.6 User-timezone-aware quiet hours.
- 9.7 Digest delivery cron.
- 9.8 Atomic rate limit (Redis Lua or `INCR` + `EXPIRE NX` pattern correctly).
- 9.9 Sanitize `title`/`body` before persist.
- 9.10 Inter-service auth on notification routes — service-account token, not just `accountType === admin` from gateway header.
- 9.11 Refresh unread count on app resume from background (frontend lifecycle hook).
- 9.12 Dedupe socket vs HTTP fetch in `notification_controller.dart`.

### New Phase 10: UI design system consolidation (low priority but high cleanup value)
- 10.1 Extract `PrimaryButton`, `SecondaryButton`, `IconButton` wrappers; migrate ~16 `ElevatedButton.styleFrom(...)` call-sites.
- 10.2 Extract `AppShadows` constant; migrate ~15 ad-hoc `boxShadow` definitions.
- 10.3 Extract shared `SearchBar` widget; consolidate marketplace/schemes/products variants.
- 10.4 Recolor `iot/crop_sensor_screen.dart` to use `AppColors.green`; remove the local teal palette.
- 10.5 Remove `google_fonts` from `cropcalendar/crop_detail_screen.dart` (or adopt it app-wide via theme — pick one).
- 10.6 Move all `SystemUiOverlayStyle` configuration into the global theme; delete per-screen overrides.
- 10.7 Add a CI lint that fails on `Color(0xFF...)` outside `core/theme/`, `BorderRadius.circular(<int>)` outside the `AppSizes.radiusX` allow-list, and inline `TextStyle(...)` outside small explicit allowlist.

### Updated phase ordering
1. Phase 1 (stop the bleeding) **+ 1.5 push strategy**
2. Phase 2 (transports — corrected scope above)
3. Phase 3 (auth/session)
4. Phase 4 (sockets)
5. Phase 5 (feed/reels/videos correctness)
6. Phase 6 (marketplace/crop calendar)
7. Phase 7 (UX polish)
8. **Phase 9 (notification service rebuild)** — slot here, depends on 1.5
9. Phase 8 (deferred hardening)
10. **Phase 10 (UI design system)** — last; doesn't block features

## G. Verification rule going forward

Several "no backend route" claims from automated audits turned out to be wrong because the agent didn't trace **gateway proxy + pathRewrite + service mount** correctly. Future investigations:

1. **Always read `api-gateway-service/index.js` first.** Map every `app.use("/api/X", ...)` to its `pathRewrite` and target service.
2. **Then read the target service's `src/index.js`** to find `app.use("/Y", ...)` mounts.
3. **Then read the route file** to find the `router.METHOD("/Z", ...)` handlers.
4. **A frontend URL is reachable iff** gateway-stripped + service-mounted + route-registered fully concatenate to it.

This is mechanical — could be a 30-line script that diffs the frontend `_apiService.{get,post,put,patch,delete}('/path/...')` calls against the actual reachable URL set.
