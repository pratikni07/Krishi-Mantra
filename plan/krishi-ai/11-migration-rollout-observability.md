# 11 — Migration, Rollout & Observability

How we ship this safely: feature flags, traffic stages, backfill jobs, shadow testing, dashboards, alerts, kill switches, and rollback procedures.

## 1. Feature flags

| Flag | Values | Scope | Default |
|------|--------|-------|---------|
| `AI_PROVIDER_MODE` | `legacy` \| `registry` \| `shadow` | service env | `legacy` at start |
| `ai:provider-override:{userId}` | configId | Redis key | unset (beta testing) |
| `ai:killswitch:global` / `:openai` / `:vertex` | `"1"` | Redis | unset |
| `WEATHER_PROVIDER` | `open-meteo` \| `openweather` | service env | `open-meteo` |
| `CONTEXT_TREE_ENABLED` | bool | service env | `true` once rolled out |
| `NEW_AI_ENABLED` | bool | mobile remote-config | `false` at start |
| `ONBOARDING_V2_ENABLED` | bool | mobile remote-config | `false` at start |

Rollout order: backend env `registry` + admin seeds an OpenAI config → shadow for 1 week → flip per-user overrides for internal beta → remove `AI_PROVIDER_MODE=shadow` sampling → enable mobile `NEW_AI_ENABLED`.

**After cutover, the admin panel is the switchboard.** Swapping OpenAI ↔ Vertex no longer needs a flag flip — it's a DB mutation via `/api/admin/ai-provider/:id/activate`.

## 2. Shadow mode

When `AI_PROVIDER_MODE=shadow` OR when the user is in the 10% shadow sample:
- The user's request is served by the **legacy** path (unchanged user experience).
- In parallel, we assemble the prompt tree and fire a **non-streaming** call against the admin-active provider (OpenAI or Vertex — both are valid shadow targets).
- We compare:
  - prompt-token counts
  - cached-token ratio
  - completion length
  - estimated $ cost
  - response similarity (optional: cosine similarity of embeddings — phase 2).
- Results logged to `ai_shadow_log` (Mongo) with fields `{ userId, chatId, legacyTokens, openaiTokens, openaiCached, latencyLegacyMs, latencyOpenaiMs, costUsd }`.

Go/no-go criteria before flipping to `openai`:
- ≥5000 shadow turns.
- Avg openai input tokens ≤ 1100.
- Cache hit rate ≥ 50%.
- No cost per-turn > $0.01 outliers unexplained.
- Spot-check: 50 samples rated "as good or better than legacy" by a human reviewer.

## 3. Data backfill

### M1: Create `farm_profiles` collection
- Script: `main-service/src/scripts/migrations/M1_create_farm_profiles.js`
- Ops: collection + indexes created by `mongoose` on first read; explicit script ensures deterministic start.
- Idempotent.

### M2: Backfill empty `FarmProfile` for every existing user
- Script: `main-service/src/scripts/migrations/M2_backfill_farm_profiles.js`
- Batches of 500, retries, resumable from checkpoint file.
- Creates `{ userId, onboardingStatus: "not_started" }` docs only if absent.
- Links `UserDetail.farmProfile` pointer.
- Runs during low-traffic window; takes ~20 min for ~500k users.

### M3: Extend `ai_chats` with usage/summary fields
- No script needed — lazy-init on next save handles it.
- Optional cleanup script post-migration.

### M4: Deploy `weather_snapshots` collection with TTL
- Script: `message-svc/src/scripts/migrations/M4_weather_snapshots.js`
- Idempotent.

### M5: Seed `AiProviderConfig` from env (bootstrap) + `AiProviderAudit` collection
- Script: `main-service/src/scripts/migrations/M5_seed_ai_provider_config.js`
- If no active config exists and `OPENAI_API_KEYS` is present, creates an OpenAI config from env vars, encrypts the keys, validates, and sets `isActive=true`.
- Creates empty `AiProviderAudit` collection + indexes.
- Idempotent (skips if row exists).
- Run this **before** flipping `AI_PROVIDER_MODE=registry`.

All migration scripts logged to `migrations_run` collection with timestamp + checksum, per existing pattern.

## 4. Rollout stages

### Stage 0 — Dev & staging (week -2 to -1)
- Feature flag all off in prod.
- Deploy all backend changes to staging with `AI_PROVIDER=openai` and seeded test users.
- Run load test (k6) with 100 concurrent virtual users, 30 turns each.
- Run prompt-regression harness (doc 09 §13).
- Code review & security review (see `security-review` skill).

