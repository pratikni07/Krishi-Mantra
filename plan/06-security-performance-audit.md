# 06 — Security & Performance Audit

> Audit-style view. Each finding is scored by severity and exploitability, with a recommended remediation. Pair this with §04 (gaps) and §05 (roadmap); this document is the evidence file.

Severity × Exploitability:
- **Critical** — reachable by any authenticated user or the public internet; results in account takeover, data loss, or full compromise.
- **High** — reachable by a motivated attacker with modest knowledge of the API; results in user-level compromise or data leak.
- **Medium** — exploitable under specific conditions or requires insider access.
- **Low** — hardening / defense-in-depth.

---

## 6.1 Security — Authentication & Authorization

### S-01 [Critical] Missing auth enforcement on content services
**Where:** feed-service, reel-service, message-svc (REST), engagement-service, notification-service.
**Evidence:** No auth middleware registered. Controllers read `userId` from `req.body` or `x-user-id` header (e.g. [feed-service/src/controller/likeController.js](../Backend-JS/feed-service/src/controller/likeController.js)).
**Impact:** Any holder of a network path to the service (including the gateway without JWT enforcement) can act as any user.
**PoC:** `curl -X POST https://api/feed/feeds/<id>/like -d '{"userId":"<victim>"}' -H "Content-Type: application/json"`.
**Fix:** Gateway verifies JWT; issues an HMAC-signed `X-Krishi-User` header; downstream services accept only the signed header. See §05 Phase 0.2.

### S-02 [Critical] Socket.io accepts any userId
**Where:** [message-svc/src/services/socket.service.js](../Backend-JS/message-svc/src/services/socket.service.js), auth middleware reads `socket.handshake.auth.userId` only.
**Impact:** Attacker connects as any user, reads every message in every chat the victim is part of, sends messages as the victim.
**PoC:** `io(url, { auth: { userId: "<victim>" } })`.
**Fix:** Require `auth.token` (JWT), verify, bind verified `userId` to `socket.data`. §05 Phase 0.3.

### S-03 [Critical] No JWT verification at the gateway
**Where:** [api-gateway-service/index.js](../Backend-JS/api-gateway-service/index.js).
**Impact:** Broken perimeter. Every downstream service inherits this problem.
**Fix:** Single `verifyJwt` middleware.

### S-04 [High] Weak OTP brute-force protection
**Where:** main-service OTP flow. Max 3 attempts per OTP, but no per-phone-number or per-IP throttle. Global limiter is 100/15 min which is loose at attacker scale.
**Impact:** Attackers rotate 10000 IPs to guess 6-digit OTPs.
**Fix:** Redis-backed rate limiter keyed on phoneNo (5 requests/hour, 10 verify attempts/hour). Exponential lockout after 5 failures.

### S-05 [High] JWT fallback secret in source
**Where:** [main-service/src/controller/Auth.js:22](../Backend-JS/main-service/src/controller/Auth.js) — `process.env.JWT_SECRET || '<default>'`.
**Impact:** Misconfigured env produces predictable tokens that attackers can forge.
**Fix:** Fail-fast on boot if `JWT_SECRET` is missing.

### S-06 [High] Tokens in localStorage (admin panels)
**Where:** admin-panel and marketplace-admin stores (`src/store/auth.store.ts`).
**Impact:** Any XSS steals the token and the attacker becomes super-admin.
**Fix:** HTTP-only cookie + CSRF double-submit; SameSite=Strict; Secure in prod.

### S-07 [High] Admin panel missing RBAC
**Where:** MainLayout checks for a token; nothing checks role. Any admin sees everything, including subscription management and seed endpoints.
**Fix:** Embed `role` in JWT; Next.js `middleware.ts` gates routes; main-service enforces per-endpoint.

### S-08 [Medium] Message-svc REST auth cache-only
**Where:** [message-svc/src/middlewares/auth.middleware.js](../Backend-JS/message-svc/src/middlewares/auth.middleware.js) checks `user:{id}` in Redis without verifying a JWT. Poisoning the cache is enough.
**Fix:** Verify JWT first; use cache only to look up user attributes, never for auth decisions.

### S-09 [Medium] Notification-service user preferences unauthenticated
**Where:** `/api/notifications/*` routes.
**Impact:** Attacker disables another user's notifications (denial of notification).
**Fix:** Identity from signed header; authorize on every preference read/write.

### S-10 [Low] No account lockout / anomaly detection
No concept of "N failed logins locks the account", "login from new geo alerts user".
**Fix:** Track failures in Redis, send alert email/push on suspicious login.

