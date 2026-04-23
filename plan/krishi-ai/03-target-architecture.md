# 03 — Target Architecture

## 1. System diagram (target)

```
       ┌────────────────────────┐     ┌────────────────────────┐
       │  Admin Panel (Next.js) │     │  Flutter mobile app    │
       │  /settings/ai-provider │     │  - Onboarding          │
       │  - Pick provider       │     │  - AI chat             │
       │  - Upload credentials  │     │  - Edit farm profile   │
       │  - Validate + Activate │     └─────────┬──────────────┘
       └───────────┬────────────┘               │  HTTPS + JWT
                   │  HTTPS + admin JWT         │
                   ▼                            ▼
                   ┌─────────────────────────────────────────┐
                   │           api-gateway-service            │
                   │  /api/auth  /api/farm-profile  /api/ai   │
                   │  /api/weather  /api/admin/ai-provider    │
                   └────┬───────────────┬────────────────┬────┘
                        │               │                │
     /api/auth/*        │               │  /api/ai/*     │  /api/admin/ai-provider/*
     /api/farm-*        │               │  /api/weather/*│  (admin JWT required)
     /api/admin/ai-*    │               │                │
                        ▼               ▼                ▼
              ┌───────────────┐   ┌──────────────────┐   │
              │ main-service  │   │    message-svc   │   │
              │  - Auth       │   │  - ai.controller │◀──┤
              │  - UserDetail │   │  - ai.service    │   │ (admin writes go
              │  - FarmProfile│   │  - context-tree  │   │  to main-service;
              │  - Crop master│   │  - weather.svc   │   │  message-svc reads
              │  - Subscription│  │                  │   │  via AiProviderConfig
              │  - AiProviderConfig│ │  ┌──────────────┐ │   cache)
              │  - AiProviderAudit│◀─┤  │ProviderFactory│
              └──────┬─────────┘  │  │  ├──────────────┤
                     │            │  │  │ openai.provider  │
                     │            │  │  │ vertex.provider  │
                     │            │  │  └──────────────┘
                     │            │  └────┬─────────────┘
                     │            │       │
                     │Redis pub/sub│      │ credentials resolved
                     │  ai-config. │      │ at call time (decrypted)
                     │  changed    │      ▼
                     ▼            ▼     ┌──────────────────┐
                 ┌────────────────────┐ │   External        │
                 │      MongoDB        │ │  - OpenAI API     │
                 │  users              │ │  - Vertex AI      │
                 │  farm_profiles      │ │  - Open-Meteo     │
                 │  ai_chats           │ │  - OpenWeather    │
                 │  weather_snapshots  │ └──────────────────┘
                 │  ai_provider_configs│
                 │  ai_provider_audit  │
                 └────────────────────┘

                 ┌──────────────────────────────┐
                 │  Redis (cluster)              │
                 │  subscription:limits          │
                 │  farm-profile:{uid}           │
                 │  weather:{bucket}             │
                 │  ctx-layer:{fp}               │
                 │  ai-config:active-provider    │◀─ invalidated on admin flip
                 │  vertex:ctx-cache:{fp}        │
                 └──────────────────────────────┘
```

## 2. Service responsibilities (target)

### main-service (adds)
- Owns **`FarmProfile`** collection (see doc 04 §1).
- Owns **`AiProviderConfig`** + **`AiProviderAudit`** collections (see doc 04 §1a, doc 13).
- New farm-profile routes:
  - `GET /api/farm-profile/me` — returns the caller's profile (joined with crop master names).
  - `POST /api/farm-profile` — create/replace whole profile.
  - `PATCH /api/farm-profile` — partial update.
  - `POST /api/farm-profile/crops` — append crop.
  - `PATCH /api/farm-profile/crops/:cropEntryId` — update one crop.
  - `DELETE /api/farm-profile/crops/:cropEntryId` — remove one crop.
  - `GET /api/farm-profile/master/crops` — paginated crop master (search).
- New admin routes (full list in doc 13):
  - `GET/POST /api/admin/ai-provider` (list/create OpenAI or Vertex config)
  - `POST /api/admin/ai-provider/:id/validate` (low-cost credential check)
  - `POST /api/admin/ai-provider/:id/activate` (atomic switch under Mongo session)
  - `POST /api/admin/ai-provider/:id/rotate-credentials`
- Onboarding signup still returns basic user+token; client steps through onboarding screens that call `POST /api/farm-profile`.
- Emits Redis pub-sub events:
  - `farm-profile.updated` → message-svc invalidates farm-profile cache.
  - `ai-config.changed` → message-svc invalidates `ai-config:active-provider` + `ProviderFactory` cache.

