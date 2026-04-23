# 01 — Architecture Overview

> System-wide view of Krishi-Mantra: a microservices-based agricultural platform for Indian farmers.

---

## 1. Product Snapshot

Krishi-Mantra ("KrishiMantra" / "Krishi Doctor") is a multi-surface agricultural platform targeting Indian small & marginal farmers. It combines:

- A **Flutter mobile app** (primary surface, 6 languages: EN/HI/MR/GU/BN/TA).
- Two **Next.js admin panels** — one super-admin, one marketplace-admin.
- A **Vite landing page** (marketing).
- A **Node.js microservices backend** (8 services) behind a thin Express API gateway.
- A **Go-based IoT platform** (MQTT + ClickHouse) for farm-sensor telemetry.
- Infrastructure via **Docker + Kubernetes** (`microservices` namespace) with Redis, RabbitMQ, MongoDB, Prometheus.

Core user-facing features: expert consultation, Krishi AI (Gemini/Mistral/Groq), weather, mandi prices with MSP comparison, marketplace, feeds, reels, chat, video tutorials, government schemes, disease detection (TFLite + Gemini Vision), farm area measurement, IoT pump/sensor monitoring, subscriptions (KISAN / KISAN_PRO / KISAN_PLUS / KISAN_MEGA) via Stripe.

---

## 2. High-Level Topology

```
                           ┌──────────────────────────────────────┐
                           │        External clients              │
                           │ Flutter app · Admin · Marketplace    │
                           │          Landing page                │
                           └───────────────┬──────────────────────┘
                                           │ HTTPS
                                           ▼
                              ┌───────────────────────────┐
                              │  api-gateway-service :3001│
                              │  (http-proxy-middleware)  │
                              └─┬────┬────┬────┬────┬─────┘
                                │    │    │    │    │
          ┌─────────────────────┘    │    │    │    └───────────────┐
          ▼                          ▼    ▼    ▼                    ▼
 ┌────────────────┐  ┌──────────┐ ┌──────┐ ┌──────┐  ┌─────────────────┐
 │ main-service   │  │ feed-svc │ │reel  │ │msg   │  │ notification-svc│
 │ :3002          │  │ :3003    │ │:3005 │ │:3004 │  │ :3006           │
 │ auth/user/     │  │ posts/   │ │reels │ │chat+ │  │ push/email/sms/ │
 │ company/prod/  │  │ likes/   │ │HLS   │ │AI    │  │ in-app + WS     │
 │ marketplace/   │  │ comments │ │upload│ │(gem/ │  │                 │
 │ subscription/  │  │ auto-post│ │      │ │mistral│ │                 │
 │ ads/crop-cal   │  │          │ │      │ │groq) │  │                 │
 └──────┬─────────┘  └────┬─────┘ └──┬───┘ └──┬───┘  └────────┬────────┘
        │                 │          │        │                │
        │            ┌────┴──────────┴────────┴────────────────┘
        │            │ RabbitMQ (notifications, events, batch)
        │            ▼
        │    ┌─────────────────────┐
        │    │ engagement-svc :3007│
        │    │ events, analytics,  │
        │    │ aggregation worker  │
        │    └─────────────────────┘
        │
        │            ┌─────────────────┐     ┌─────────────────┐
        ├──────────► │ api-service     │     │ Stripe · Twilio │
        │            │ :3000 (legacy/  │     │ Gemini · Cloudi │
        │            │ proxy+mandi)    │     │ -nary · OWM     │
        │            └─────────────────┘     └─────────────────┘
        │
   MongoDB · Redis · Cloudinary · S3

                 ─── IoT plane (Go) ───
 ┌──────────────┐  MQTT  ┌──────────────┐     ┌───────────────┐
 │ iot-device   │ ─────► │ iot-parser   │ ──► │ iot-soil /    │
 │ (simulator)  │        │ (handshake,  │     │ iot-weather   │
 └──────────────┘        │  routing)    │     │ (validation + │
                         └──────┬───────┘     │  persist)     │
                                │ calls main  └──────┬────────┘
                                ▼ for sub auth       ▼
                         main-service /iot    ClickHouse :9000
                                              (soil_data, weather_data)
```

