# 06 — Backend: Provider Layer & OpenAI Implementation

This doc covers the message-svc refactor: the **provider interface**, the **ProviderFactory** that dispatches by the admin-active `AiProviderConfig`, the **OpenAI** implementation of that interface, rewiring the AI controller/service, streaming, cost tracking, retries, multi-key rotation, and the image pipeline. The **Google Vertex AI implementation** of the same interface is its own doc: [06b-google-vertex-provider.md](06b-google-vertex-provider.md). The context tree (doc 07), prompt engineering (doc 09), and admin-panel management (doc 13) are separate because they're big topics on their own; this doc assumes those as black boxes.

## 1. New module layout

```
Backend-JS/message-svc/src/
├── ai-providers/
│   ├── provider.interface.js         NEW: adapter contract
│   ├── factory.js                    NEW: resolves active provider
│   ├── openai.provider.js            NEW: OpenAI implementation
│   ├── vertex.provider.js            NEW: Google Vertex AI (doc 06b)
│   ├── vertex-adapters.js            NEW: message/image format converters
│   └── __fixtures__/                 NEW: recorded responses for tests
├── services/
│   ├── ai.service.js                 REWRITTEN (provider-agnostic orchestrator)
│   ├── ai-config.service.js          NEW: reads AiProviderConfig, Redis-cached
│   ├── context-tree.service.js       NEW: see doc 07
│   ├── weather.service.js            NEW: see doc 08
│   ├── farm-profile.client.js        NEW: HTTP+Redis client to main-service
│   ├── intent-router.service.js      NEW: cheap classifier
│   ├── chat-summarizer.service.js    NEW: rolling summary
│   ├── token-budget.service.js       NEW: tiktoken-based pruner
│   ├── token-usage.service.js        NEW: usage accounting + cost (per provider)
│   ├── message-limit.service.js      UNCHANGED (daily quota)
│   └── subscription.service.js       UNCHANGED
├── models/
│   ├── ai-chat.model.js              EXTENDED (see doc 04)
│   └── weather-snapshot.model.js     NEW
├── controllers/
│   └── ai.controller.js              TRIMMED (thinner; delegates to services)
├── routes/
│   └── ai.routes.js                  PATCHED (+ /weather, + SSE)
└── utils/
    ├── sse.js                        NEW: SSE helpers (normalized event shape)
    ├── secret-box.js                 NEW: AES-256-GCM encrypt/decrypt
    └── cost-table.js                 NEW: $/1M tokens by model (both providers)
```

## 2. The provider interface

`ai-providers/provider.interface.js` — every provider implements this contract. OpenAI and Vertex do; future providers (Anthropic, Bedrock, …) can drop in without touching callers.

```js
// Every provider exports an object with these methods.
// Inputs/outputs are normalized to OpenAI-style shapes so the controller
// doesn't branch on provider.
module.exports.ProviderInterface = {
  async streamChat({ messages, model, userId, maxTokens, temperature, abortSignal }) {},
  async chat({ messages, model, userId, maxTokens, temperature }) {},          // non-streaming
  async analyzeImages({ messages, imageUrls, model, userId }) {},
  async embed({ input, model }) {},
  async countTokens({ messages, model }) {},                                   // offline count
  async validate() {},                                                         // used by admin /validate endpoint
};
```

### ProviderFactory

`ai-providers/factory.js`
```js
const AiConfig = require("../services/ai-config.service");
const openai = require("./openai.provider");
const vertex = require("./vertex.provider");

async function active() {
  // 1. Per-user override (internal beta)
  //    Lookup uses a configId, not a provider string, so future providers work.
  //    (Handled upstream before calling factory for routine turns.)

  // 2. Kill switches
  const cfg = await AiConfig.getActive();
  if (await killswitchActive(cfg.provider)) {
    if (cfg.autoFallback) return await active({ skip: cfg.provider });
    throw ProviderUnavailable(cfg.provider);
  }

  switch (cfg.provider) {
    case "openai": return openai.bind(cfg);
    case "vertex": return vertex.bind(cfg);
    default: throw new Error(`Unknown provider: ${cfg.provider}`);
  }
}

module.exports = { active };
```

Each provider module's `bind(cfg)` returns an instance that closes over the decrypted credentials + model selections. The instance exposes the `ProviderInterface` methods. The factory is O(1) steady-state (Redis cache) and refetches only on pub/sub invalidation.

## 3. OpenAI provider

`ai-providers/openai.provider.js` (abbreviated — full implementation in PR)

