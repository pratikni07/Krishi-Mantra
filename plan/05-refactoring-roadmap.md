# 05 — Refactoring Roadmap

> A phased plan that sequences the fixes from §04 into concrete, shippable chunks. Each phase closes with a definition of done and a demo-able outcome. Items reference the IDs in §04 where applicable.

Rough timeline assumes a 3-engineer team: one full-stack backend, one Flutter, one generalist/DevOps/admin.

---

## Phase 0 — Pre-launch lockdown (week 1, blocks production)

**Goal:** make the system safe to expose to real users, even if still missing features.

### 0.1 Rotate & remove committed secrets
[P0-3] Delete `cricgemini.js`, scrub git history of committed API keys using `git-filter-repo`. Rotate Gemini, data.gov.in, Stripe, Cloudinary, OpenWeather, Twilio. Move every key into `.env` (dev) and a cloud secret manager (prod); add `.env.example` with dummy values. Add `gitleaks` to pre-commit.

**DoD:** `gitleaks detect` clean; no plaintext keys in repo or in `kubectl get secret -o yaml`.

### 0.2 Gateway-issued identity (JWT verification once)
[P0-1, P0-8]
- Add `verifyJwt` middleware in `api-gateway-service/index.js`. On success, compute `{ userId, role, exp }`, serialize, HMAC-sign with a service shared secret (distinct from JWT secret), attach as `X-Krishi-User` header.
- In every downstream service, add `requireSignedIdentity` middleware that verifies the HMAC and populates `req.user`. Reject 401 when missing.
- Remove body-provided `userId` reads from `feedController`, `likeController`, `commentController`, `messageController`, `engagementController`.
- Reject any `req.body.userId` that doesn't match `req.user.id`.

**DoD:** integration test — POST to `/api/feed/feeds/:id/like` with another user's id in the body returns 403.

### 0.3 Socket.io authentication
[P0-2] Require a JWT in `socket.handshake.auth.token`; verify and bind `socket.data.userId`. Ignore any client-supplied userId in every event handler. Add an auth-failure counter.

**DoD:** integration test — a socket connects with a stale/forged token and receives a `connect_error`.

### 0.4 Input validation on all mutating routes
[P0-8] Wire Joi via a `validate(schema)` middleware. Per-endpoint schemas for `feed/createFeed`, `feed/toggleLike`, `feed/addComment`, `message/send`, `engagement/track`, `auth/signup-with-phone`, `auth/verify-otp`, `subscription/checkout`. Reject unknown fields (`stripUnknown: false`).

**DoD:** sending any extra field returns 400 with a detailed error shape.

### 0.5 Flutter config & iOS ATS
[P0-F1, P0-F2] Migrate base URL, Socket URL, Gemini URL, weather key to `flutter_dotenv` + `--dart-define`. Remove `NSAllowsArbitraryLoads`; add a dev-only domain exception gated by build flavor. Remove token `print()`s ([P0-F4]).

**DoD:** release build runs with no hardcoded IP, iOS rejects HTTP calls in release flavor, no tokens in logcat.

### 0.6 MQTT hardening
[P0-4] Switch Mosquitto to password file + per-device credentials issued at handshake; enable TLS on port 8883; ACL so devices can only publish to their own handshake topic and `krishi/sensors/raw`, consumers can only subscribe.

**DoD:** `mosquitto_pub` with wrong creds rejected; external host cannot publish to `krishi/sensors/raw`.

### 0.7 IoT default-deny subscription check
[P0-9] Require `MAIN_SERVICE_API_KEY` unless `IOT_DEV_MODE=true`. Populate the K8s Secret from External Secrets Operator.

**DoD:** iot-parser pod CrashLoopBackOff if API key missing in prod; handshake rejects devices with invalid subscription.

### 0.8 Probes + HPAs
[P0-D2, P0-D3] Every deployment gets livenessProbe + readinessProbe. Commit the referenced `hpa.yaml` files (CPU target 70%) or remove references from `deploy.sh`.