---

## 3. Services Inventory

### 3.1 Backend (Node.js, all Express)

| Service | Port | Role | Key tech |
|---|---|---|---|
| `api-gateway-service` | 3001 | Thin reverse proxy; rate limit; CORS | http-proxy-middleware 3, express-rate-limit |
| `main-service` | 3002 | Auth, user, company, product, marketplace, crop-calendar, ads, schemes, subscription, payment | Mongoose, Redis, Stripe, Twilio, Nodemailer, Cloudinary, Joi |
| `feed-service` | 3003 | Social feed, likes, comments, trending, auto-post, user interests, geo-feed | Mongoose, ioredis, amqplib, node-cron, Cloudinary |
| `message-svc` | 3004 | Chat (Socket.io), groups, AI chat (Gemini/Mistral/Groq), rate limit | Socket.io 4, Redis, RabbitMQ |
| `reel-service` | 3005 | Reel upload, HLS/MP4 transcoding, likes, comments, tutorials | Mongoose, fluent-ffmpeg, AWS S3, Cloudinary, node-cron |
| `notification-service` | 3006 | Push/email/SMS/in-app fanout, batch, digest, WebSocket | Nodemailer, `ws`, OneSignal/Web Push, Winston |
| `engagement-service` | 3007 | Event ingestion, analytics, aggregation worker | Mongoose (high-pool), Redis, RabbitMQ, node-cron |
| `api-service` | 3000 | Legacy/secondary proxy + Mandi (data.gov.in) + Gemini stub | Express, http-proxy-middleware, axios, data.gov.in |

### 3.2 IoT plane (Go)

Single binary, four modes via `APP_TYPE`: `device` (simulator), `parser` (handshake + routing), `soil`, `weather` (consumer + persistence).

- MQTT broker: **Mosquitto**, anonymous listener `:1883`
- Time-series DB: **ClickHouse** (`soil_data`, `weather_data`, MergeTree, ORDER BY `(device_id, timestamp)`)
- Subscription gating via `POST /api/v1/iot/validate-subscription` to `main-service`
- Tests: ~12 unit tests (`connection`, `config`, `models`, `session`)

### 3.3 Frontends

| Surface | Stack | Purpose |
|---|---|---|
| `Frontend/krishimantra` | Flutter 3.6+, GetX, Dio, Hive, Socket.io-client, tflite_flutter | Farmer-facing app (30+ screens, 21 controllers, 140+ endpoints consumed) |
| `Frontend/admin-panel` | Next.js 14 (app router), TS, Tailwind, shadcn/ui, Zustand | Super-admin for users/companies/ads/feeds/reels/subscriptions/IoT addons |
| `Frontend/marketplace-admin` | Next.js 15, TS, Tailwind, shadcn, Zustand, Sonner, next-themes | Marketplace ops (marketplace products, companies, trending) |
| `Frontend/landing-page` | Vite + vanilla JS/HTML/CSS | Public marketing site (~87KB gzipped) |

### 3.4 Infrastructure & Ops

- **Docker Compose** sets: `docker-compose.yml` (services), `docker-compose.infra.yml` (Mongo 27018, Redis 6380, RabbitMQ 5672), `docker-compose.iot.yml` (mosquitto, clickhouse, iot-device, iot-parser, iot-soil, iot-weather).
- **Kubernetes** manifests under `deployment/`: per-service folders (deployment.yaml, service.yaml, configmap.yaml, secret.yaml) plus `ingress.yaml`, Prometheus (configmap/deployment/service), Redis, RabbitMQ, and `deploy.sh`.
- **Observability**: Prometheus configured (pod/node auto-discovery) but **zero /metrics endpoints** across services → effectively blind. No Grafana, no Alertmanager, no tracing, no log aggregation.

---

## 4. Cross-Cutting Data Flows

### 4.1 Auth flow (phone OTP, primary)