---

## 6.2 Security — Secrets & Transport

### S-11 [Critical] API keys committed to source
**Where:**
- [Backend-JS/api-service/cricgemini.js](../Backend-JS/api-service/cricgemini.js) — Gemini API key.
- [Backend-JS/api-service/src/controller/mandiController.js](../Backend-JS/api-service/src/controller/mandiController.js) — data.gov.in API key.
**Impact:** Quota exhaustion, bill shock, supply-chain impersonation.
**Fix:** Rotate. Scrub git history with `git-filter-repo`. Add `gitleaks` to pre-commit. Move secrets into `.env` + cloud manager.

### S-12 [Critical] Plaintext Kubernetes secrets
**Where:** [deployment/IoT-Service/secret.yaml](../deployment/IoT-Service/secret.yaml) (empty password, but still checked in), docker-compose passwords (`admin/secure-password`, `guest/guest`).
**Fix:** External Secrets Operator → AWS Secrets Manager (or SealedSecrets for GitOps).

### S-13 [Critical] MQTT anonymous + plaintext
**Where:** [mosquitto/config/mosquitto.conf](../mosquitto/config/mosquitto.conf).
**Impact:** Anyone with network access publishes fake sensor data or subscribes to all devices' telemetry.
**Fix:** TLS on 8883, password file with per-device creds, ACL restricting publish/subscribe by topic prefix.

### S-14 [High] ClickHouse password empty in secret
**Where:** `deployment/IoT-Service/secret.yaml`.
**Fix:** Generate a strong password and load from the secret manager.

### S-15 [High] iOS NSAllowsArbitraryLoads = true
**Where:** [Frontend/krishimantra/ios/Runner/Info.plist](../Frontend/krishimantra/ios/Runner/Info.plist).
**Impact:** App accepts HTTP, enabling coffee-shop MITM against farmers.
**Fix:** Remove; use `NSExceptionDomains` only for dev host gated on build flavor.

### S-16 [Medium] No certificate pinning in the Flutter app
**Fix:** Pin API + CDN certs with a Dio interceptor; refuse on mismatch.

### S-17 [Medium] Hardcoded dev host in Flutter
**Where:** [Frontend/krishimantra/lib/core/config/app_config.dart](../Frontend/krishimantra/lib/core/config/app_config.dart).
**Fix:** dotenv / --dart-define.

### S-18 [Low] Ingress cert-manager only for api-gateway
**Where:** [deployment/ingress.yaml](../deployment/ingress.yaml) issues a single Let's Encrypt cert.
**Fix:** Acceptable for now; ensure cert renewal alerts wired to Alertmanager.

---

## 6.3 Security — Input & Output Handling

### S-19 [High] No schema validation on mutating endpoints
**Where:** Every service.
**Impact:** Type confusion, mass assignment, stored XSS via `content`/`description` fields.
**Fix:** Joi/Zod schema per endpoint; reject unknown fields; HTML-escape text on output where rendered as HTML.

### S-20 [High] NoSQL injection in query-param filters
**Where:** feed-service search/filter, marketplace search, engagement analytics. Operators like `{ $regex: req.query.q }` without sanitization.
**PoC:** `?q[$ne]=null` returns all records.
**Fix:** Whitelist operators, coerce to string before building query.

### S-21 [High] Unvalidated file uploads (reel-service, main-service)
No magic-byte check, no MIME whitelist in controllers.
**Impact:** Upload malicious files masquerading as images/videos; rely on downstream (Cloudinary) for protection.
**Fix:** Validate with `file-type` (magic bytes), cap sizes per route, scan with ClamAV in a sidecar for anything > 10MB.

### S-22 [Medium] Unsanitized AI responses shown to users
Flutter renders AI output in-app; if any surface renders HTML (markdown plugin), stored prompt injection leads to XSS.
**Fix:** Render as plain text / safe markdown. Strip HTML tags before storage.

### S-23 [Medium] Open CORS fallback
Several services default to `cors({ origin: true, credentials: true })` when `CORS_ORIGIN` is unset.
**Impact:** Combined with cookie auth, enables cross-site exploitation.
**Fix:** Fail-closed defaults — require an explicit allowed-origins list.

### S-24 [Medium] Unsanitized search parameters in Mandi
State/district/crop params pushed straight to data.gov.in. While upstream is unlikely to be exploitable, a bad actor could use the service as an open proxy against data.gov.in.
**Fix:** Whitelist state/district/commodity values.