**DoD:** `kubectl rollout restart` on any pod and traffic continues; `kubectl get hpa -n microservices` lists expected HPAs.

**Phase 0 demo:** login flow end-to-end (Flutter → gateway → main); manual attempt to like as another user gets 403; socket connects only with a valid token; dashboards in Grafana show request counts.

---

## Phase 1 — Foundations (weeks 2-4)

**Goal:** bring observability, testing, and correctness to a sane baseline.

### 1.1 Observability stack
[P1-2, P1-3]
- Add `prom-client` to every Node service; expose `/metrics` with default process metrics + `http_requests_total{service,method,route,status}` histogram + a feature counter (e.g. `feeds_created_total`).
- Add OpenTelemetry auto-instrumentation to Node (`@opentelemetry/auto-instrumentations-node`); export OTLP to a Jaeger or Tempo backend.
- Instrument iot-service with `github.com/prometheus/client_golang/prometheus/promhttp` and OTel Go SDK.
- Annotate pods `prometheus_io_scrape: "true"`, `prometheus_io_port: "3002"` etc.
- Ship Grafana dashboards (one "Service overview" per service + one "Edge" with gateway metrics).
- Alertmanager rules for p95 latency > 500ms, 5xx > 1%, queue depth > 10k.

**DoD:** opening Grafana shows per-service graphs with real data; a failing deployment raises an alert within 2 minutes.

### 1.2 CI + test bootstrap
[Testing]
- GitHub Actions workflows: `lint`, `test-backend` (mongodb-memory-server), `test-flutter`, `test-admin`, `build-docker`, `e2e-smoke`.
- Coverage gate: 50% lines per package.
- Seed coverage:
  - Flutter: `AuthController`, `MandiController`, `DiseaseDetectionController`, auth repository, mandi repository, token-refresh lock.
  - main-service: auth flow (signup/OTP/login/refresh), subscription lifecycle, product CRUD.
  - feed-service: `toggleLike` idempotency, input validation.
  - message-svc: socket auth rejection, direct message create/read.
  - engagement: buffer flush, aggregation correctness.
- One Playwright E2E in the admin: login + user list loads.

**DoD:** `main` branch is green; PRs must pass lint+test+coverage.

### 1.3 Dead-letter queues & retries
[P1-1] Declare `dlx-<queueName>` exchanges, set `x-dead-letter-exchange`, message TTL 24h. Add a minimal DLQ admin: a protected `/admin/dlq` page listing counts + first message per queue.

**DoD:** publishing a malformed event lands in the DLQ and is visible in the admin.

### 1.4 Auth hardening
[P1-7, P1-A1, P1-A2]
- Move admin tokens to HTTP-only cookies; add `samesite=strict` + CSRF double-submit.
- Add `role` to JWT claims (`super_admin`, `content_admin`, `marketplace_admin`, `user`, `consultant`).
- Next.js `middleware.ts` on both admin panels enforces role per path.
- main-service rejects requests whose claim role doesn't authorize the endpoint.
- OTP rate limit per phoneNo (5/hour) via rate-limit-redis.

**DoD:** role-gated routes return 403 when accessed with wrong role; OTP flood attempts throttled.

### 1.5 Like uniqueness & counter consistency
[P0-5]
- Unique index `(userId, feed)` on `LikeModel` in feed-service.
- Replace `exists` check with upsert + handle `11000` as idempotent success.
- Wrap count increment in the same operation; use `$inc` with a guard to avoid double-increment when inserting retries.

**DoD:** sending the same `like` twice in parallel leaves exactly one Like document and increments the counter by exactly 1.

### 1.6 Reel transcoding worker
[P0-6]
- Introduce BullMQ with Redis as the queue.
- `transcode-worker` deployment consumes jobs, writes result URLs back to MongoDB, emits `reel:transcode:done` via Socket.io.
- HTTP endpoint returns 202 with `jobId`; status polling endpoint.
- Multer → Cloudinary streamed upload (no disk buffering).

