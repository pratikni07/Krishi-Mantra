# 02 — Microservices Deep Dive

> Internals of every Node.js service, the Go IoT plane, and the Mosquitto/ClickHouse substrate.

Table of contents:
- [2.1 api-gateway-service (3001)](#21-api-gateway-service-3001)
- [2.2 api-service (3000)](#22-api-service-3000)
- [2.3 main-service (3002)](#23-main-service-3002)
- [2.4 feed-service (3003)](#24-feed-service-3003)
- [2.5 message-svc (3004)](#25-message-svc-3004)
- [2.6 reel-service (3005)](#26-reel-service-3005)
- [2.7 notification-service (3006)](#27-notification-service-3006)
- [2.8 engagement-service (3007)](#28-engagement-service-3007)
- [2.9 iot-service (Go)](#29-iot-service-go)
- [2.10 Cross-service concerns](#210-cross-service-concerns)

---

## 2.1 api-gateway-service (3001)

**File:** [Backend-JS/api-gateway-service/index.js](../Backend-JS/api-gateway-service/index.js)

A thin Express reverse proxy using `http-proxy-middleware` v3.

**Routing table**

| Prefix | Forwards to | Notes |
|---|---|---|
| `/api/main/*` | main-service :3002 | `^/api/main` rewritten to `` |
| `/api/messages/*` | message-svc :3004 | `^/api/messages` → `` |
| `/api/feed/*` | feed-service :3003 | `^/api/feed` → `` |
| `/api/reels/*` | reel-service :3005 | Prepends `/reels` on rewrite |
| `/api/notification/*` | notification-service :3006 | `^/api/notification` → `` |
| `/api/ai/*` | message-svc :3004 | `^/` → `/api/ai/` (AI chat routes live in message-svc) |
| `/api/engagement/*` | engagement-service :3007 | `^/` → `/api/engagement/` |
| `/api/upload/*` | local multer+S3 handler | multipart pass-through |

**Middleware chain**
1. `express-rate-limit` v6 — 100 req / 15 min per IP (configurable via env).
2. `express.json({ limit: '10mb' })` + `urlencoded({ limit: '10mb' })`.
3. CORS — configurable `ALLOWED_ORIGINS`; credentialed; methods GET/POST/PUT/DELETE/PATCH/OPTIONS.
4. Optional debug request logger (gated on `LOG_LEVEL=debug`).
5. Per-service proxy with `pathRewrite`, multipart detection, body forwarding for POST/PUT/PATCH, and service-tagged error response.

**Health & discovery**
- `GET /health` returns `{status:"healthy", timestamp}` only; does **not** check downstream service health.
- Service URLs are **hardcoded in env vars**; no DNS/service registry, no load balancing, no circuit breaker, no retries. A single failing upstream returns 502 to the client.

**What is missing**
- **No JWT verification** here — authentication is offloaded entirely to downstream services which then don't enforce it (see §2.4, §2.6, §2.8).
- **No per-route rate limits** for sensitive flows (auth, like, comment).
- **No correlation ID** propagation → distributed tracing is impossible.
- **No request signing** or gateway-issued identity, so any service that receives a request from the gateway cannot distinguish it from a direct call.

---

## 2.2 api-service (3000)

**File:** [Backend-JS/api-service/src/index.js](../Backend-JS/api-service/src/index.js)

Confusingly, a **second** proxy service. Uses ES modules.

- Proxies `/api/main/*` → main (3002), `/api/notifications/*` → notifications (4001 — **mismatched port**, notification-service listens on 3006), `/api/feed/*` → feed (3003).
- Hosts its own Mandi price endpoints via [src/controller/mandiController.js](../Backend-JS/api-service/src/controller/mandiController.js) that call `data.gov.in` with a hardcoded API key.
- Standalone [cricgemini.js](../Backend-JS/api-service/cricgemini.js) calls Gemini with a **hardcoded API key** (`AIzaSyB...`) and is not wired into any route.
- Has `express-status-monitor` exposed at `/status` with default creds if env not set.
- Unused deps: `cheerio`, `geolib`.

**Verdict:** duplicated responsibility with `api-gateway-service`. One should be deleted, ideally `api-service` (port 3000) — keep mandi logic as a module inside main-service.

---

## 2.3 main-service (3002)

**Folder:** [Backend-JS/main-service/src/](../Backend-JS/main-service/src/)

The monolith. Owns identity, commerce, content metadata, and admin config.

### Models (25)
- **Identity:** `User`, `UserDetail` (nested profile with GeoJSON `location`), `OTP`, `WhatsAppOTP`.
- **Commerce:** `Company`, `Products`, `Services`, `SubscriptionPlan`, `UserSubscription`, `PaymentHistory`, `UsageTracking`, `IotAddon`, `UserIotAddon`, `Testimonial`.
- **Content meta:** `News`, `Scheme`, `HomeScreenAd`, `FeedAds`, `ReelAds`, `NewsAds`, `DisplayUI`.
- **Agronomy:** `Region`, `Crop`, `CropCalendar`, `Activity`.
- **IoT:** `DeviceRegistration` (ticketing flow for farmer→admin device pairing).

**Subscription shape** — `SubscriptionPlan.features` is an explicit feature flag map: `{ aiMessagesPerDay, consultantChatsPerDay, canCreatePosts, canCreateReels, marketplaceListings, adFree, analyticsAccess: ['none'|'basic'|'full'], iot: { waterPump, cropMonitoring, weatherStation } }`. This is the source of truth for feature gating across services, but no service consumes it directly — features are enforced client-side in Flutter.

### Route prefixes (partial)
- `/auth/*` — signup-with-phone, verify-otp, login, logout, change-password, find-user-ip (calls geoplugin).
- `/user/*`, `/companies/*`, `/products/*`, `/news/*`, `/ads/*` (6 ad types), `/service/*`, `/crop-calendar/*`, `/schemes/*`, `/analytics/*`, `/marketplace/*`, `/subscription/*` (plans, checkout, cancel), `/api/device-registration/*`, `/api/v1/iot/*` (device validation endpoint).

### Auth
- JWT from `Authorization: Bearer` or `token` cookie, 24h exp, secret from `JWT_SECRET` with a fallback default if unset (dangerous).
- `authorize(...roles)` middleware factory; helpers `isConsultant`, `isMarketplace`, `isAdmin`.
- Password hashing: bcrypt cost=10.
- OTP model: `phoneNo`, `otp`, `expiresAt`, `attempts` (max 3) — but **no per-phoneNo or per-IP rate limit**; the global 100/min limiter is the only brake.

### Caching
Redis singleton with tiered TTLs (SHORT 5m / MEDIUM 30m / LONG 1h / VERY_LONG 24h) and `getOrSet`-style helpers. Keys like `user:{id}`, `consultants`, `news:all`, `events:count:YYYY-MM-DD`. Falls back to DB on disconnect.

### Issues worth highlighting
- **Two route files for User** (`User.js` and `UserRoutes.js`) — dead code / confusion.
- `Auth.js:88` — `.catch()` on Nodemailer silently swallows failures.
- `ProductController.js:20–26` — non-transactional double update of User and Company. Race / orphan risk.
- `getAllProducts` returns unpaginated, populated documents.
- Seed scripts (`seedData.js`, `seedMoreUsers.js`, `seedAdsData.js`, etc.) are reachable by anyone who can run the container; should be CI-only and protected.
- No input-validation middleware despite `Joi` being installed — validators in `utils/validators.js` are not wired into routes.
- Winston logger has no redaction — passwords and tokens can reach log sinks.
- No MongoDB transactions anywhere.

---

## 2.4 feed-service (3003)

**Folder:** [Backend-JS/feed-service/src/](../Backend-JS/feed-service/src/)

Social feed. Express + Mongoose + Redis + RabbitMQ + node-cron.

### Models
- `FeedModel` — content, mediaUrls[], like/comment/views counters, `location` (GeoJSON Point), `tags[]`, soft-delete, text + 2dsphere indexes, `engagementScore` virtual = views + 3*likes + 5*comments.
- `LikeModel` — `{ userId, feed }` — **no unique index** (duplicate likes possible at schema level; application code does an "exists" check that can race).
- `CommentModel` — nested replies via parent ref.
- `Tags`, `userInterest`, `ShareModel`.

### Routes
`/feeds/*` — CRUD, like, comment, get by tag/user/trending, recommended, stats.
`/comments/*`, `/likes/*`, `/analytics/*`.

### Auto-post scheduler
`src/utils/autoPostScheduler.js` — node-cron every 2 minutes. Reads `samplePosts.json` and `adminConsultantUsers.json`, makes **HTTP POST to its own `/feeds`** without auth. Gated by `ENABLE_AUTO_POST=true`.

### Messaging
Publishes `{type, userId, title, body, priority, source:'feed-service', createdAt}` to RabbitMQ `notifications` queue on like/comment events.

### Serious issues
1. **No auth middleware on any route.** `likeController.toggleLike()` trusts `req.body.userId`. [src/controller/likeController.js:38](../Backend-JS/feed-service/src/controller/likeController.js)
2. **No input validation.** Controllers accept arbitrary fields; mass-assignment risk on `createFeed`.
3. **NoSQL injection** via query params that flow into `$regex` / `$in` filters.
4. **CORS fallback** is `origin: true` (allow everything) if `CORS_ORIGIN` unset.
5. **No pagination ceiling** on `getRecommendedFeeds` / `getRandomFeeds`.
6. **Aggregation pipelines** use triple `$lookup` (feed → comments → likes → user) without `$limit` early stages.
7. **Auto-poster makes unauthenticated POSTs** to its own API surface.

---

## 2.5 message-svc (3004)

**Folder:** [Backend-JS/message-svc/src/](../Backend-JS/message-svc/src/)

Chat + AI. Socket.io 4 + Mongoose + Redis + RabbitMQ. Also hosts AI chat (Gemini, Mistral, Groq).

### Models
- `chat.model` — type `direct|group`, participants, `lastMessage`, per-user `unreadCount` map.
- `message.model` — `chatId`, `sender`, `content` (≤5000), `mediaType` enum, `readBy[]`, `deliveredTo[]`, `isDeleted`, compound indexes including `chatId+'readBy.userId'`.
- `group.model` — `admin[]`, `members[]`, `onlyAdminCanMessage`.
- `ai-chat.model` — `aiProvider: 'gemini'|'mistral'|'groq'`, `dailyMessageCount: {count, lastResetDate}`, `conversationHistory[]`.

### Socket.io layer
[src/services/socket.service.js](../Backend-JS/message-svc/src/services/socket.service.js)

- **Auth**: reads `socket.handshake.auth.userId` and uses it directly. **There is no token verification.** Anyone can connect as anyone. This is the single most severe defect in the platform.
- Per-socket event rate limiting, 10 connections per user cap (map leaks — not decremented on disconnect).
- Auto-joins user to all their chat rooms on connect (one Mongo query per connect, O(n) chats).
- Emits `chat:create:direct`, `message:send`, `message:read`, `typing:start/stop`, `presence:online/offline`, `group:*`.
- Online status stored in Redis hash `online_users`.

### REST routes
`/api/chat/*`, `/api/group/*`, `/api/message/*`, `/api/ai/*`.
Auth middleware present for REST (`src/middleware/auth.middleware.js`) — it requires `x-user-id` and checks a Redis cache `user:{id}`, but **does not verify a JWT**. Poisoning the Redis key or forging headers is enough.

### AI chat
- `ai.service` dispatches to provider based on user's active chat. Per-day message limits enforced through `message-limit.service` (Redis counter). No token-length cap.
- `ai-socket.service` defers messages to next day when the daily allowance is exhausted rather than rejecting them.

### Issues
1. **Socket.io unauthenticated** — critical.
2. No ownership checks on `deleteMessage` / `markMessageAsRead`.
3. `userConnectionCount` map not cleaned on disconnect → slow memory leak over days.
4. Message history pagination is skip/limit (not cursor-based).
5. AI responses not sanitized → possible XSS in clients that render as HTML.

---

## 2.6 reel-service (3005)

**Folder:** [Backend-JS/reel-service/src/](../Backend-JS/reel-service/src/)

Short-video service with HLS/MP4/WebM output.

### Models
- `Reel` — `videoUrls: {hls, mp4, webm}`, `cloudinaryId`, `videoMeta: {duration, width, height, size, format}`, `location`, `like.count` indexed, `like.users[]` array.
- `LikeModel` — **has** unique index `{reel:1, userId:1}` (good — feed-service should copy this).
- `VideoComment` — nested replies with `depth`.
- `VideoTutorial`, `ReelUserInterest`.

### Routes
`/reels/*` — upload (Multer), `GET /reels/upload/signature` (Cloudinary signed URL for direct upload), `POST /:id/migrate` / `POST /reels/migrate-all` (transcode MP4→HLS), `GET /reels/trending`, `GET /reels/recommended/:userId`, like/comment.
`/videos/*`, `/analytics/*`.

### Critical issue — synchronous FFmpeg
`videoUploadController` / `videoUploadService` run fluent-ffmpeg transcodes **in-request**. Even with direct-upload signatures, migration endpoints block the event loop on CPU-bound work. On Node single-thread this freezes concurrent requests.

### Other issues
- Rate limiter skips `/like`, `/comments`, `/interaction`, `/interests` — exactly the endpoints that need tighter protection.
- No magic-byte / MIME validation on Multer uploads.
- No retries or dead-letter for failed Cloudinary ops.
- 50MB body limit (metadata shouldn't need 50MB).
- Disabled auto-reel scheduler is still in the codebase; confusing.

---

## 2.7 notification-service (3006)

**Folder:** [Backend-JS/notification-service/src/](../Backend-JS/notification-service/src/)

Centralized notifications with in-app WS fanout.

### Models
- `Notification` — `userId`, `type ∈ {push,email,sms,in_app}`, `status ∈ {pending,sent,delivered,failed,skipped,deferred}`, `priority`, `category ∈ {system,engagement,promotion,digest}`, `scheduledFor`, `dedupeKey`, `batchId`, `channelTrail[]`, `retryCount`, delivery timestamps.
- `User` — `pushTokens[]`, `notificationPreferences: { enabled, quietHours, categories: {...} }`, language, timezone.

### Processing
1. `queue.service` — three RabbitMQ queues: `notifications`, `batch`, `event`.
2. `batch-processor.js` — consumer with prefetch 10; ack on success, nack+requeue on transient, drop on validation failure; reschedules to next day if in quiet hours.
3. `processor.js` — checks preferences, tries primary channel then `fallbackChannels[]`.
4. `push.service` has a provider router but the Web Push / OneSignal / SMS implementations are **stubs**.
5. `digest.service` aggregates per-user digests; `notification-policy.service` enforces dedupe/quiet hours.
6. `websocket.service` uses native `ws` (not Socket.io) — **no Redis adapter** → cannot scale beyond a single pod.

### Issues
- Stub senders: **push, email, SMS are not actually wired to any provider in code I could see** — only scaffolding.
- `userId`/preference data in MongoDB is user-facing identity but never updated by main-service (no sync path documented).
- Push tokens stored plaintext.
- WS service won't scale horizontally.
- No delivery receipt webhook wiring for OneSignal.

---

## 2.8 engagement-service (3007)

**Folder:** [Backend-JS/engagement-service/src/](../Backend-JS/engagement-service/src/)

Event ingestion + analytics. Single purpose: absorb 100k+ concurrent clients emitting events.

### Models
- `Event` — 60+ `eventName` enum values across 9 categories (navigation, engagement, content, social, commerce, communication, ai, system, error). Properties include `contentId`, `contentType`, `duration`, `watchDuration`, `completionRate`, `searchQuery`, `device`, `location`, `processed` flag, **90-day TTL on timestamp**. Six compound indexes.
- `Session`, `UserMetrics`, `DailyMetrics` (aggregated).

### Routes
- `POST /api/engagement/events` and `/events/batch` — track single/batch, buffered in memory.
- `GET /api/engagement/events/:userId`, `/analytics/dashboard` (cached 1h), `/realtime` (cached 5m), `/engagement-breakdown`, `/churn-risk`.

### Pipeline
1. Event arrives → validated (userId / sessionId / eventName / eventCategory) → pushed to in-memory `eventBuffer`.
2. When size ≥ 1000 or 5 sec elapse, `flushBuffer()`:
   - `insertMany` to Mongo.
   - Publish to RabbitMQ `engagement_events` / `engagement_batch` queue.
   - Increment Redis counters (`events:count:YYYY-MM-DD`).
3. `aggregationWorker` (node-cron hourly) rolls raw events into `DailyMetrics`.

### Issues
- **No auth.** `POST /events` accepts arbitrary `userId`.
- **In-memory buffer** — crash = data loss, unbounded if Mongo slow → OOM.
- **Six compound indexes on Event** hurt write throughput on high volume.
- **Single Mongo collection** — sharding story unclear; at 100k DAU and 20 events/user/day that's 2M docs/day.
- **Daily rollup recomputed** instead of incremental `$inc`.
- **Rate limit by IP** not by userId.
- **NoSQL injection** on aggregation fields (eventName, userId).
- Timezone handling via `getTodayString()` likely naive UTC — Indian days cross at 05:30 UTC.

---

## 2.9 iot-service (Go)

**Folder:** [iot-service/](../iot-service/)

One Go binary, four modes. Only real test coverage in the codebase (~12 tests).

### Modes
| APP_TYPE | Role |
|---|---|
| `device` | Simulator — publishes handshake, raw sensor data, heartbeat |
| `parser` | Subscribes `krishi/sensors/raw`, validates session, routes to `krishi/sensors/soil` or `krishi/sensors/weather` |
| `soil` | Subscribes soil topic → validates ranges → INSERT into ClickHouse `soil_data` |
| `weather` | Same for `weather_data` |

### MQTT topics
```
krishi/handshake/request            (device → parser)
krishi/handshake/response/{id}      (parser → device)
krishi/sensors/raw                  (device → parser)
krishi/sensors/soil                 (parser → soil consumer)
krishi/sensors/weather              (parser → weather consumer)
krishi/heartbeat/request            (every 30s)
krishi/heartbeat/response/{id}
krishi/disconnect
```

### Handshake + session
`pkg/handlers/handshake.go` validates deviceId/type/firmware, then calls main-service `POST /api/v1/iot/validate-subscription` with `X-API-Key` header and 10s timeout. If `MAIN_SERVICE_API_KEY` is empty, the client is considered not-configured and **allows connection** (backward-compat fallback in `pkg/api/client.go`). This means the check is silently skipped in default deployments.

### ClickHouse schema
```sql
CREATE TABLE soil_data (
    device_id String,
    timestamp DateTime,
    moisture, temperature, ph, nitrogen, phosphorus, potassium Float64
) ENGINE = MergeTree() ORDER BY (device_id, timestamp);

CREATE TABLE weather_data (
    device_id String, timestamp DateTime,
    air_temp, humidity, pressure, wind_speed, rainfall, light_level Float64
) ENGINE = MergeTree() ORDER BY (device_id, timestamp);
```
No TTL, no partitioning (a single `ORDER BY` becomes the primary key — fine for dedup but not for compaction/retention). No replication.

### Validation
Reasonable ranges for all fields except NPK (no upper bound), wind speed (no max), rainfall (no max). An attacker can inject `nitrogen=1e308`.

### Reconnect
State machine: `DISCONNECTED → HANDSHAKING → CONNECTED → RECONNECTING → HANDSHAKING`. Exponential backoff 2s → 5m, infinite retries. No circuit breaker.

### Failure modes
- ClickHouse write failure → log and drop. **No DLQ, no retry queue.**
- MQTT broker requires no auth and uses no TLS. Anyone on the pod network can publish/subscribe anything.
- Device simulator has no throttling beyond its own interval.

### Config
All from env. `MAIN_SERVICE_API_KEY` empty by default. `CLICKHOUSE_PASS` empty in `secret.yaml`.

### Mosquitto config
`mosquitto/config/mosquitto.conf`:
```
listener 1883
allow_anonymous true
persistence true
log_dest file /mosquitto/log/mosquitto.log
```
No TLS, no ACL, no userdb.

---

## 2.10 Cross-service concerns

### 2.10.1 Identity propagation
Every service invents its own auth convention: gateway passes headers through, main-service verifies JWT, message-svc verifies `x-user-id` against Redis, feed/reel/engagement trust the body. This is split-brain. Unifying this is the single highest-leverage refactor available.

### 2.10.2 Event & queue topology
RabbitMQ has queues `notifications`, `batch`, `event`, `engagement_events`, `engagement_batch`. All durable, all on the same broker with `guest/guest` in docker-compose. No dead-letter exchanges anywhere. No schema registry — each publisher invents its own message shape.

### 2.10.3 Cache keys
Each service prefixes differently (`engagement:*`, no prefix in main, colon-delimited in message-svc). Under a single Redis instance this is a scoping hazard as the product grows.

### 2.10.4 Observability
- Winston (main, engagement, notification), Morgan (reel), `console.log` (gateway, feed controllers, Go services).
- Prometheus scrape config auto-discovers pods by annotation `prometheus_io_scrape: "true"` — **no deployment sets this annotation and no service exports `/metrics`**. Dashboard is empty.
- No distributed tracing (no OpenTelemetry, no Jaeger, no Zipkin). Correlation IDs are not propagated.

### 2.10.5 Testing
- **0** test files in `main-service`, `feed-service`, `reel-service`, `message-svc`, `notification-service`, `engagement-service`, `api-gateway-service`, `api-service`, admin panels, marketplace admin, landing page.
- **1** widget_test.dart (1 KB, placeholder) in Flutter app.
- **12** Go unit tests in `iot-service` covering backoff, config parsing, session lifecycle. These are the only tests in the repository.

### 2.10.6 Duplicated / orphan code
- `api-service` (3000) vs `api-gateway-service` (3001) — duplicated proxy.
- `Backend-JS/main-service/notification-service/` and `Backend-JS/main-service/message-service/` — nested folders shadowing top-level services. Likely leftover from an early rewrite.
- `Backend-JS/main-service/src/routes/User.js` vs `UserRoutes.js`.
- `tools/`, `build/`, `uploads/` in reel-service contain artifacts that should be gitignored.

These three concerns (identity, observability, duplication) set the theme for the refactoring roadmap in §05.