### S-25 [Low] Winston logs unredacted
Passwords, OTPs, tokens visible in logs when request bodies are logged.
**Fix:** Custom formatter that redacts by key name.

---

## 6.4 Security — Denial of Service

### S-26 [High] Synchronous FFmpeg transcoding
Single large video blocks the reel-service event loop. One attacker = service unavailable.
**Fix:** Separate BullMQ worker with concurrency and memory limits.

### S-27 [High] Unbounded in-memory event buffer
[engagement-service/src/services/eventService.js](../Backend-JS/engagement-service/src/services/eventService.js) — `eventBuffer` grows when Mongo is slow. OOM kill likely under load.
**Fix:** RabbitMQ-first ingest; no in-process buffer.

### S-28 [Medium] No per-user rate limiting
Limits are per-IP. One user behind CGNAT can exhaust quota for a whole village.
**Fix:** Rate-limit on `userId` (once auth is in place).

### S-29 [Medium] Socket.io auto-joins all chats on connect
O(n) Mongo query per connection. A burst of 10k reconnects hammers Mongo.
**Fix:** Lazy-join on `message:send` / `chat:open`; cache chat IDs in Redis per user.

### S-30 [Low] No API-level request timeout
Slow downstream = slow upstream = backpressure propagation.
**Fix:** `server.setTimeout(30000)` plus explicit per-route timeouts for AI calls.

---

## 6.5 Security — IoT & Data Plane

### S-31 [High] IoT handshake default-allow
[iot-service/pkg/api/client.go](../iot-service/pkg/api/client.go) allows devices if API key isn't configured.
**Impact:** Default deployment never validates subscriptions.
**Fix:** Fail-closed in prod; explicit dev flag.

### S-32 [Medium] Device ID spoofable
Handshake accepts any `device_id` that has a subscription — a second device can present the same ID and receive a session.
**Fix:** Track active sessions per device_id; refuse concurrent handshakes without explicit takeover flow; require device pre-registration with a shared secret.

### S-33 [Low] Sensor validation missing upper bounds
NPK, wind_speed, rainfall have no max.
**Fix:** Add realistic upper bounds; reject outliers.

---

## 6.6 Performance — Latency & Throughput

### P-01 [High] Reel transcoding blocks requests
Moves to the foreground on every upload. Already covered in S-26 (DoS lens) and §05 Phase 1.6.

### P-02 [High] Feed aggregation triple $lookup
3-way join on every feed fetch. Feeds are the home-screen load path.
**Fix:** Denormalize author info; split counters into Redis sorted sets; cap lookup depth.

### P-03 [High] Socket.io auto-join scan
O(n) Mongo query per connection. Every app resume reconnects.
**Fix:** Lazy-join; cache in Redis.

### P-04 [Medium] Skip/limit pagination
Feed, marketplace, messages all use skip/limit. `skip(10000)` is O(n).
**Fix:** Cursor pagination by `_id` / timestamp.

### P-05 [Medium] Missing Lean queries
Many `.find()` calls without `.lean()` in main-service; ~30% response-size tax.
**Fix:** Default to `.lean()` everywhere reads don't need Mongoose docs.

### P-06 [Medium] Populate fan-out on products
`Company.findById().populate('products')` without limit — one company with 10k products = huge response.
**Fix:** Paginate populates or return counts + separate endpoint.

### P-07 [Medium] In-process cron on feed-service
Auto-post cron HTTP-posts to the service's own API every 2 minutes, authenticating as nobody. It serializes with real user traffic.
**Fix:** Direct service-layer call from the cron; not a subject of auth but still a perf waste.

### P-08 [Medium] Engagement Event has 6 compound indexes
Write amplification on the highest-volume table.
**Fix:** Drop 4; derive from DailyMetrics.

### P-09 [Medium] ClickHouse unpartitioned
Full-table reads on a growing table.
**Fix:** `PARTITION BY toYYYYMM(timestamp)`; add materialized views for dashboards.

### P-10 [Low] Single-instance Redis/RabbitMQ/Mongo
Acceptable for early, but every instance is a SPOF.
**Fix:** Replica set / Sentinel / cluster.

---

## 6.7 Performance — Mobile

### P-11 [Medium] God widget rebuilds
home_screen.dart rebuilds on any state change because fetchers live in `initState` and reactive maps wrap the whole tree.
**Fix:** Split into sub-widgets with scoped `Obx`.