**DoD:** 50 concurrent uploads do not increase API latency; worker autoscales.

### 1.7 Engagement: RAM buffer removal
[P0-7] `POST /events` publishes directly to RabbitMQ. A consumer (batches of 1000 or 1s) inserts into MongoDB. Delete the module-level buffer.

**DoD:** killing `engagement-service` mid-burst causes zero event loss (verified with an ordered producer test).

### 1.8 Notifications: commit to one provider
[P1-6] Pick FCM (recommended): wire Firebase Admin SDK, remove abstract router, implement send + receipt. Wire FCM in Flutter and register device tokens in main-service on login.

**DoD:** test notification delivered to a real device from admin dashboard.

**Phase 1 demo:** Grafana showing request + event metrics, Jaeger trace spanning gateway → feed → notification; a duplicate like is idempotent; a reel upload returns fast and the client sees a transcode-complete push; a push lands on the phone.

---

## Phase 2 — Consolidation & scale (weeks 5-8)

**Goal:** eliminate duplicated code, scale data stores, tighten the mobile app.

### 2.1 Delete duplicated proxy & orphan dirs
[P1-4, P1-5]
- Move Mandi endpoints into main-service as `/mandi/*` with a Redis cache (1h).
- Delete `Backend-JS/api-service/` and `cricgemini.js`.
- Audit `Backend-JS/main-service/notification-service/` + `message-service/` nested folders — port any unique code, delete.
- Collapse `User.js` / `UserRoutes.js` into one file.

**DoD:** repo is missing these files; all clients still work.

### 2.2 Cursor pagination everywhere
[P1-9]
- Message history: `?before=<msgId>&limit=50` returning descending by `_id`.
- Feed listing: `?before=<feedId>&limit=20` with Redis-cached heads.
- Notification list.

**DoD:** scrolling the 10000th message in a chat stays under 100ms p95.

### 2.3 ClickHouse retention & partitioning
[P1-10]
- Recreate tables with `PARTITION BY toYYYYMM(timestamp)` and `TTL timestamp + INTERVAL 1 YEAR`.
- Add materialized views `soil_data_hourly` / `weather_data_hourly` for dashboards.
- Ship dashboard queries that hit the MV, not raw tables.

**DoD:** `SELECT count() FROM soil_data` on 1 year of data returns under 500ms.

### 2.4 Engagement index diet
[P1-11] Drop 4 of the 6 compound indexes, measure write throughput, rebuild aggregation queries to use `{userId, timestamp}` + `DailyMetrics`.

**DoD:** single-node write throughput improves ≥ 30% in a 1-hour load test.

### 2.5 Feed aggregation denormalization
[P1-8] Denormalize `authorName` / `authorPhoto` onto Feed documents, update via a user-change event. Drop lookup joins; show counters only (authoritative via Redis sorted set).

**DoD:** `GET /feeds?page=1` p95 drops below 150ms at 500 RPS.

### 2.6 Shared admin UI package
[P2-A1]
- Set up a pnpm/yarn workspace with `packages/ui`, `packages/schemas`, `apps/admin`, `apps/marketplace-admin`.
- Extract `DataTable<TRow>`, `CrudDrawer<TRow>`, `ConfirmDialog`, `Sidebar`, `MainLayout`.
- Share Zod schemas between front and back via `@krishi/schemas`.
- Replace bespoke CRUD pages with `<Crud entity="users" />` pattern.

**DoD:** both admin panels build off the shared package with no duplicated component code.

### 2.7 Flutter type safety + outbox
[P1-F1, P1-F4]
- `freezed` + `json_serializable` models for every API response.
- Outbox: Hive-persisted queue for POST mutations (like, comment, add-product), replayed on connectivity with idempotency keys.

**DoD:** flipping airplane mode during a like action then re-enabling networks completes the action without duplication.