Credentials come from the active `AiProviderConfig` (doc 13), decrypted by `ai-config.service`. The env vars are only a bootstrap fallback for cold-start when the DB is empty (see M5).

```js
const OpenAI = require("openai");
const { encode } = require("gpt-tokenizer/model/gpt-4o");  // good enough approx for gpt-4.1-mini
const { costFor } = require("../utils/cost-table");
const logger = require("../utils/logger");

// Per-config instance. Returned by the factory.
function bind(cfg) {
  const keys = cfg.credentials.apiKeys; // decrypted array
  if (!keys?.length) throw new Error("OpenAI config has no API keys");
  let keyIndex = 0;

  const client = () => new OpenAI({
    apiKey: keys[keyIndex],
    organization: cfg.extras?.orgId,
    baseURL: cfg.extras?.baseUrl,      // optional (for proxies)
    timeout: 60_000,
    maxRetries: 0, // we do our own retries
  });

  // (rest of the methods below close over `client`, `keys`, `keyIndex`, `cfg`)

  const RETRYABLE = new Set([408, 409, 429, 500, 502, 503, 504]);

  async function withRetry(fn, { max = 4 } = {}) {
    let lastErr;
    for (let attempt = 0; attempt < max; attempt++) {
      try {
        return await fn(client());
      } catch (err) {
        lastErr = err;
        const status = err?.status ?? err?.response?.status;
        if (!RETRYABLE.has(status)) throw err;
        // Rotate key on quota errors
        if (status === 429) { keyIndex = (keyIndex + 1) % keys.length; }
        const backoff = Math.min(10_000, (2 ** attempt) * 500 + Math.random() * 250);
        await new Promise(r => setTimeout(r, backoff));
      }
    }
    throw lastErr;
  }

  const streamChat = async ({ messages, model = cfg.models.chat, userId, maxTokens = 800, temperature = 0.4, abortSignal }) =>
    withRetry(async (c) => c.chat.completions.create({
      model, messages, stream: true,
      max_tokens: maxTokens, temperature,
      user: userId,
      stream_options: { include_usage: true },
    }, { signal: abortSignal }));

  const chat = async (opts) => {
    const { model = cfg.models.chat, messages, userId, maxTokens = 400 } = opts;
    return withRetry(async (c) => c.chat.completions.create({
      model, messages, max_tokens: maxTokens, temperature: opts.temperature ?? 0.3, user: userId,
    }));
  };

  const analyzeImages = async ({ messages, imageUrls, userId, model = cfg.models.vision }) => {
    const m = [...messages];
    const last = m.pop();
    const parts = [
      { type: "text", text: last.content || "Analyze the attached crop image(s)." },
      ...imageUrls.map(url => ({ type: "image_url", image_url: { url, detail: "low" } })),
    ];
    m.push({ role: "user", content: parts });
    return withRetry(async (c) => c.chat.completions.create({
      model, messages: m, max_tokens: 900, temperature: 0.2, user: userId,
    }));
  };

  const embed = async ({ input, model = cfg.models.embed }) =>
    withRetry(async (c) => c.embeddings.create({ model, input }));

  const countTokens = ({ messages }) => {
    let total = 0;
    for (const m of messages) {
      total += 4;
      if (typeof m.content === "string") total += encode(m.content).length;
      else for (const part of m.content) if (part.type === "text") total += encode(part.text).length;
    }
    return total + 2;
  };

  const validate = async () => {
    const c = client();
    await c.models.list({ query: { limit: 1 } });  // light-weight ping
    return { ok: true };
  };

  return { streamChat, chat, analyzeImages, embed, countTokens, validate, provider: "openai" };
}

module.exports = { bind };
```

Notes:
- **Key rotation only on 429** (quota exhausted for that key). Other errors stay on the same key so they surface.
- `stream_options.include_usage: true` is required to get token counts with streaming.
- `user: userId` goes to OpenAI for abuse monitoring — they dedupe per user.
- Images are **URL-referenced**, not uploaded as base64 — S3 URL straight from our presigner. Saves egress.
- `detail: "low"` on images halves image-token cost (~85 tokens vs ~170 per image at high). Enough for plant disease screening; we can escalate to `high` if quality issues reported.

## 4. Cost table