### P-12 [Medium] ListView without item extent / caches
Feed, reels, marketplace lists instantiate all items; janky scroll on low-end devices.
**Fix:** Set `itemExtent`/`prototypeItem` where possible; tune `cacheExtent`.

### P-13 [Medium] Unoptimized images
Service icons in PNG/JPG; no WebP. App binary is larger than it needs to be.
**Fix:** Convert to WebP; use `cached_network_image` for remote with explicit `memCacheWidth`.

### P-14 [Medium] Translator API call per string
`LanguageHelper` appears to call Google Translator per string of dynamic content. Quota hit and latency tax.
**Fix:** Batch per-request; cache in Hive keyed on `(text, targetLang)`.

### P-15 [Low] No const constructors
Missing `const` causes needless rebuilds.
**Fix:** Lint `prefer_const_constructors`.

---

## 6.8 Performance — Admin panels

### P-16 [Medium] All pages client-fetched
No SSR or React Query. Every navigation re-fetches from scratch.
**Fix:** React Query / SWR with stale-while-revalidate; or move to Next.js server components for reads.

### P-17 [Medium] Recharts bundle size
Admin ships the whole Recharts library; large on first load.
**Fix:** Dynamic import on analytics page; consider `chart.js` or lighter alternative.

### P-18 [Low] Image optimization
Admin uses `next.config.mjs` with Cloudinary whitelisted; ensure `next/image` is used everywhere (currently mixed).

---

## 6.9 Reliability & Resilience

### R-01 [High] No dead-letter queues
Poison messages requeue forever in RabbitMQ. Bad message = infinite consumer burn.
**Fix:** DLX with TTL; DLQ admin page.

### R-02 [High] No retries or circuit breaker at gateway
A flapping downstream returns 502 directly.
**Fix:** `opossum` circuit breaker per route with retries on idempotent methods.

### R-03 [Medium] No liveness/readiness probes on many deployments
Stuck pods keep receiving traffic.
**Fix:** Add probes to every Deployment.

### R-04 [Medium] IoT consumer write failures drop data
Failed ClickHouse inserts are logged and discarded.
**Fix:** Retry with backoff; fall back to disk queue; send to DLQ after N retries.

### R-05 [Medium] WebSocket in notification-service doesn't scale horizontally
Native `ws` with no Redis adapter — notifications only reach users connected to the same pod.
**Fix:** Switch to Socket.io with `@socket.io/redis-adapter`, or use a proper pub/sub broadcaster like NATS.

### R-06 [Low] No graceful shutdown signals wired to queues
Some services close the DB before draining consumers.
**Fix:** Consumer-first shutdown order; track in-flight messages, stop when drained.

---

## 6.10 Observability gaps that compound risk

- No Prometheus scrapes → no SLO tracking → violations go unnoticed.
- No tracing → incidents take hours to diagnose.
- No Sentry / Loki → mobile and admin exceptions never reach the team.
- No audit log → security incidents are forensically invisible.

Fix by implementing §05 Phase 1.1 in full, with structured JSON logs shipped to Loki and a Sentry DSN wired in every client and server.

---

## 6.11 Summary tables

### Critical (fix before production)

| ID | Area | Finding |
|---|---|---|
| S-01 | Backend | Content services don't enforce auth |
| S-02 | message-svc | Socket.io accepts any userId |
| S-03 | gateway | No JWT verification |
| S-11 | api-service | API keys in source |
| S-12 | k8s | Plaintext secrets |
| S-13 | MQTT | Anonymous + plaintext |

### High

| ID | Area | Finding |
|---|---|---|
| S-04 | main-svc | OTP brute-force protection thin |
| S-05 | main-svc | JWT fallback secret |
| S-06 | admin | localStorage tokens |
| S-07 | admin | No RBAC |
| S-14 | ClickHouse | Empty password |
| S-15 | iOS | NSAllowsArbitraryLoads |
| S-19 | Backend | No input validation |
| S-20 | Backend | NoSQL injection |
| S-21 | Backend | Unvalidated uploads |
| S-26 | reel-svc | Sync FFmpeg DoS |
| S-27 | engagement | Unbounded buffer |
| S-31 | iot | Default-allow handshake |
| P-01 | reel-svc | Transcoding latency |
| P-02 | feed-svc | Aggregation cost |
| P-03 | message-svc | Socket auto-join |
| R-01 | rabbit | No DLQs |
| R-02 | gateway | No retries/breaker |

### Medium & Low

See §6.1–6.10 for the full list; they are the backlog after the Critical and High items clear.