### 2.8 Flutter refactor passes
[P1-F3, P2-F2]
- Split `home_screen.dart` into sub-widgets + a `HomeController`.
- Enable `prefer_const_constructors` lint and fix violations.
- Add `onClose()` to every controller ([P1-F2]).

**DoD:** `flutter analyze` clean on the repo; `flutter run --profile` shows fewer rebuilds on Home.

### 2.9 Push to production for MSP & mandi
[P1-F5] Expose `/mandi/msp` from main-service (versioned); Flutter fetches on app start and caches. Delete `msp_data.dart`.

**DoD:** updating MSP in admin reflects in the app after cache TTL (1h) or app restart.

**Phase 2 demo:** shared admin UI, a chat with 10k messages scrolls smoothly, a year of sensor data queries fast, home screen is composed of small widgets.

---

## Phase 3 — Scale & polish (weeks 9-12)

### 3.1 Infrastructure hardening
[P1-D1, P1-D2, P1-D3]
- NetworkPolicy default-deny in `microservices` namespace; explicit allow rules.
- Redis Sentinel or ElastiCache; RabbitMQ clustered 3 nodes; MongoDB replica set (or Atlas).
- Resource requests/limits tuned per service based on Phase 1 metrics.
- PodDisruptionBudget for every Deployment.

**DoD:** chaos test killing one RabbitMQ node leaves the system working.

### 3.2 Certificate pinning + WAF
[P2-F3]
- Dio interceptor pins API + CDN cert SHA-256.
- Cloud WAF (AWS WAF / Cloudflare) in front of ingress — OWASP rules + bot rules.

**DoD:** MITM with a non-pinned cert fails; `sqlmap` / `xsstrike` against public endpoints returns 403 from the WAF.

### 3.3 Admin a11y + polish
[P2-A3]
- axe-core CI check on the admin panels, zero violations gate.
- Focus traps on dialogs, skip-to-content, ARIA labels on icon buttons.

### 3.4 Analytics rebuild
[P2-F4]
- Flutter emits domain events to engagement-service via the existing route.
- Engagement writes a materialized daily dashboard read by the admin.
- Cohort retention (D1, D7, D30) and feature adoption tiles in the admin.

### 3.5 Landing page productization
[P2-L1, P2-L2, P3-L1, P3-L2]
- Migrate to Next.js using the shared UI kit.
- Add a waitlist form; wire analytics.
- Translate into hi/mr/gu/bn/ta; route under `/[locale]/*`.

### 3.6 Code-quality cleanup sweep
- Winston redaction, Morgan → structured JSON logs piped to Loki.
- Typedef every shared message contract (`@krishi/contracts`).
- Delete dead code: unused deps (cheerio, geolib), nested orphan services, seed scripts in runtime image, Dockerfile.dev vs Dockerfile consolidation.

**Phase 3 demo:** a chaos-day where a pod is killed, a broker node crashes, a client connection is dropped — user-facing impact is invisible; admin a11y score 100.

---

## Phase 4 — Looking further (backlog)

Not scheduled, but worth capturing:

- **Service mesh (Istio/Linkerd)** for mTLS between services, policy, retries, traffic shaping. Only once scale justifies the ops cost.
- **CQRS / read models** for engagement analytics — separate read DB, continuous projection.
- **Real-time ML** for disease detection via on-device delta updates (federated learning).
- **PWA** for the landing page so farmers can "install" it.
- **Blockchain traceability** — only if farmer demand emerges; extremely easy to overbuild.
- **Voice navigation** via Whisper + Indic TTS for low-literacy users.

---

## Execution notes

- Use one tracker (Linear / Jira) keyed on the IDs in §04 so progress is auditable.
- Every phase lands behind a feature flag where possible; both phones and admin panels get a staged rollout.
- Every phase has a demo deliverable. No phase closes without it, even if items slip.
- Keep Phase 0 small and sharp. It's the only "drop everything" phase; after that, the team should be able to ship a mix of P1/P2 work alongside feature development.