```
Flutter app ─► POST /api/main/auth/initiate-auth (phoneNo)
   main-service ─► Twilio SMS / WhatsApp (OTP + 10-min TTL, max 3 attempts)
Flutter app ─► POST /api/main/auth/verify-otp (phoneNo, otp)
   main-service ─► issue JWT (24h) + refresh token
Flutter app stores tokens via flutter_secure_storage
All subsequent requests carry `Authorization: Bearer <jwt>`
```

**Critical gap:** API gateway does **not** verify JWTs. Each downstream service is expected to trust `Authorization` header and/or `x-user-id`, but **feed/reel/message/notification controllers do not enforce auth** — any request that makes it past the gateway's rate limiter can mutate data under any `userId`.

### 4.2 Feed/engagement flow

```
Flutter ─► POST /api/feed/feeds/:id/like
  feed-svc increments counter, toggles Like model, invalidates Redis cache
  feed-svc publishes to RabbitMQ "notifications" queue
    notification-svc processor picks up, checks prefs/quiet hours,
    routes to push/email/in-app, broadcasts via native `ws`
  feed-svc (separately) the Flutter app emits events to engagement-svc
    engagement-svc buffers (in-memory) → flushes to Mongo + RabbitMQ
    aggregationWorker cron rolls DailyMetrics hourly
```

### 4.3 Chat flow

```
Flutter ─► Socket.io handshake to message-svc (via gateway polling or direct WS)
  message-svc reads `socket.handshake.auth.userId` (NO TOKEN VALIDATION)
  auto-joins user to all participant chatIds
  message:send ─► message.service creates Message, updates Chat.unreadCount,
    emits to chatId room, tracks deliveredTo/readBy
AI chat path: ai:message:send ─► ai.service calls Gemini/Mistral/Groq,
  enforces per-day message limit via Redis counter
```

### 4.4 Reel upload

```
Flutter ─► GET /api/reels/upload/signature (Cloudinary signed URL)
Flutter ─► direct upload to Cloudinary
Flutter ─► POST /api/reels/upload (metadata only)
  reel-svc kicks off FFmpeg HLS/MP4 transcode **synchronously** (blocks request)
  reel-svc stores videoUrls.hls / .mp4 / .webm
```

### 4.5 IoT ingestion

```
Device MQTT ─► krishi/handshake/request (deviceId, type, firmware)
  parser ─► main-service POST /api/v1/iot/validate-subscription
  parser ─► krishi/handshake/response/<deviceId> (session_id or reason)
Device ─► krishi/sensors/raw (session_id + payload)
  parser routes by sensor type to krishi/sensors/soil or /weather
  consumers validate ranges, INSERT into ClickHouse
Heartbeat every 30s; reconnect with exponential backoff (2s → 5m)
```

### 4.6 Subscription & payment

```
Flutter ─► POST /api/main/subscription/checkout (planId, billingCycle)
  main-service calls Stripe Checkout Session, returns URL
Stripe webhook ─► main-service updates UserSubscription (status, endDate)
  Features gated by SubscriptionPlan.features flags (aiMessagesPerDay,
  canCreatePosts, iot.{waterPump,cropMonitoring,weatherStation}, etc.)
  UsageTracking increments per day for AI messages / consultant chats
```

---

## 5. Persistence & State

| Store | Role | Notes |
|---|---|---|
| MongoDB | Primary OLTP for all Node services | No sharding; `main-service` has ~25 models; Feed/Reel/Message have own DBs (unclear if shared cluster) |
| Redis | Caching, online users, rate-limit state, counters, feed caches, Socket.io room state | Singleton per service; graceful fallback to DB when unavailable |
| RabbitMQ | Async: notifications, event stream (feed_created, post_liked, etc.), batch queues | Durable queues, 24h message TTL (engagement), no DLQ anywhere |
| ClickHouse | Time-series sensor data | No TTL, no partitioning, no replication |
| Cloudinary | Images + reel video HLS | Used by main, feed, reel |
| AWS S3 | Alternate media storage | multer-s3 wired but unused in most flows |
| Hive (client) | Flutter cache via `dio_cache_interceptor_hive_store` | 5m/1h/1d tiers, unencrypted |