`utils/cost-table.js`
```js
// Prices per 1M tokens, as of Jan 2026. Keep centralized.
// Update quarterly; provider moves are logged in PROMPT_VERSION.md.
const PRICES = {
  // OpenAI
  "gpt-4.1-mini":           { input: 0.15, cachedInput: 0.075, output: 0.60 },
  "gpt-4.1":                { input: 2.00, cachedInput: 1.00,  output: 8.00 },
  "gpt-4o-mini":            { input: 0.15, cachedInput: 0.075, output: 0.60 },
  "text-embedding-3-small": { input: 0.02, output: 0 },
  // Google Vertex AI
  "gemini-2.5-flash":       { input: 0.075, cachedInput: 0.01875, output: 0.30 },
  "gemini-2.5-pro":         { input: 1.25,  cachedInput: 0.31,    output: 5.00 },
  "text-embedding-005":     { input: 0.025, output: 0 },
};

exports.costFor = function (model, usage) {
  const p = PRICES[model]; if (!p) return 0;
  const prompt = usage.prompt_tokens ?? 0;
  const cached = usage.prompt_tokens_details?.cached_tokens ?? 0;
  const completion = usage.completion_tokens ?? 0;
  return (
    ((prompt - cached) * p.input) / 1_000_000 +
    (cached * p.cachedInput) / 1_000_000 +
    (completion * p.output) / 1_000_000
  );
};
```

## 5. AI controller (target)

`controllers/ai.controller.js` — `sendMessage` handler reduced to orchestration. Note the controller never names a provider — `ProviderFactory.active()` handles that.

```js
const { active: activeProvider } = require("../ai-providers/factory");

exports.sendMessage = asyncHandler(async (req, res) => {
  const { userId } = req.user;
  const { chatId, message, preferredLanguage } = req.body;

  // 1. quota
  const quota = await MessageLimitService.check(userId);
  if (!quota.canProceed) return res.status(429).json({ code: "DAILY_LIMIT", ...quota });

  // 2. load or create chat
  const chat = chatId
    ? await AIChat.findOne({ _id: chatId, userId, isActive: true })
    : await AIChat.create({ userId, userName: req.user.name, preferredLanguage });
  if (!chat) return res.status(404).json({ code: "CHAT_NOT_FOUND" });

  // 3. resolve provider (O(1) steady-state; cached)
  const provider = await activeProvider();

  // 4. intent route (cheap, sync)
  const routing = await IntentRouter.classify(message, {
    previousTopic: chat.context.currentTopic,
    provider,                     // allows the LLM fallback to use the same provider
  });

  // 5. assemble context tree
  const built = await ContextTreeService.assemble({
    userId, chat, message, routing,
    preferredLanguage: preferredLanguage || chat.metadata.preferredLanguage || "en",
    provider,                     // so tree-service can ask the provider for countTokens
  });

  // 6. enforce token budget
  const fitted = TokenBudget.fit(built, { maxInputTokens: 2500 });

  // 7. stream
  const wantsSSE = req.headers.accept?.includes("text/event-stream");
  if (wantsSSE) return streamAndPersist(res, chat, fitted, routing, userId, message, provider);
  return nonStreamAndPersist(res, chat, fitted, routing, userId, message, provider);
});
```

The helpers `streamAndPersist` / `nonStreamAndPersist` both call `provider.streamChat` / `provider.chat` — no provider branching ever appears in the controller.

### Stream normalization

OpenAI emits SSE chunks with `choices[0].delta.content`. Vertex emits gRPC stream chunks with `candidates[0].content.parts[].text`. The respective provider modules normalize to a single shape at the boundary:

```js
// Normalized event emitted by any provider's streamChat async iterator
{ type: "delta", text: "...", raw?: <original> }
{ type: "done",  usage: { prompt_tokens, cached_tokens, completion_tokens } }
{ type: "error", code: "...", message: "..." }
```

`utils/sse.js` wraps this into `data: {json}\n\n` frames going out to the client. The mobile SSE client (doc 10) consumes the same format regardless of active provider.

Streaming helper:
```js
async function streamAndPersist(res, chat, fitted, routing, userId, userMessage) {
  SSE.open(res);
  const stream = await OpenAI.streamChat({
    messages: fitted.messages,
    model: fitted.model,
    userId,
    maxTokens: fitted.maxOutputTokens,
    abortSignal: req.abortController?.signal,
  });

  let full = ""; let usage = null;
  for await (const chunk of stream) {
    if (chunk.usage) usage = chunk.usage;
    const delta = chunk.choices?.[0]?.delta?.content;
    if (delta) { full += delta; SSE.data(res, { type: "delta", text: delta }); }
  }

  // Persist both turns + usage
  chat.messages.push({ role: "user", content: userMessage });
  chat.messages.push({ role: "assistant", content: full, model: fitted.model, tokenUsage: usage });
  chat.usage.totalPromptTokens     += usage?.prompt_tokens ?? 0;
  chat.usage.totalCachedTokens     += usage?.prompt_tokens_details?.cached_tokens ?? 0;
  chat.usage.totalCompletionTokens += usage?.completion_tokens ?? 0;
  chat.usage.estimatedUsdCost      += costFor(fitted.model, usage || {});
  chat.context = ContextExtractor.update(chat.context, full, routing);
  await chat.save();
  MessageLimitService.increment(userId); // fire-and-forget
  TokenUsage.recordTurn({ userId, chatId: chat._id, model: fitted.model, usage });
  MaybeTriggerSummary(chat);

  SSE.data(res, { type: "done", chatId: chat._id, usage });
  SSE.close(res);
}
```