### message-svc (rewritten AI subsystem)
- Replaces Groq+Gemini with a **ProviderFactory** in front of two implementations.
- New internal modules:
  - `ai-providers/provider.interface.js` — adapter contract (`streamChat`, `chat`, `analyzeImages`, `embed`, `countTokens`, `validate`).
  - `ai-providers/openai.provider.js` — OpenAI implementation (doc 06).
  - `ai-providers/vertex.provider.js` — Google Vertex AI implementation (doc 06b).
  - `ai-providers/factory.js` — resolves the active provider via `ai-config.service` and returns the matching module.
  - `services/ai-config.service.js` — fetches the active `AiProviderConfig` (Redis-cached, pub/sub invalidated), decrypts credentials on demand.
  - `services/context-tree.service.js` — assembles & caches layered prompt blocks (provider-neutral).
  - `services/weather.service.js` — fetches + caches 7-day weather window.
  - `services/farm-profile.client.js` — HTTP client to main-service, Redis-cached.
  - `services/token-budget.service.js` — counts tokens per layer, prunes if over budget.
  - `services/intent-router.service.js` — classifies user message; asks the active provider for the cheap-model fallback call.
  - `services/chat-summarizer.service.js` — rolls older turns into a 150-token summary via the active provider.
- AI controller is mostly untouched externally (same routes) — internally it calls `ContextTreeService.buildMessages(...)` then `ProviderFactory.active().streamChat(...)`.
- SSE streaming added behind `Accept: text/event-stream` (both providers' streams are normalized to OpenAI-style delta events before going out).

### api-gateway-service
- Add three route groups:
  - `/api/farm-profile/*` → main-service (JWT required).
  - `/api/weather/*` → message-svc (JWT required) for the mobile weather UI to consume the cached 7-day data too.
  - `/api/admin/ai-provider/*` → main-service (**admin JWT required**, plus per-admin rate-limit: 60 req/hour).
- No rate-limit changes beyond copying the existing `authenticatedLimiter` + stricter cap on the admin route group.

### Admin panel (Next.js app at `Frontend/admin-panel/`)
- New section under existing `/settings` → `/settings/ai-provider`:
  - List configs, show active, health, usage.
  - Editors for OpenAI and Vertex (doc 13 §7).
  - Validate / Activate / Rotate actions.
- No other services change.

## 3. Request flow — text chat turn

```
User types "what about tomato spots?"
    │
    ▼
AIChatController.sendMessage()
  - body: { chatId, message, preferredLanguage }       ← location/weather REMOVED from client
  - Authorization: Bearer <jwt>
    │
    ▼  POST /api/ai/chat  (gateway → message-svc)
    │
    ▼
ai.controller.sendMessage()
  1. Load/create AIChat doc from MongoDB
  2. Check subscription quota (cached)
  3. Intent classify user message → { intent: "plant-health", cropsOfInterest: ["tomato"] }
  4. ContextTreeService.assemble({
       userId, chatId, intent, cropsOfInterest, preferredLanguage
     })
        → returns { systemPrompt, messagesWindow, fingerprints, tokenCountEst }
  5. TokenBudgetService.fit(...)  // prune if over budget
  6. OpenAIProvider.streamChat({
       model: "gpt-4.1-mini",
       messages: [systemPrompt, ...messagesWindow, newUserTurn],
       stream: true,
       user: userId
     })
  7. Pipe SSE back to client. On close:
      - Save assistant message to AIChat
      - Save usage (prompt_tokens, cached_tokens, completion_tokens, cost)
      - Bump daily quota counter
      - If chat has > 10 turns since last summary → fire-and-forget ChatSummarizer
```

## 4. Request flow — image turn

Same as above but:
- `multipart/form-data` with 1..5 images.
- Each image uploaded to S3 (existing `PresignedUrl` path) **before** hitting AI endpoint. We only send URLs, not bytes, to OpenAI — let it fetch them (OpenAI vision accepts URLs). This keeps our payload small.
- `OpenAIProvider.analyzeImages({ messages, imageUrls })` uses `gpt-4o-mini` (vision-capable).
- ContextTreeService still builds the prompt tree; vision just swaps the terminal `content` into multipart `[text, image_url, image_url, …]` OpenAI format.

## 5. API surface (delta)

### New (main-service)
```
# Farm profile
GET    /api/farm-profile/me
POST   /api/farm-profile               { location, totalArea, unit, … , crops: [...] }
PATCH  /api/farm-profile               partial
POST   /api/farm-profile/crops         { cropId, variety, area, sowingDate, … }
PATCH  /api/farm-profile/crops/:id
DELETE /api/farm-profile/crops/:id
GET    /api/farm-profile/master/crops?q=tomato

# Admin — AI provider (full spec in doc 13)
GET    /api/admin/ai-provider                list configs (no credentials)
GET    /api/admin/ai-provider/active         current provider + health
POST   /api/admin/ai-provider/openai         create/update OpenAI config
POST   /api/admin/ai-provider/vertex         create/update Vertex config (multipart if SA JSON)
POST   /api/admin/ai-provider/:id/validate   fires a real credential check
POST   /api/admin/ai-provider/:id/activate   atomic switch
POST   /api/admin/ai-provider/:id/rotate-credentials
PATCH  /api/admin/ai-provider/:id            update non-credential fields
DELETE /api/admin/ai-provider/:id            (not allowed if active)
GET    /api/admin/ai-provider/audit
```

### New (message-svc)
```
GET    /api/weather/7day?lat=..&lon=..       ← used by mobile UI too
GET    /api/ai/cost-summary                  ← optional: user's token/cost last 30d
```

### Changed (message-svc)
`POST /api/ai/chat` — `location` / `weather` fields in body are now **ignored** (server derives from FarmProfile). Left optional for back-compat so old app builds don't 400.

### Unchanged
All other existing endpoints. Response shapes extend (add fields) but never remove.

## 6. Data ownership

| Collection | Service owner | Read-by |
|-----------|---------------|---------|
| `users` | main-service | message-svc (via HTTP) |
| `user_details` | main-service | message-svc (cached) |
| `farm_profiles` *(new)* | main-service | message-svc (cached) |
| `crops` (master) | main-service | message-svc (cached, rarely invalidated) |
| `ai_provider_configs` *(new)* | main-service | message-svc (cached 5 min, pub/sub invalidated) |
| `ai_provider_audit` *(new)* | main-service | — |
| `ai_chats` | message-svc | — |
| `weather_snapshots` *(new)* | message-svc | — |
| `context_caches` *(new, optional)* | message-svc | — |

Cross-service calls go over HTTP (REST) + Redis cache, never direct Mongo. This preserves the microservice boundary.

## 7. Key design choices (with one-line rationale)

| Choice | Why |
|--------|-----|
| Assemble prompt **server-side**, not client | Profile+weather changes daily; client can't be trusted to send fresh data; and we want caching. |
| Store **FarmProfile as its own collection**, not nested in UserDetail | Grows fast (per-crop records), lifecycle differs, indexed separately. UserDetail stays a thin profile. |
| **Open-Meteo first**, OpenWeather fallback | Open-Meteo is free and returns past+future in one call. OpenWeather requires a key and is paid — keep as fallback. |
| **gpt-4.1-mini** for chat (not gpt-4o) | ~90% of the quality at ~20% of the cost. Multi-lingual is solid. Can upgrade selectively via intent router. |
| **gpt-4o-mini** for vision | Cheapest vision-capable model that meets the task. |
| **OpenAI prompt caching** (automatic, no flag) | Reuses byte-identical prefixes for ~50% discount. Requires us to put stable layers first. |
| **Redis as layer cache** | Already in-stack. TTL + fingerprint key. |
| **Streaming via SSE** | Cuts perceived latency; first token in <1.5s. Server's already Express, easy to add. |
| **Context tree, not RAG vector store** | Farmer profile is small and structured; no need for retrieval. Tree is simpler, cheaper, deterministic. |

## 8. Feature flag plan

Legacy-cutover flag `AI_PROVIDER_MODE` (service env only, retired after full cutover):
- `legacy` — Groq+Gemini (current behavior).
- `registry` — reads `AiProviderConfig` from the DB; serves via `ProviderFactory`.
- `shadow` — serve legacy to user, call the admin-active provider in parallel, log cost/latency only. Used for 1 week before flipping to `registry`.

Once in `registry` mode, the **admin panel** becomes the switchboard: picking OpenAI vs Vertex is a DB mutation, no code change, no deploy. Overridable per-user in Redis (`ai:provider-override:{userId}`) for internal beta testing (this override pins a specific config id, not a provider name, so it keeps working across future providers).

Additional hard guards:
- `ai:killswitch:global` — 503 the whole AI path.
- `ai:killswitch:openai`, `ai:killswitch:vertex` — force the factory to skip a specific provider (useful to isolate a bad provider without touching config).

## 9. What this doesn't solve yet

- No semantic search over past farmer chats (future epic: embed and retrieve relevant past turns).
- No "proactive" notifications ("your tomato needs fungicide today") — that's a separate scheduled-job feature.
- Chat-level cost billing back to user (only internal observability).
- IoT sensor data integration into the prompt (branch name suggests it's coming — leave a hook in the context tree for a future `iot` layer).

## 10. Hooks left open for future work

Each context-tree layer has a version tag. Adding a new layer (e.g. `iot-readings`) is:
1. Add a builder method in `context-tree.service.js`.
2. Insert at correct priority in `layerOrder[]`.
3. Bump `TREE_VERSION` so existing caches invalidate.

This keeps the refactor future-proof without committing to every hypothetical layer today.