---

## 6. Language & Localization

Flutter app owns i18n via `lib/core/utils/home_localizations.dart` (≈630 lines, 100+ keys, 6 languages). Runtime language switching through `LanguageService` + `TranslationManager`; batch translation via Google Translator library for dynamic backend content. Admin panels & landing page are **English only**.

---

## 7. Notable Implementation Choices

**Good:**
- Clean Flutter architecture (core/data/presentation) and GetX DI.
- Rich event taxonomy in engagement-service (60+ event types, 8 categories).
- Two-tier ML for disease detection (TFLite on-device + Gemini Vision cloud fallback).
- MongoDB connection pooling tuned for 10k / 100k concurrent users in main and engagement.
- Thread-safe token refresh in Flutter's `ApiService` using a `Completer`-based lock.
- Stripe-gated subscription with per-day usage tracking.

**Worrying:**
- **No JWT verification at gateway** and **no auth middleware** on feed/reel/message controllers. Services trust `userId` from request body.
- **Socket.io accepts any `userId`** from handshake with no token check (`message-svc/src/services/socket.service.js`).
- **Hardcoded API keys in source** (`api-service/cricgemini.js`, `api-service/src/controller/mandiController.js`, Flutter `AppConfig`).
- **MQTT broker allows anonymous** on plain TCP (no TLS, no ACL).
- **Synchronous FFmpeg transcode** in reel-service request path.
- **In-memory event buffer** in engagement-service is lost on crash.
- **Zero Prometheus instrumentation**; Prometheus deployed but nothing to scrape.
- **~0% automated test coverage** across mobile, backend, and admin panels (12 Go tests aside).
- **Duplicate services**: `api-gateway-service` (3001) and `api-service` (3000) both proxy but to overlapping routes — confusing and split-brain.
- **Notification-service nested under main-service** as well (`Backend-JS/main-service/notification-service/`) — orphan? unclear ownership.

---

## 8. Deployment Model

**Docker (dev):** Three compose files. `infra` brings up Mongo/Redis/RabbitMQ on non-default ports (27018/6380/5672) with hardcoded creds (admin/secure-password, guest/guest). `iot` compose doesn't wire to `main-service`, so subscription validation silently degrades to allow-all (backward-compat fallback in `pkg/api/client.go`).

**Kubernetes:** All resources in the `microservices` namespace. Each service has deployment + service + configmap + secret. IoT consumers scale to 2 replicas with tight 128Mi/256Mi memory limits and **no liveness/readiness probes**. `deploy.sh` references `hpa.yaml` per service but those files are **not in the repo**. Ingress is `api.yourwebsite.com → api-gateway:80` with cert-manager TLS, but no path-based routing — everything funnels through the gateway's own routing table. No NetworkPolicy; no PodDisruptionBudget; secrets are plaintext YAML.

**Release:** No CI workflows checked in. Ecosystem files (`ecosystem.config.js`) hint at PM2-based rollouts in dev/staging.

---

## 9. Summary of Risks Worth Remembering

1. Auth is effectively client-enforced on content services. Any authenticated mobile client can impersonate other users.
2. IoT MQTT is wide open — anyone on the network can publish fake sensor data under any `device_id`.
3. Observability is a placebo — Prometheus is deployed but no service exports metrics.
4. Data-loss risks in engagement (RAM buffer) and IoT (no DLQ on ClickHouse write failure).
5. Reel uploads block the event loop during FFmpeg transcoding — trivial DoS.
6. Secrets are committed (Gemini key, data.gov.in key) or stored plaintext in K8s manifests.

These define the scope of the documents that follow: `02-microservices-deep-dive.md` drills into each service; `03-frontend-deep-dive.md` into the clients; `04-gaps-and-improvements.md` catalogues the problems; `05-refactoring-roadmap.md` sequences the fixes; `06-security-performance-audit.md` focuses the security and perf lens.