### Stage 1 — Shadow (week 0)
- Run M5 to seed an `AiProviderConfig` OpenAI row from env vars.
- Deploy backend to prod. `AI_PROVIDER_MODE=legacy` but shadow sampling of 10% → active provider (OpenAI initially) in parallel.
- Mobile: unchanged.
- Run 7 days. Collect shadow metrics.

### Stage 2 — Beta backend (week 1)
- Flip `AI_PROVIDER_MODE=registry` for 5% of users (via `ai:provider-override:{userId}` pointing at the OpenAI config id).
- Keep shadow on the remaining 95%.
- Watch dashboards; fix P0s.

### Stage 3 — Gradual ramp (week 2)
- 20% of users on `registry` mode (random selection).
- Mobile app v2 released with `NEW_AI_ENABLED` dark-launched (still `false`).

### Stage 4 — Mobile onboarding beta (week 3)
- 5% of mobile users get `ONBOARDING_V2_ENABLED=true`. They see the 4-step onboarding.
- Track `farm_profile_completed` funnel; fix UX bumps.

### Stage 5 — Full backend cutover (week 4)
- `AI_PROVIDER_MODE=registry` globally. Legacy Groq+Gemini calls removed.
- Keep Groq/Gemini SDK code and env vars behind flag for one more release (cheap insurance).

### Stage 5.5 — Vertex provider rollout (week 4.5)
- Admin creates a second `AiProviderConfig` for Vertex AI (project, region, SA JSON).
- Validate via admin UI; confirm `valid`.
- Flip `ai:provider-override:{beta-user-ids}` to Vertex config id for internal team (20 users).
- Run 3 days; compare quality/cost dashboards.
- If good: admin clicks **Activate** on the Vertex config → all users cut over in seconds. (Alternatively, leave OpenAI active; Vertex remains ready to be activated on demand.)
- If issues: deactivate back to OpenAI with one click.

### Stage 6 — Full mobile rollout (week 5)
- `NEW_AI_ENABLED=true` and `ONBOARDING_V2_ENABLED=true` for 100%.
- Admin panel UI for provider management goes live to the full admin team (docs shipped in runbook).

### Stage 7 — Cleanup (week 6)
- Delete `groq-sdk`, `@google/generative-ai` (old Gemini SDK) from package.json.
- Remove legacy AI service code paths.
- Remove OWM direct-call code from mobile.
- Remove `AI_PROVIDER_MODE=legacy` branch; mode becomes effectively `registry` always.

## 5. Rollback procedures

| Issue | Action |
|-------|--------|
| Active provider cost spike | Admin clicks **Activate** on the other provider (if configured) — or flip `AI_PROVIDER_MODE=legacy` as last resort. |
| Mass 5xx from active provider | Automatic: circuit breaker in the provider module + auto-fallback to the other provider if admin enabled it + global kill-switch flag (see §6). Users fall back to a friendly "AI is temporarily down" UI otherwise. |
| Bad credentials discovered post-activation | Admin clicks **Rotate credentials**; if still failing, **Activate** the other provider. Takes <1 min. |
| Prompt regression (users complain answers are worse) | Flip `CONTEXT_TREE_ENABLED=false` → falls back to a minimal 1-layer prompt (no profile/weather). If still bad, flip back to `legacy`. |
| Migration M2 stuck | Script is resumable; just rerun. No data corruption risk — only creates missing docs. |
| M5 couldn't seed config | Admin creates the OpenAI config manually via `/settings/ai-provider` before flipping `AI_PROVIDER_MODE=registry`. |
| Mobile app crash in onboarding | Flip `ONBOARDING_V2_ENABLED=false` → users land on home; existing users unaffected. |

All flags are flip-via-env-var + hot-reload where possible (`main-service` already supports SIGHUP reload on a subset; otherwise a rolling deploy ~5 min).

## 6. Kill switches