Non-streaming path is the same but buffers the response and sends one JSON.

## 6. Intent router (cheap)

`services/intent-router.service.js`

Two-stage:
1. **Regex/keyword pass** (instant, zero cost):
   - "weather|rain|temperature|forecast" → intent `weather`, no crop filter.
   - "disease|spots|wilt|pest|bug|insect|fungus" + crop name → intent `plant-health`, cropsOfInterest = [matched crop].
   - "fertili[sz]er|nutrient|urea|dap|nitrogen|NPK" → intent `nutrition`.
   - "irrig|water|drip|moisture|drought" → intent `irrigation`.
   - "market|price|mandi|sell" → intent `market`.
   - crop-name-only messages ("about tomato") → intent `crop-general`, crop filter.
   - Otherwise → intent `general`.
2. **LLM fallback** (only if regex yielded `general` *and* user has >3 crops — it's worth distinguishing). Uses `gpt-4o-mini` with a 40-token prompt returning one word:
   ```
   Return ONE label from: weather, plant-health, nutrition, irrigation, market, crop-general, general.
   User: "<msg>"
   ```
   Cost negligible (~20 input tokens + 5 output = $0.00002/call). Cached on message hash for 24h.

Output:
```js
{
  intent: "plant-health",
  cropsOfInterest: ["tomato"],   // cropId or cropName
  needsWeather: true,            // intent ∈ {weather, plant-health, irrigation, crop-general}
  needsCropBlock: true,
  lowCostOk: true                // allows downgrade to smaller model / fewer layers
}
```

Downstream, the context-tree service uses these flags to decide which layers to include.

## 7. Image pipeline

Reused flow with two changes:
- **No base64 upload to the provider.** Client uploads image to S3 via existing presigned-url endpoint → gets a temporary URL (24h) → sends URL in `/api/ai/analyze-image` request. Our backend simply forwards URL to the active provider.
- **Multi-image:** up to 5 URLs in one call. Both OpenAI and Vertex support native multi-image vision.

Prompt assembly is identical — context tree + user turn with `content: [text, image_url, …]`. Temperature 0.2 (determinism > creativity for diagnosis). The provider module does the OpenAI-vs-Vertex format conversion; the controller doesn't see it.

Validation kept server-side: S3 URL must match our bucket (anti-SSRF by sending providers arbitrary URLs). The same check runs regardless of active provider.

Note for Vertex: if the S3 URL is presigned (with `?X-Amz-…` query), Vertex may not fetch it reliably. `vertex-adapters.js` falls back to downloading server-side and passing `inlineData` base64 for presigned URLs. Non-presigned public URLs are passed as `fileData` directly.

## 8. Chat summarization

`services/chat-summarizer.service.js`

Triggered when a chat crosses **12 messages since last summary**. Runs async, not blocking the turn.

Algorithm:
1. Take messages `[summarizedUpTo .. n-6]` — leaves last 6 turns raw in the window.
2. Feed to `gpt-4.1-mini` with prompt:
   ```
   Summarize this farmer-AI conversation for future reference in ≤120 words. Capture:
   - crop/location/season context mentioned
   - symptoms/issues raised
   - recommendations given
   - any outstanding questions
   (no preamble; write as compact bullet list)
   ```
3. Concatenate with existing `summary.text` (if any) then run one more pass if combined > 200 tokens.
4. Save `chat.summary = { text, summarizedUpTo: n-6, summaryTokens }`.
5. Invalidate `ctx-layer:summary:{chatId}:*` Redis keys.

Costs ~$0.0002 per summarization. With 2k chats/day each summarizing twice: ~$0.80/day.

## 9. Token budget enforcement

`services/token-budget.service.js`

Called after context tree assembly. Given `{ layers[], currentTurn }`, computes:
```
budget = maxInputTokens (default 2500)
used   = sum(layer.tokenEst) + countTokens(currentTurn)
```

If `used > budget`:
1. Drop optional layers in priority order (see doc 07 §5): `knowledge-hints → market-context → crop-calendar-block → old-summary-detail`.
2. If still over, compress `chat-summary` layer (run summarizer in-line with tighter cap).
3. If still over (very rare), truncate the oldest `messagesWindow` turns.
4. If still over, bump to `gpt-4.1` model (8k+ context) — logged as `budget_escalation`.

We never silently drop the user's current message.

## 10. Rate limiting & quotas

Unchanged shape:
- Per-route (express-rate-limit with Redis store) — keeping current caps.
- Per-user subscription quota — message-limit.service untouched.
- New **per-day $ cap per user**: `ai:daily-cost:{userId}:{yyyy-mm-dd}` → increments per turn. Hard-cap at 50 × subscription daily limit × avg cost (configurable). Returns 429 `{ code: "DAILY_COST_CAP" }` if hit.
- New **per-minute $ cap across service**: bucket `ai:global-cost:{yyyy-mm-dd-hh-mm}` for blast-radius protection. Default $10/min.

## 11. Observability

Every turn logs (info level):
```json
{
  "event": "ai.turn",
  "userId": "hashed",
  "chatId": "...",
  "model": "gpt-4.1-mini",
  "intent": "plant-health",
  "layersUsed": ["core","profile","weather-7d","crop-tomato","summary","window"],
  "tokens": { "prompt": 843, "cached": 512, "completion": 294 },
  "cacheHitRate": 0.607,
  "costUsd": 0.00031,
  "latencyMs": { "firstToken": 810, "total": 3120 }
}
```

Prometheus metrics:
- `ai_turn_duration_seconds{model,intent,phase}` (phase = firstToken/total)
- `ai_tokens_total{model,kind=prompt|cached|completion}`
- `ai_cost_usd_total{model}`
- `ai_cache_hit_ratio{layer}`
- `ai_turn_errors_total{model,reason}`

Alerts:
- Cost > 1.5 × 7-day moving avg for 2h → page.
- Cache hit rate < 40% sustained 1h → page.
- 5xx error rate > 3% over 10m → page.

## 12. Environment variables

Note: **primary** AI config lives in MongoDB (`AiProviderConfig`, admin-managed). Env vars below are for bootstrap, infra defaults, and non-credential knobs.

Added:
```
# Mode & cost controls
AI_PROVIDER_MODE=registry               # legacy | registry | shadow (retired post-cutover)
AI_DAILY_COST_CAP_USD_PER_USER=0.50
AI_GLOBAL_COST_CAP_USD_PER_MINUTE=10
AI_MAX_INPUT_TOKENS=2500
AI_MAX_OUTPUT_TOKENS=800

# Credential encryption (master key for AES-256-GCM wrap of AiProviderConfig.credentials)
AI_CONFIG_KEK_ALIAS=gcp-kms://projects/.../keyRings/.../cryptoKeys/krishi-ai-config   # preferred
AI_CONFIG_MASTER_KEY=                   # fallback: base64 32-byte key for staging/dev only

# Bootstrap (only used by M5 migration if no AiProviderConfig exists yet)
OPENAI_API_KEYS=sk-...,sk-...
OPENAI_CHAT_MODEL=gpt-4.1-mini
OPENAI_VISION_MODEL=gpt-4o-mini
OPENAI_EMBED_MODEL=text-embedding-3-small

# Vertex bootstrap defaults (only if admin hasn't configured DB row yet)
VERTEX_DEFAULT_PROJECT=
VERTEX_DEFAULT_LOCATION=asia-south1

# Weather
WEATHER_PROVIDER=open-meteo             # open-meteo | openweather
OPENWEATHER_API_KEY=                    # only if above=openweather

# Inter-service
MAIN_SERVICE_URL=http://main-service:3000
```

Retired (removed after rollout):
```
GROQ_API_KEY
GEMINI_API_KEY
```

## 13. Testing

- Unit: each service under `services/__tests__/*` with mocked provider.
- Contract: `ai-providers/__fixtures__/` holds recorded OpenAI responses; replay in tests with nock.
- Integration: docker-compose test stack (mongo + redis + message-svc + main-service) runs 10 golden-path scenarios (onboarded user, no profile, Hindi, image turn, rate-limit, budget-overflow, …).
- Load: k6 script simulating 100 concurrent users, 20 turns each. Verify cache hit >55 %, cost within projection, P95 latency <4.5s.
- Shadow: 1 week of `AI_PROVIDER=shadow` traffic on 10 % of users before cutover.

See [11-migration-rollout-observability.md](11-migration-rollout-observability.md) for rollout specifics.
