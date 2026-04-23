# 04 — Gaps & Improvements

> A prioritized catalogue of concrete defects, gaps, and improvements across every surface. Each item has a location, impact, and recommendation. Use this as the backlog source for §05 roadmap.

Severity legend:
- **P0** — Fix before any production traffic. Security, data loss, or feature-breaking.
- **P1** — Fix in the first sprint after launch. Real user-facing or operational risk.
- **P2** — Pay down over 2-3 sprints. Quality, velocity, and scale.
- **P3** — Nice-to-have; schedule in a cleanup milestone.

---

## 4.1 Backend — Cross-cutting (P0 / P1)

### P0-1 No JWT verification at the API gateway
[Backend-JS/api-gateway-service/index.js](../Backend-JS/api-gateway-service/index.js)

The gateway does not validate tokens. Every downstream service re-implements auth differently, and feed/reel/engagement do not enforce it at all. **Any request that survives the 100 req/15 min rate limit can act as any `userId`.**

*Fix:* Implement a gateway middleware that verifies JWT, resolves `userId` + role into a signed header (`X-User-Id`, `X-User-Role`, HMAC signature), and passes it downstream. Services trust only the signed header and never an unsigned body-provided `userId`.

### P0-2 Socket.io accepts any userId without token verification
[Backend-JS/message-svc/src/services/socket.service.js](../Backend-JS/message-svc/src/services/socket.service.js) — the auth middleware reads `socket.handshake.auth.userId` and calls it done.

*Fix:* Require a JWT in `socket.handshake.auth.token`, verify against `JWT_SECRET`, reject unverified. Bind `socket.data.userId` from the verified claim; ignore body-supplied userIds in every event handler.

### P0-3 Hardcoded API keys committed to source
- [Backend-JS/api-service/cricgemini.js](../Backend-JS/api-service/cricgemini.js) — Gemini key in plain text.
- [Backend-JS/api-service/src/controller/mandiController.js](../Backend-JS/api-service/src/controller/mandiController.js) — data.gov.in key.
- Stripe secrets: verify `.env` is gitignored and rotate if ever committed.

*Fix:* Rotate all three keys immediately, move to `.env` (dev) and K8s `Secret` / external secret manager (prod), add `trufflehog` / `gitleaks` to pre-commit.

### P0-4 MQTT broker anonymous + plaintext
[mosquitto/config/mosquitto.conf](../mosquitto/config/mosquitto.conf) — `allow_anonymous true`, no TLS, no ACL.

*Fix:* Enable `password_file`, create per-device creds at handshake, use `listener 8883` with certificates, add ACL restricting `krishi/sensors/raw` to `publish` only from device users and `krishi/sensors/{soil,weather}` to `subscribe` only for consumer users.

### P0-5 No deduplication / uniqueness on Likes in feed-service
[Backend-JS/feed-service/src/model/LikeModel.js](../Backend-JS/feed-service/src/model/LikeModel.js) has no unique index on `(userId, feed)`. `reel-service/LikeModel` has it; copy the pattern.

*Fix:* Add `likeSchema.index({ userId: 1, feed: 1 }, { unique: true })`, handle `11000` duplicate-key error as idempotent success, drop the application-level "exists" check to avoid the race.

### P0-6 Synchronous FFmpeg in reel-service
[Backend-JS/reel-service/src/controllers/videoUploadController.js](../Backend-JS/reel-service/src/controllers/videoUploadController.js) blocks the Node event loop for every transcode.

*Fix:* Move transcodes to a BullMQ worker backed by Redis (separate deployment), return `202 Accepted` with a `jobId`, push progress via Socket.io or webhook. Stop reading whole files into memory — stream Multer uploads straight to Cloudinary via `upload.pipe()`.

### P0-7 In-memory event buffer in engagement-service loses data on crash
[Backend-JS/engagement-service/src/services/eventService.js](../Backend-JS/engagement-service/src/services/eventService.js)

*Fix:* Push straight to RabbitMQ from the `POST /events` handler; run a consumer that batches into Mongo. Remove the module-level `eventBuffer` entirely, or persist to disk/Redis if latency requires client-side dedupe.

### P0-8 No input validation anywhere
Joi and express-validator are installed but almost no route uses them. `feedController.createFeed`, `likeController.toggleLike`, `messageController.sendMessage`, `engagement POST /events`, subscription endpoints — none validate request bodies.

