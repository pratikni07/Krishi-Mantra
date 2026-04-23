# 02 — Current State Analysis

> Snapshot of the AI feature as of branch `copilot/add-iot-device-for-krishi-mantra` (scanned 2026-04-21). This is the *before* against which the target in doc 03 is measured.

## 1. Service map

```
          ┌───────────────────────────┐
  mobile  │    api-gateway-service    │
  app  ──▶│  (Express + JWT + limit)  │
          └────────────┬──────────────┘
                       │ /api/ai/*
                       ▼
          ┌───────────────────────────┐       ┌─────────────┐
          │       message-svc         │──────▶│    Redis    │ (quota cache)
          │  ai.controller / service  │       └─────────────┘
          └────┬──────────────┬───────┘
               │ Groq SDK     │ Gemini SDK
               ▼              ▼
          Llama-3.3-70b   gemini-2.0-flash
```

- **AI service = `message-svc`** (historically the chat/socket service; AI was bolted on).
- **api-service** at `Backend-JS/api-service/` is a separate thin service (different feature — not the AI service, despite the name). Kept unchanged.
- **main-service** owns User, UserDetail, Subscription, Crop, CropCalendar models. AI service calls main-service for quota checks.

## 2. Key files today

| Concern | Path |
|--------|------|
| Gateway routing (all `/api/ai/*` → message-svc) | [Backend-JS/api-gateway-service/index.js:288-294](../../Backend-JS/api-gateway-service/index.js#L288-L294) |
| AI routes | [Backend-JS/message-svc/src/routes/ai.routes.js](../../Backend-JS/message-svc/src/routes/ai.routes.js) |
| AI controller | [Backend-JS/message-svc/src/controllers/ai.controller.js](../../Backend-JS/message-svc/src/controllers/ai.controller.js) |
| AI service (prompt + provider calls) | [Backend-JS/message-svc/src/services/ai.service.js](../../Backend-JS/message-svc/src/services/ai.service.js) |
| Chat history model | [Backend-JS/message-svc/src/models/ai-chat.model.js](../../Backend-JS/message-svc/src/models/ai-chat.model.js) |
| Daily quota | [Backend-JS/message-svc/src/services/message-limit.service.js](../../Backend-JS/message-svc/src/services/message-limit.service.js) |
| Subscription fanout to main-svc | [Backend-JS/message-svc/src/services/subscription.service.js](../../Backend-JS/message-svc/src/services/subscription.service.js) |
| User schema | [Backend-JS/main-service/src/model/User.js](../../Backend-JS/main-service/src/model/User.js) |
| Extended profile | [Backend-JS/main-service/src/model/UserDetail.js](../../Backend-JS/main-service/src/model/UserDetail.js) |
| Crop master | [Backend-JS/main-service/src/model/CropCalendar/Crop.js](../../Backend-JS/main-service/src/model/CropCalendar/Crop.js) |
| Signup controller | [Backend-JS/main-service/src/controller/Auth.js](../../Backend-JS/main-service/src/controller/Auth.js) |
| Flutter AI chat screen | [Frontend/krishimantra/lib/presentation/screens/ai_chat/ai_chat_screen.dart](../../Frontend/krishimantra/lib/presentation/screens/ai_chat/ai_chat_screen.dart) |
| Flutter AI chat controller | [Frontend/krishimantra/lib/presentation/controllers/ai_chat_controller.dart](../../Frontend/krishimantra/lib/presentation/controllers/ai_chat_controller.dart) |
| Flutter signup | [Frontend/krishimantra/lib/presentation/screens/auth/signup_screen.dart](../../Frontend/krishimantra/lib/presentation/screens/auth/signup_screen.dart) |
| Flutter weather service | [Frontend/krishimantra/lib/data/services/weather_service.dart](../../Frontend/krishimantra/lib/data/services/weather_service.dart) |

## 3. Current AI endpoints (message-svc)

| Method | Path | Handler | Notes |
|--------|------|---------|-------|
| POST | `/api/ai/chat` | `sendMessage` | Text turn. Groq. |
| POST | `/api/ai/analyze-image` | `analyzeCropImage` | Single image, multipart. Gemini. 10MB cap. |
| POST | `/api/ai/analyze-multi-images` | `analyzeMultipleImages` | Up to 5 images. Gemini. |
| GET  | `/api/ai/history` | `getChatHistory` | Paginated list. |
| GET  | `/api/ai/chat/:chatId` | `getChatById` | Single chat with messages. |
| PATCH | `/api/ai/chat/:chatId/title` | `updateChatTitle` | |
| DELETE | `/api/ai/chat/:chatId` | `deleteChat` | Soft (`isActive=false`). |
| GET  | `/api/ai/limit-info` | `getMessageLimitInfo` | Daily quota left. |
| POST | `/api/ai/new-chat` | `createNewChat` | Create empty chat. |

Rate limits per route:
- chat: 200 req/min
- image: 10 req / 5 min
- everything else: 100 req / 15 min

## 4. Current request / response shapes

### Chat request (from mobile)
```json
POST /api/ai/chat
{
  "userId": "...",
  "userName": "Pratik",
  "userProfilePhoto": "https://...",
  "chatId": "651abc...",
  "message": "My tomato leaves have yellow spots",
  "preferredLanguage": "en",
  "location": { "lat": 0.0, "lon": 0.0 },      // ← stubbed on client
  "weather":  { "temperature": 0, "humidity": 0 } // ← stubbed
}
```

### Chat response
```json
{
  "chatId": "651abc...",
  "message": "AI response…",
  "context": {
    "currentTopic": "plant health",
    "lastContext": "previous AI response",
    "identifiedIssues": ["yellow leaf spots"],
    "suggestedSolutions": ["fungicide application"]
  },
  "title": "Tomato leaf issue",
  "history": [...],
  "limitInfo": { "dailyLimit": 5, "remainingMessages": 4, "resetsAt": "..." }
}
```

## 5. Current system prompt (abridged)

Reassembled from `ai.service.js` L587–632. Rebuilt per turn:

```
You are an agricultural expert AI assistant specialized in farming...

Previous conversation summary:
- User: [msg1]
  AI: [summary of response1]
- ... (up to 5 recent agri-related turns)

Current context:
- Current topic: plant health
- Identified issues: yellow leaf spots
- Suggested solutions: fungicide

Environmental context:
- Location: 0.0, 0.0
- Temperature: 0°C
- Humidity: 0%

Important instructions:
1. ALWAYS reference previous messages...
2. Provide detailed, actionable agricultural advice...
(8 instructions)

Focus areas:
- Crop cultivation, disease ID, pest management, soil, irrigation...
(8 bullets)

IMPORTANT: Respond entirely in English
```

Then the last **15 messages** of the chat are appended as `user`/`assistant` turns.

### Problems with the current prompt
1. Rebuilt **byte-by-byte different** per turn → no prompt caching possible.
2. Carries 8+ generic instruction bullets every turn (~300 tokens wasted).
3. "Environmental context" is always `0,0` / `0°C` / `0%` because client stubs it.
4. Nothing about the farmer themselves — crops, land, experience are unknown to the model.
5. Language instruction is appended at the very end — models sometimes ignore it after the conversation window fills up.
6. "Previous conversation summary" is actually the last 5 *agri* turns re-listed verbatim — double-counted tokens since the last 15 turns follow anyway.

## 6. Current chat schema gaps

`AIChat.metadata` already has `preferredLanguage`, `location`, `weather` — but weather is only ever the 2-value client stub. There's no:
- Farm-profile snapshot at chat creation time
- Chat-level token usage / cost record
- Summary field for older turns (everything kept verbatim)
- Fingerprint / cache key for the assembled prompt

## 7. Current mobile-app gaps

- `ai_chat_controller.dart` sends `location: {0.0, 0.0}` and `weather: {0, 0}` — never populated from `weather_service.dart` or geolocator.
- `signup_screen.dart` collects only `name, firstName, lastName, phoneNo, image`. No farm profile UI.
- `user_model.dart` has no `FarmProfile` field.
- No "Edit my farm" screen. Profile screen displays `experience`, `subscription` — no crop list.
- Multi-lingual UI is good; language code is already threaded through to the AI request via `LanguageService`.

## 8. Dependencies to remove/add

### Remove (after rollout)
- `groq-sdk` — chat path
- `@google/generative-ai` — vision path

### Add
- `openai` (v4.x) — chat, vision, embeddings
- `gpt-tokenizer` or `tiktoken` — client-side token counting for budget enforcement
- Weather client library — `axios` is enough; no new dep. (Using Open-Meteo REST.)

### Keep
- `redis` / `ioredis` — extended for context-layer cache
- `express-rate-limit` + `rate-limit-redis`
- JWT/gateway auth plumbing

## 9. Existing strengths to preserve

- **Modular provider layer** — `ai.service.js` is already the only place that speaks to external AIs. One file to refactor.
- **Subscription-based daily quota** — works, cached in Redis, keep as-is.
- **Key rotation for Gemini** — the pattern (comma-separated env var + round-robin on quota errors) is a good template for OpenAI keys.
- **Circuit breaker for vision** — extend to OpenAI.
- **Multi-language system prompt directive** — move into the "core" layer of the tree but keep the directive.
- **AIChat.metadata.preferredLanguage** — already captured; no change.

## 10. What this tells us about scope

- Backend refactor is mostly concentrated in **3 files** (`ai.service.js`, `ai.controller.js`, `ai-chat.model.js`) + **1 new module** (`ai-providers/openai.provider.js`) + **2 new models** (`FarmProfile`, `WeatherSnapshot`) + **1 new service** (`weather.service.js`).
- Mobile-app work is bigger in *UX* terms — multi-step onboarding + edit-profile screen + real weather plumbing — but doesn't touch the chat screen much (request/response shape stays stable).
- Gateway changes are zero. Paths unchanged.
- No change to subscription service.
