# 13 — Admin: AI Provider Management

The admin panel is where ops picks which AI provider Krishi AI uses, pastes/uploads credentials, and flips the switch for all users. This doc specifies the UI, the main-service API, the storage/encryption model, and the runtime switchover behavior.

## 1. What the admin can do

From **Admin Panel → Settings → AI Provider**:

1. See the currently-active provider and a summary of its config (model, region, last health check).
2. Create/edit configurations for each supported provider:
   - **OpenAI** — API key(s), chat model, vision model, embedding model, org id (optional).
   - **Google Vertex AI** — project, region(s), credentials (Service-Account JSON upload OR WIF), chat model, vision model, embedding model.
3. Click **Validate credentials** — back-end makes one low-cost call and reports `OK` / `error reason`.
4. Set the **active provider** — atomic switch; all traffic uses the new provider from the next request.
5. Toggle **auto-fallback** — if active provider goes red, automatically fall through to the other (if configured and healthy).
6. Toggle **per-feature overrides** (optional, phase 2) — e.g. "use Vertex for vision, OpenAI for text". Default off.
7. View cost/usage for current provider (last 7 / 30 days).
8. View change history ("switched from OpenAI to Vertex on 2026-05-03 by admin@…").

**Only one provider is active at any given time** (except during auto-fallback). This matches the requirement: pick one, apply to all users.

## 2. Data model

Already defined in doc 04 §1a. Summary:

`AiProviderConfig` (one doc per provider)
```
_id
provider:        "openai" | "vertex"
displayName:     string
models:          { chat, vision, embed }
credentials: {
  type:          "api_key" | "service_account_json" | "wif"
  payload:       <AES-256-GCM encrypted blob>
  fingerprint:   sha256(plaintext)   // never reveals content, but lets us detect re-upload
  lastRotatedAt: Date
}
extras: { project?, location?, regions?, orgId?, safetySettings? ... }
status:          "unvalidated" | "valid" | "credential_invalid" | "error"
lastValidatedAt: Date
autoFallback:    boolean
isActive:        boolean     // exactly one doc has true
createdBy, updatedBy, createdAt, updatedAt
```

Single-active constraint enforced by a partial unique index:
```js
AiProviderConfigSchema.index({ isActive: 1 }, { unique: true, partialFilterExpression: { isActive: true } });
```

All mutations go through the `AiProviderConfig` controller which uses a Mongo session to atomically unset the old active and set the new.

## 3. Encryption

Credentials must never land in plaintext on disk or in logs.

- `utils/secret-box.js` wraps Node's `crypto` `aes-256-gcm`:
  - `encrypt(plaintext, aad) → { iv, tag, ciphertext }` all base64.
  - `decrypt({ iv, tag, ciphertext }, aad)`.
- AAD binds the ciphertext to `provider + createdAt` so a blob can't be swapped between configs.
- Key source (in priority order):
  1. GCP KMS or AWS KMS (prod) — key alias in env `AI_CONFIG_KEK_ALIAS`.
  2. `AI_CONFIG_MASTER_KEY` env (base64, 32 bytes) — fallback for staging/dev.
- Key rotation plan: doc a quarterly rotation — re-encrypt all rows via a script that decrypts with old key and re-encrypts with new.

On read:
- Never return plaintext to the admin panel. API returns `credentials: { fingerprint, lastRotatedAt, type }` only.
- The "Validate" action can be re-run anytime; plaintext stays server-side.

## 4. API surface (main-service)