Hard kill via Redis (no deploy needed):
- `ai:killswitch:global = "1"` → `/api/ai/*` immediately returns 503 with friendly message.
- `ai:killswitch:openai = "1"` → force the factory to skip the OpenAI provider (auto-fallback to Vertex if configured + `autoFallback: true`, else 503).
- `ai:killswitch:vertex = "1"` → same for Vertex.
- `ai:killswitch:images = "1"` → disable only image endpoints.
- `ai:killswitch:admin = "1"` → freeze admin-panel writes to `AiProviderConfig` (e.g. during an incident when you don't want well-meaning admins flipping things).

Set/reset via ops runbook. These trump admin-panel state.

## 7. Dashboards (Grafana)

Three dashboards, one board per team lens.

### `krishi-ai-ops` (SRE)
- Requests/min, 5xx%, P50/P95 latency (first token, total) — **split by provider**.
- Active provider indicator (OpenAI / Vertex) + health dots for each configured provider.
- Cache hit ratio per layer (core, profile, crops, weather, summary) + OpenAI prompt-cache / Vertex context-cache hit rate.
- Daily $ spend per provider + 30-day trend.
- Active users / active chats.
- Kill-switch state.
- Admin actions timeline (from `AiProviderAudit`) — last 24h activations, validations, rotations.

### `krishi-ai-cost` (PM/Finance)
- $ per day, **per provider**, per model, per user subscription tier.
- Tokens in/out per day per provider.
- $/1k turns (overall + by provider).
- Top 20 users by cost (hashed IDs).
- Shadow vs live cost delta.
- Side-by-side OpenAI vs Vertex price efficiency (tokens per dollar).

### `krishi-ai-quality` (Product)
- Onboarding funnel: started → step 1 → step 2 → step 3 → completed.
- % of AI turns with `profile completed` context.
- Avg crops per farmer.
- Per-intent % mix (plant-health, irrigation, …).
- "Clarifying question" rate (detected by model output containing "?" at end) — proxy for under-context.

## 8. Alerts (PagerDuty + Slack)

| Alert | Trigger | Severity |
|-------|---------|----------|
| Active provider 5xx % | >5% for 10 min | P1 |
| P95 latency > 6s | 10 min | P2 |
| Daily cost > 150% of 7d avg | within 2h | P1 |
| Cache hit rate < 40% | 1h | P2 |
| Weather provider failure rate > 20% | 15 min | P2 |
| Migration M2/M5 failed batch | immediate | P2 |
| Global kill-switch activated | immediate | FYI to #krishi-ai-ops |
| `AiProviderConfig` activated (audit event) | immediate | FYI to #krishi-ai-ops + #security |
| `status=credential_invalid` on the active config | immediate | P1 |
| Auto-fallback engaged (provider flipped without admin action) | immediate | P1 |

## 9. Logging discipline

- Every `ai.turn` event: one JSON line, bounded fields, userId hashed.
- **Never** log: user message text, profile contents in full, chat message content.
- **Do** log: intent, layer names, token counts, latency, cache fingerprints (hashed).
- Sampling: 100% of error events, 10% of success events (dial via `AI_TURN_LOG_SAMPLE`).

## 10. Cost forecasting

Pre-rollout estimate (see doc 07 §7 cost model):
- 50k daily chat turns @ $0.0004/turn = **$20/day chat**.
- 5k daily image turns @ $0.004/turn = **$20/day vision**.
- Summarization/title calls: ~$1/day.
- **Target monthly bill: < $1500.**
- Upper guardrail: `AI_DAILY_COST_CAP_USD_PER_USER` + global minute cap.

Re-forecast weekly during Stage 3–5 with actuals.

## 11. Post-rollout verification (week 7)

- Data integrity: `FarmProfile` count ≈ active user count. No orphaned `UserDetail.farmProfile` pointers.
- No traffic to `groq.com` / `generativelanguage.googleapis.com` (confirm at egress).
- All dashboards green.
- Remove migration scripts? **No** — keep under `scripts/migrations/` per existing convention; they're idempotent and serve as documentation.

## 12. Comms plan

- **Internal:** #krishi-ai Slack channel for all rollout updates. Daily status during Stages 2–6.
- **External:** In-app notification when a user first sees the new AI behavior:
  - "🌱 Your AI assistant is now smarter — add your crops for personalized advice."
  - Appears once, on first AI chat open post-flip.
- Optional blog post after Stage 6 explaining the upgrade.

## 13. Security review gate

Before Stage 2, run the built-in `security-review` skill on the full diff:
- Verify no user input interpolated into shell/SQL.
- Verify S3 URL validation in image endpoint (anti-SSRF).
- Verify no PII in OpenAI `user` field (we pass userId, not name/phone).
- Verify JWT required on all new routes.
- Verify gateway rate limits apply to new routes.
- Verify Redis keys are env-prefixed to avoid cross-env contamination.
