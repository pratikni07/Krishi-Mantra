# 06b — Google Vertex AI Provider

Companion to doc 06. Defines the second supported provider (Google Cloud Vertex AI) behind the same `ProviderInterface`, so the admin-configurable switch (doc 13) can flip between OpenAI and Vertex without any route/controller changes.

## 1. Models used

| Capability | Vertex model | OpenAI equivalent |
|-----------|--------------|-------------------|
| Chat (fast/cheap) | `gemini-2.5-flash` | `gpt-4.1-mini` |
| Chat (higher quality) | `gemini-2.5-pro` | `gpt-4.1` |
| Vision (single + multi-image) | `gemini-2.5-flash` (native multimodal) | `gpt-4o-mini` |
| Text embeddings | `text-embedding-005` | `text-embedding-3-small` |

Rationale: 2.5-flash is vision-capable and cheap; we avoid maintaining separate chat/vision SKUs.

## 2. Auth model

Vertex has no plain API key. Two supported credential types, both stored encrypted in `AiProviderConfig.credentials` (doc 04):

1. **Service-Account JSON** (preferred for simplicity):
   - Admin uploads a service-account key JSON (roles: `roles/aiplatform.user`).
   - Stored as `credentials.type = "service_account_json"`, `credentials.payload` = AES-256-GCM encrypted JSON.
2. **Workload Identity Federation** (preferred when Krishi-Mantra is already on GCP):
   - Admin provides provider id, audience, and impersonated SA email.
   - Tokens minted by the standard Google auth library via environment.

The provider module exposes a single `getAuthClient()` that returns a `GoogleAuth`-backed client regardless of credential type. Callers don't care.

Credential validation happens at save time (admin panel) by making one low-cost call (`models.list`). Stored only if validation passes.

## 3. Provider implementation

`ai-providers/vertex.provider.js` — same interface as `openai.provider.js`.

```js
const { VertexAI } = require("@google-cloud/vertexai");
const { GoogleAuth } = require("google-auth-library");
const { decryptJSON } = require("../utils/secret-box");
const { getActiveProviderConfig } = require("../services/ai-config.service");

// Cached client per (project, location, credFingerprint)
const clientCache = new Map();

async function clientFor(cfg) {
  const key = `${cfg.project}|${cfg.location}|${cfg.credFingerprint}`;
  if (clientCache.has(key)) return clientCache.get(key);

  const creds = await resolveCreds(cfg);   // returns GoogleAuth instance
  const vertex = new VertexAI({
    project:  cfg.project,
    location: cfg.location,                // e.g. "us-central1" or "asia-south1"
    googleAuthOptions: creds.options,
  });
  clientCache.set(key, vertex);
  return vertex;
}

exports.streamChat = async function ({ messages, model, userId, maxTokens = 800, temperature = 0.4, abortSignal }) {
  const cfg = await getActiveProviderConfig();   // Redis cached
  const vertex = await clientFor(cfg);
  const generative = vertex.getGenerativeModel({
    model: model || cfg.chatModel || "gemini-2.5-flash",
    systemInstruction: extractSystemInstruction(messages),
    generationConfig: { maxOutputTokens: maxTokens, temperature },
  });
  return withRetry(() => generative.generateContentStream({
    contents: toVertexContents(messages),
  }), { max: 4, abortSignal });
};
```

Key shape adapters (`toVertexContents` / `extractSystemInstruction`):
- OpenAI uses `{role: "system"|"user"|"assistant", content: string|parts[]}`.
- Vertex uses `systemInstruction` separately, and `contents = [{role: "user"|"model", parts: [{text|inlineData|fileData}]}]`.
- System message from our tree (L0–L4) becomes `systemInstruction`.
- All other messages collapse: `assistant → model`, `user → user`.
- Image parts: our `image_url` becomes Vertex `fileData: { fileUri: s3Url, mimeType }` (Vertex can fetch public S3 URLs). For presigned URLs, fetch and pass `inlineData` base64 as fallback.

## 4. Prompt-cache equivalent on Vertex

Vertex supports **Context Caching** — cached content is created once, referenced by name in subsequent requests. Differs from OpenAI's automatic prefix cache, so our adapter must do explicit work:

1. When `streamChat` is called, compute a `prefixFingerprint` over layers L0..L4 (we already have this from the context-tree service).
2. Look up `vertex:ctx-cache:{fp}` in Redis → Vertex cached-content resource name (`projects/.../cachedContents/...`).
3. If absent: call `cachedContents.create({ contents, ttl })` with 1h TTL, store the returned name.
4. Pass `cachedContent: name` on `generateContentStream`. Vertex billing gives a discount on the cached portion.

Stampede protection: `redis.set(..., "NX", "EX", 30)` lock while creating, short-retry if locked.