*Fix:* Add a `validate(schema)` middleware and apply per-route. Reject on unknown fields (`strict: true`). Treat incoming `userId` as untrusted until rejected in favor of the gateway-signed header (see P0-1).

### P0-9 Default-allow subscription gate in iot-service
[iot-service/pkg/api/client.go](../iot-service/pkg/api/client.go) — if `MAIN_SERVICE_API_KEY` is empty, the client silently allows all handshakes. The K8s secret ships empty.

*Fix:* Make API key required in production mode (fail-closed), keep a dev-mode flag (`IOT_DEV_MODE=true`) that logs loudly. Populate K8s secret from an external manager.

---

## 4.2 Backend — Per-service (P1 / P2)

### P1-1 Dead-letter queues missing everywhere
RabbitMQ queues (notifications, batch, event, engagement_events) have no DLX. Poison messages requeue forever.

*Fix:* Declare `x-dead-letter-exchange` on every queue, route to `dead-letter` with TTL; add a simple admin viewer.

### P1-2 Prometheus deployed but no /metrics exported
[deployment/prometheus-configmap.yaml](../deployment/prometheus-configmap.yaml) auto-discovers pods annotated `prometheus_io_scrape: "true"`; no deployment sets the annotation and no Node service exports `/metrics`.

*Fix:* Add `prom-client` to each Node service (default process metrics + a small request-latency histogram + a custom feature counter). Export `expvar`/`promhttp` in Go. Annotate deployments. Ship a Grafana dashboard JSON alongside the Prometheus CM.

### P1-3 No tracing / no correlation ID
Cross-service debugging is impossible.

*Fix:* Add `@opentelemetry/sdk-node` to each Node service, Go OTel SDK in iot-service, OTLP to a Jaeger or Tempo backend. Gateway generates `x-request-id` and propagates `traceparent`.

### P1-4 Duplicate proxy services
`api-service` (port 3000) and `api-gateway-service` (port 3001) both proxy to main/feed/notifications.

*Fix:* Delete `api-service`. Move the Mandi endpoints into a `mandi` route in main-service with a 1-hour Redis cache. Delete `cricgemini.js` — it's not used anywhere.

### P1-5 Nested orphan folders inside main-service
`Backend-JS/main-service/notification-service/` and `Backend-JS/main-service/message-service/` shadow top-level services. Almost certainly leftovers from an earlier structure.

*Fix:* Review git history (who touched last, when), migrate any real code, delete.

### P1-6 Notification-service providers are stubs
Push (Web Push / OneSignal), SMS, and Email senders are scaffolding. Email via Nodemailer is partly wired; push is not.

*Fix:* Either commit to FCM (recommended, free at scale, first-class Flutter) or OneSignal. Remove the abstract "provider router" until there are two providers to route between — premature abstraction is worse than hardcoding.

### P1-7 No CSRF on cookie-auth admin panels
When tokens move to HTTP-only cookies (P0-1 corollary), CSRF becomes real. Add a double-submit cookie or SameSite=Strict + origin check on all mutating routes.

### P1-8 Feed aggregation triple $lookup
[Backend-JS/feed-service/src/controller/feedController.js](../Backend-JS/feed-service/src/controller/feedController.js) — `getCommonAggregationPipeline` joins feeds → users → comments → likes in one pipeline. Fine at 10 feeds, quadratic at 10k.

*Fix:* Denormalize author name/photo onto Feed document; use Redis-cached per-feed counters; paginate before lookups; avoid joining likes, rely on the counter.

### P1-9 Message history pagination uses skip/limit
Breaks above a few thousand messages per chat.

*Fix:* Cursor pagination on `{chatId, _id}` descending with a `?before=<msgId>` query param.

### P1-10 ClickHouse tables grow forever
No TTL, no partitioning, no replication on `soil_data` / `weather_data`.

*Fix:* Add `PARTITION BY toYYYYMM(timestamp)` and `TTL timestamp + INTERVAL 1 YEAR DELETE` (or to a cold-tier table). Consider materialized views for hourly aggregates.

### P1-11 Engagement Event has 6 compound indexes
Write amplification on a collection expected to be the highest-volume table in the system.