Base path `/api/admin/ai-provider`. Guarded by existing admin JWT middleware (accountType = admin).

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/` | list all configs (no credentials) |
| GET | `/:id` | single config (no credentials) |
| GET | `/active` | returns active provider id + display + health |
| POST | `/openai` | create/update OpenAI config (accepts `apiKeys[]`, `models`, `orgId`) |
| POST | `/vertex` | create/update Vertex config (multipart if SA-JSON upload) |
| POST | `/:id/validate` | fires a real credential check → returns `{ ok, error? }` |
| POST | `/:id/activate` | atomic: set `isActive=true`, others false; clears Redis `ai-config:active-provider` → pub/sub |
| POST | `/:id/rotate-credentials` | accepts new creds, validates, then swaps under lock |
| PATCH | `/:id` | update non-credential fields (models, autoFallback) |
| DELETE | `/:id` | cannot delete if active; otherwise allowed |
| GET | `/:id/health` | last-N health checks |
| GET | `/:id/usage?from=&to=` | aggregated tokens + $ cost |
| GET | `/audit` | change history |

All admin actions log to `AiProviderAudit` collection:
```
{ configId, provider, action, actor, diff, at }
```

## 5. Redis cache & pub/sub

- `ai-config:active-provider` — JSON `{ id, provider, models, fingerprint, updatedAt }` (TTL 5 min).
- Channel `ai-config.changed` — published by main-service on every write. message-svc subscribes, clears its own Redis cache, reloads.
- Per-request: `AiProviderFactory.active()` is `await redis.getOrFetch(key, loader)` → O(1) steady-state.

## 6. Runtime lookup contract

```js
// services/ai-config.service.js
async function getActiveProviderConfig() {
  const cached = await redis.getJSON("ai-config:active-provider");
  if (cached) return decryptLazy(cached);  // credentials stay encrypted until actually needed
  const doc = await AiProviderConfig.findOne({ isActive: true }).lean();
  if (!doc) throw new Error("No AI provider configured by admin");
  await redis.setJSON("ai-config:active-provider", doc, 300);
  return decryptLazy(doc);
}
```

`AiProviderFactory.active()` dispatches:
```js
async function active() {
  const cfg = await getActiveProviderConfig();
  switch (cfg.provider) {
    case "openai": return require("../ai-providers/openai.provider").bind(cfg);
    case "vertex": return require("../ai-providers/vertex.provider").bind(cfg);
    default: throw new Error(`Unknown provider ${cfg.provider}`);
  }
}
```

Both provider modules export the same `ProviderInterface` (doc 06 §2). Everything above the factory is provider-agnostic.

## 7. Admin panel UI (Next.js)

Location: `Frontend/admin-panel/src/app/settings/ai-provider/`

Screens:

### 7.1 List + active card (`page.tsx`)
- Top card: **Active Provider** — provider logo, display name, model, region, last health check dot.
- Buttons: *Edit* · *Validate* · *Switch to another provider*.
- Table below: all saved configs with last-validated timestamp, status pill.
- "Add Provider" button → opens the editor for a new provider.

### 7.2 Editor — OpenAI (`openai/page.tsx`)
Form fields:
- API keys (textarea; one per line; server stores as array for rotation).
- Org id (optional).
- Chat model (select with defaults: `gpt-4.1-mini`, `gpt-4.1`, `gpt-4o-mini`).
- Vision model (select).
- Embedding model (select).
- Toggle: auto-fallback to Vertex if this config goes red.
- Buttons: *Save* · *Save + Validate* · *Save + Activate*.

On save: `POST /api/admin/ai-provider/openai` with form body. On success, redirect to list.

### 7.3 Editor — Vertex (`vertex/page.tsx`)
Form fields:
- GCP Project id.
- Primary region (select: `asia-south1`, `us-central1`, …).
- Additional regions (multi-select for fallback).
- Credential type (radio: Service Account JSON / Workload Identity Federation).
  - If SA-JSON: file input (`.json`), preview shows `client_email` + `project_id` parsed from the file (never the private key).
  - If WIF: fields for pool provider, audience, impersonated SA email.
- Chat/Vision/Embedding model selects (Vertex defaults).
- Safety settings (expert: 4 selects, default `BLOCK_ONLY_HIGH`).
- Auto-fallback toggle.
- Buttons: *Save*, *Save + Validate*, *Save + Activate*.

On save: `POST /api/admin/ai-provider/vertex` (multipart). Server parses the SA JSON, validates structure, encrypts, stores.

### 7.4 Activate modal
Confirm dialog: *"Switch active AI provider from OpenAI → Vertex? All users' next AI request will be served by Vertex."* Requires typing the provider name (OpenAI-style hard-confirm) to prevent fat-finger.

### 7.5 Health card
Shows last 20 health checks as a sparkline (green/red). Click → drawer with per-check details (latency, error if any).

### 7.6 Usage card
Token counts & $ cost for current provider — consumes `/api/admin/ai-provider/:id/usage`.

## 8. Validate flow (step-by-step)

1. Admin clicks Validate.
2. Client → `POST /api/admin/ai-provider/:id/validate`.
3. Server:
   - Decrypts creds.
   - Dispatches to the provider's `validate()` method:
     - OpenAI: `GET /v1/models` — 200? ✓
     - Vertex: `models.list` — non-empty? ✓
   - On success: `status: "valid"`, `lastValidatedAt: now`.
   - On failure: `status: "credential_invalid"` (or `error`) with `lastError` stored.
4. Response: `{ ok: true }` or `{ ok: false, reason }`.

Validate must be called at least once before `activate`. The API enforces it.

## 9. Activate flow (zero downtime)

1. Admin confirms switch.
2. Server: starts Mongo session; sets old active `isActive=false`, new active `isActive=true`. Commits.
3. Emits `ai-config.changed` on Redis.
4. message-svc handlers receive, flush `ai-config:active-provider`, next request fetches the new config.
5. Inflight requests finish with the old provider — that's fine; each request resolves the factory once at its start.
6. Audit entry written.

Rollback: same action in reverse. Old config remains in DB as a non-active row; re-activate any time.

## 10. Auto-fallback

If active provider's circuit-breaker opens:
- `ai.controller` asks the factory for a **fallback** provider.
- Factory returns the alternate provider's module **only if**:
  - Another valid & recent (`lastValidatedAt < 24 h`) config exists.
  - The active config has `autoFallback = true`.
- If conditions not met, the request gets 503.
- A flag `ai-config:fallback-in-effect` is set with 10-min TTL and logged for observability.

## 11. Security

- All admin routes require accountType=admin + recent re-auth (JWT < 15 min old) for credential-touching endpoints.
- CSRF token on all mutation endpoints (same pattern as elsewhere in admin panel).
- Rate limit: 20 validate calls per admin per hour.
- PII: no farmer data ever flows through these endpoints; they're provider config only.
- Audit log retained 2 years.
- Credentials never appear in application logs. Test: grep `private_key` / `sk-` across logs must return empty.
- KMS-backed key rotation documented in ops runbook.

## 12. Handling an already-configured deployment

Bootstrap migration M5 (one-off, runnable later):
- Reads env `OPENAI_API_KEYS` (+ model defaults) from the existing config.
- Creates an `AiProviderConfig` doc with provider=openai, isActive=true, those values encrypted.
- Validates; if OK, rollout can rely on DB config henceforth.
- If both env and DB present, DB wins. After the migration, env vars are only used at cold-boot when DB is empty — they act as a safety net, not a primary source.

Deprecation path: once all environments have a row, remove the env-var fallback (next release).

## 13. Testing

- Unit: `secret-box` round-trip, tamper detection (wrong AAD), key rotation.
- Unit: factory returns correct module per provider id.
- Integration: validate + activate + request flow using test accounts on both providers.
- E2E: Cypress test on admin panel — create vertex config, upload SA JSON, validate, activate, then chat via mobile-equivalent API and confirm provider used (from `ai.turn` log).
- Failure: revoke credentials mid-chat, confirm circuit-breaker + fallback (if enabled) or graceful 503.

## 14. Rollout (admin side)

- Ship admin UI + DB schema first (can sit unused).
- Run M5 to seed current provider.
- Only after shadow+beta backend rollout (doc 11) is stable, open the switch UI to all admins.
- Train ops with a playbook: "to switch provider", "to rotate credentials", "to roll back".

## 15. Open items

- [ ] Do we want **per-tenant** provider selection later (different providers for different client-apps)? Design leaves room: just add `scope: { tenant }` to the config; single-active becomes single-active-per-scope. Not needed for v1.
- [ ] Do we expose admin-facing **cost ceiling** per provider? (Currently only per-user and global.) Would be a nice-to-have; punt to phase 2.
- [ ] Do we want an admin-facing **playground** to test prompts against the currently-active provider? Good debugging tool; phase 2.