Important minimum: cached content must be ≥ 32k tokens on some tiers; **our typical prefix is only ~600 tokens, so this optimization only applies to heavy image chats with large multi-layer context**. For routine chat, skip the cache (the overhead exceeds the saving).

Policy in code:
```js
const shouldCacheOnVertex = prefixTokens >= 4096;
```

So we opportunistically cache only when it pays off. Standard turns pay full price on Vertex but still benefit from our Redis layer-level caches (which remain provider-neutral).

## 5. Retry / error handling

`withRetry` wrapper mirrors the OpenAI one but maps different error shapes:
- `code: 8` (RESOURCE_EXHAUSTED) → retry with backoff, rotate to next region if region fallback configured.
- `code: 14` (UNAVAILABLE) → retry.
- `code: 4` (DEADLINE_EXCEEDED) → retry once then fail.
- `code: 16` (UNAUTHENTICATED) → **do not retry** → mark `AiProviderConfig.status = "credential_invalid"`, auto-pause via kill switch (see §8), page oncall.
- Streaming connection reset → retry once from scratch.

Region fallback: admin can configure `regions: ["asia-south1", "us-central1"]`; retry on quota escalates to the next region.

## 6. Cost table entry

`utils/cost-table.js` extended:
```js
PRICES["gemini-2.5-flash"] = { input: 0.075, cachedInput: 0.01875, output: 0.30 };  // $/1M, update centrally
PRICES["gemini-2.5-pro"]   = { input: 1.25,  cachedInput: 0.31,    output: 5.00 };
PRICES["text-embedding-005"] = { input: 0.025, output: 0 };
```

Cached-input discount on Vertex ≈ 75% off (higher than OpenAI's 50%) — when we can use it, it's strong.

## 7. Differences that callers don't see

The `ai.controller` + `context-tree.service` code is provider-agnostic. Only these modules know about Vertex:

- `ai-providers/vertex.provider.js`
- `ai-providers/vertex-adapters.js` (message/image format converters)
- `services/ai-config.service.js` (resolves active provider → picks module)

Every other layer of the code references the abstract:
```js
const provider = await AiProviderFactory.active();
await provider.streamChat({ ... });
```

## 8. Health + kill-switch

Added Redis keys:
- `ai:killswitch:vertex = "1"` → forces the factory to pick the *other* provider if fallback configured, else hard-503.
- `vertex:health` → last check timestamp, last error. Checked by a 60s cron.
- `ai-config:active-provider` → current provider id (refreshed via pub/sub on admin write).

If active-provider = `vertex` and `vertex:health` is red for 5 min:
- Automatic fallback to `openai` **only if** admin enabled `autoFallback: true` on the config. Otherwise surface 503.
- Paged alert either way.

## 9. Safety & content filters

Vertex has built-in safety filters (HARM_CATEGORY_* blocks). Agricultural topics rarely hit them, but we set them to `BLOCK_ONLY_HIGH` across all four categories so benign advice isn't accidentally blocked. Exposed as `safetySettings` in `ai-config.service` so admin can dial per deployment if needed.

OpenAI has no equivalent mandatory filter — we apply the same light content policy on its path via our own pre-flight regex in `intent-router.service` (doc 06 §6 already).

## 10. Observability

Same metrics schema as OpenAI; provider label added:
- `ai_turn_duration_seconds{provider="vertex"|"openai", model, intent, phase}`
- `ai_tokens_total{provider, model, kind}`
- `ai_cost_usd_total{provider, model}`
- `ai_cache_hit_ratio{provider, layer}`
- `ai_provider_error_total{provider, reason}`

Dashboards (doc 11 §7) will show side-by-side OpenAI vs Vertex when both have recent traffic (e.g. during a switch window).

## 11. Environment variables (optional defaults)

Only used if admin hasn't set a config yet. In normal operation, credentials come from the DB.

```
VERTEX_DEFAULT_PROJECT=
VERTEX_DEFAULT_LOCATION=asia-south1
VERTEX_DEFAULT_CHAT_MODEL=gemini-2.5-flash
VERTEX_DEFAULT_VISION_MODEL=gemini-2.5-flash
VERTEX_DEFAULT_EMBED_MODEL=text-embedding-005
```

## 12. Implementation checklist

- [ ] `npm i @google-cloud/vertexai google-auth-library`
- [ ] `ai-providers/vertex.provider.js`
- [ ] `ai-providers/vertex-adapters.js` (message/image converters)
- [ ] `utils/secret-box.js` (AES-256-GCM encrypt/decrypt with key from KMS or env)
- [ ] Cost table entries
- [ ] Vertex fixtures + nock-based tests
- [ ] Validate-creds helper for admin panel save flow
- [ ] Region-fallback logic
- [ ] Vertex-specific metrics labels in exporter
- [ ] Docs for ops: how to rotate a service-account key