*Fix:* Keep only `{userId:1, timestamp:-1}` + the TTL index. Derive the rest from the aggregated `DailyMetrics`.

### P1-12 No rate limiting per user on engagement and notifications
Current limits are per IP, so a single misbehaving client (or NAT'd village) can starve the queue.

*Fix:* Use `rate-limit-redis` keyed on `userId` where known, IP as fallback.

### P1-13 Message-svc rate-limit skip list includes hot endpoints
`/like`, `/comments`, `/interaction`, `/interests` are **excluded** from the upload limiter in reel-service. These are exactly the endpoints that need tighter limits.

*Fix:* Split rate limiters: uploads (1/min), likes/comments (60/min), reads (300/min).

### P1-14 Auto-post scheduler is unauthenticated self-HTTP
[Backend-JS/feed-service/src/utils/autoPostScheduler.js](../Backend-JS/feed-service/src/utils/autoPostScheduler.js) cron posts to its own public `/feeds` endpoint.

*Fix:* Call the service function directly, not over HTTP. Delete the HTTP round-trip; the cron runs in-process anyway.

### P2-1 Ecosystem split-brain: PM2 + Docker + K8s
`ecosystem.config.js` files exist for PM2; Dockerfiles exist; K8s manifests exist. Three operating models for one repo.

*Fix:* Pick one path per environment — K8s for prod, Docker Compose for local — and delete the PM2 config unless staging specifically uses it.

### P2-2 Seed scripts are production-accessible
`seedData.js`, `seedAll.js`, `seedMoreUsers.js`, `createMarketplaceAdmin.js` all live next to production code. Anyone who can `kubectl exec` can reset the DB.

*Fix:* Move into a separate `scripts/` image not included in runtime Dockerfile, or gate behind `ADMIN_SEED_TOKEN`.

### P2-3 Winston no redaction
Log lines include raw request bodies including passwords/OTPs.

*Fix:* Custom formatter that redacts `password`, `otp`, `token`, `authorization`, `stripeCustomerId` by key.

---

## 4.3 Flutter app (P0 / P1 / P2)

### P0-F1 Hardcoded dev host
[lib/core/config/app_config.dart](../Frontend/krishimantra/lib/core/config/app_config.dart) — `_devHost = '192.168.1.46'`.

*Fix:* `flutter_dotenv` + `.env`, checked-in `.env.example`, `--dart-define` for CI builds.

### P0-F2 NSAllowsArbitraryLoads = true
[ios/Runner/Info.plist](../Frontend/krishimantra/ios/Runner/Info.plist)

*Fix:* Remove the blanket allow; use `NSExceptionDomains` only for local dev host, gated by build configuration.

### P0-F3 TFLite model + Gemini key both missing
Disease detection is advertised but doesn't work.

*Fix:*
- Commit the `.tflite` model (or fetch on first launch from a CDN + verify SHA).
- Load Gemini key from backend config endpoint (key never ships in the app binary; backend proxies the call and enforces subscription gating).

### P0-F4 `print` of token prefix in auth_repository
Sensitive data in release logs.

*Fix:* Replace all `print` with `AppLogger` which no-ops in release.

### P1-F1 Untyped JSON everywhere
Repositories return `Map<String, dynamic>` and controllers destructure with `?[]?.toString()`.

*Fix:* Use `json_serializable` / `freezed` for every API response model; fail fast at the parse boundary.

### P1-F2 Missing `onClose()` in controllers
`ConnectivityController`, some feed/reel/message controllers never dispose stream subscriptions.

*Fix:* Audit each controller, override `onClose()` to cancel subscriptions, close `StreamController`s, and unregister observer callbacks.

### P1-F3 God widget home_screen.dart
500+ LOC with API fetches in `initState` and layout mingled.

*Fix:* Extract `HomeServicesGrid`, `HomeTestimonialsCarousel`, `HomeSchemesCarousel`, `HomeHotProducts`, `HomeAdsBanner`. Move fetches to a `HomeController`.

### P1-F4 No offline write queue
Failed POSTs after reconnection are lost.

*Fix:* Outbox pattern: persist pending mutations in Hive, replay on connectivity change with idempotency keys.

### P1-F5 Hardcoded MSP data
[lib/data/msp_data.dart](../Frontend/krishimantra/lib/data/msp_data.dart) — 2025-26 season values baked in.

*Fix:* Serve from `main-service` with version header; cache locally with TTL.

### P1-F6 No push notifications
Notification center is in-app only; daily mandi / weather alerts can't reach users.

*Fix:* Wire FCM in Flutter, register device token in main-service, send via notification-service (which currently stubs push).

### P1-F7 One placeholder test
Real user-visible business logic (disease detection, mandi filter, farm area calculation, token refresh) is completely untested.

*Fix:* Initial coverage targets: 80% for `core/utils` and models, 60% for repositories (mocked Dio), 50% for controllers (mocktail), golden tests for disease card + mandi row. Add CI check on PRs.

### P2-F1 Each translation call individually hits Google Translator
Scale will hit quota fast.

*Fix:* Batch translations in `LanguageHelper`, cache in Hive, fall back to English if translation fails.

### P2-F2 Missing `const` constructors
Small perf win across the app.

*Fix:* Enable `prefer_const_constructors` and `prefer_const_literals_to_create_immutables` in `analysis_options.yaml` and fix warnings.

### P2-F3 No certificate pinning
MITM possible on public Wi-Fi.

*Fix:* Add a Dio interceptor that pins the prod API + CDN cert SHA; refuse mismatch.

### P2-F4 No analytics SDK
Can't measure retention, feature usage, conversion.

*Fix:* Add Firebase Analytics (or PostHog self-hosted), wire the existing engagement-service events through an adapter.

---

## 4.4 Admin panels (P1 / P2)

### P1-A1 Tokens in localStorage
Both admin panels use `localStorage` (`admin_token`, `auth-storage`). XSS = total account takeover.

*Fix:* HTTP-only cookies + CSRF. Login endpoint issues the cookie; Next.js `middleware.ts` reads the cookie for RBAC decisions.

### P1-A2 No RBAC
Any authenticated admin sees every page.

*Fix:* Add a `role` field on admin (`super_admin`, `content_admin`, `marketplace_admin`), gate routes via `middleware.ts`, and enforce server-side (main-service should reject based on the JWT claim).

### P1-A3 No form validation
Dialogs post whatever is typed.

*Fix:* Zod + react-hook-form. Share schemas with the backend by extracting the Zod schemas into a `@krishi/schemas` workspace package.

### P1-A4 No error boundaries
A render exception blanks the admin.

*Fix:* `ErrorBoundary` component wrapping each page; log to Sentry (or Grafana Loki).

### P2-A1 Duplicate CRUD scaffolding
Each entity page rebuilds the same Table + Dialog + Loading + Search.

*Fix:* Extract `DataTable<TRow>` and `CrudDrawer<TRow>` into a shared `@krishi/ui` package. Adopt React Query / SWR so loading/error states are standardized.

### P2-A2 Inconsistent API response shapes
`{success, data}` vs `{count, data, total}` vs bare arrays.

*Fix:* Wrap all controllers in main-service with a `success(data, meta)` / `failure(code, message)` helper that emits one shape.

### P2-A3 Accessibility
No ARIA labels on icon buttons, no focus trap in dialogs, no skip-to-content.

*Fix:* `@axe-core/react` in dev, commit to a single round of remediation per page.

---

## 4.5 Landing page (P2 / P3)

### P2-L1 Placeholder content & images
`og-image.png` missing, stock placeholders for hero/testimonials.

*Fix:* Hire/generate real imagery; fill testimonials with actual quoted farmers (with consent).

### P2-L2 No email capture, no analytics
Can't measure or nurture.

*Fix:* Integrate a simple form → main-service waitlist endpoint; wire GA4 or Plausible.

### P3-L1 No CMS
Content changes require code deploy.

*Fix:* Migrate to Next.js (share design with admin) + MDX or Sanity.

### P3-L2 No Hindi / regional versions
Target audience literally cannot read the site.

*Fix:* Translate into hi/mr/gu/bn/ta and route via `/hi/*` etc.

---

## 4.6 Deployment / Infra (P0 / P1)

### P0-D1 Plaintext secrets in manifests
[deployment/IoT-Service/secret.yaml](../deployment/IoT-Service/secret.yaml) and docker-compose infra credentials (`admin/secure-password`, `guest/guest`) are all plaintext.

*Fix:* Move to External Secrets Operator + AWS Secrets Manager (or SealedSecrets / Bitnami for GitOps). Rotate the committed credentials.

### P0-D2 No liveness / readiness probes
IoT deployments and several Node deployments omit probes. K8s has no way to restart a stuck pod.

*Fix:* Add `GET /health` to every service (already present in several). Configure `livenessProbe` (HTTP /health, 30s) and `readinessProbe` (same, 10s).

### P0-D3 Missing `hpa.yaml` files
`deploy.sh` references `hpa.yaml` per service but those files don't exist in the repo.

*Fix:* Either remove the references or commit HPAs targeting CPU=70%.

### P1-D1 No NetworkPolicy
Any pod can reach any other pod.

*Fix:* Default-deny egress, allow only declared flows (gateway → services, services → Mongo/Redis/RabbitMQ).

### P1-D2 Single-replica infrastructure
Redis, RabbitMQ, Mongo all single-replica.

*Fix:* For stability: Redis Sentinel / managed ElastiCache; RabbitMQ clustered 3 nodes; MongoDB replica set (or managed Atlas).

### P1-D3 Resource limits too tight
IoT pods at 128Mi/256Mi crash on larger payloads. Go runtime + MQTT buffers need more headroom.

*Fix:* 256Mi request / 512Mi limit for IoT parser/consumer; benchmark under 1M messages/day load.

### P1-D4 Ingress has no path-based routing
Everything funnels through the gateway's own routing.

*Fix:* Either keep the gateway as the single edge (current) — but in that case decommission the duplicated `api-service` — or move path routing to the ingress and delete the gateway.

---

## 4.7 Testing (cross-cutting, P1)

Current state:
- iot-service: 12 unit tests.
- Flutter: 1 placeholder widget test.
- Every other service / admin panel: 0 tests.

First-wave coverage targets (conservative, achievable in 3 weeks):
- `main-service`: auth flow (signup → OTP → login → token refresh), subscription lifecycle, product CRUD happy + sad paths. Jest + mongodb-memory-server.
- `feed-service`: like idempotency, create-feed input validation.
- `message-svc`: socket auth, message create/read, group admission.
- `engagement-service`: buffered flush, aggregation worker correctness.
- Flutter: repository tests for auth/feed/reel/mandi (mocked Dio), controller tests for `AuthController`/`MandiController`/`DiseaseDetectionController`, golden test for disease card and mandi row.
- Admin panels: Playwright smoke tests for login + one CRUD per entity.
- E2E: one Playwright script walks app → gateway → main → DB for the phone-OTP login flow.

---

## 4.8 Quick-reference table

| ID | Area | Severity | Description |
|---|---|---|---|
| P0-1 | gateway | P0 | Verify JWT, sign identity header |
| P0-2 | message-svc | P0 | Socket.io token verification |
| P0-3 | api-service | P0 | Rotate & remove committed API keys |
| P0-4 | mosquitto | P0 | Auth + TLS + ACL |
| P0-5 | feed-svc | P0 | Unique index on Like |
| P0-6 | reel-svc | P0 | Move FFmpeg to BullMQ worker |
| P0-7 | engagement | P0 | Eliminate in-memory buffer |
| P0-8 | all backend | P0 | Input validation on every route |
| P0-9 | iot-svc | P0 | Fail-closed on missing API key in prod |
| P0-D1 | infra | P0 | External secrets manager |
| P0-D2 | infra | P0 | Liveness/readiness probes |
| P0-D3 | infra | P0 | HPAs exist or remove references |
| P0-F1 | flutter | P0 | dotenv for config |
| P0-F2 | flutter | P0 | Remove NSAllowsArbitraryLoads |
| P0-F3 | flutter | P0 | Wire disease detection models |
| P0-F4 | flutter | P0 | Remove token prints |
| P1-* | — | P1 | DLQs, tracing, metrics, CSRF, cursor pagination, ClickHouse TTL, push notifications, RBAC, form validation, offline outbox, test coverage |
| P2-* | — | P2 | Duplicate proxy removal, shared UI package, batch translation, a11y, design-system consolidation, analytics |
| P3-* | — | P3 | Landing CMS, i18n for landing, PWA, voice navigation |

The roadmap in §05 sequences these.
