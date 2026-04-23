# 01 — Requirements & Goals

## 1. Problem statement

Today the Krishi AI assistant doesn't *know* the farmer. It answers questions without context about what they grow, where they grow it, or what the weather is doing. On the backend we run two different providers (Groq for chat, Gemini for vision) — more ops surface than we need. On the mobile side, location and weather are stubbed, so even the limited context we claim to send is fake.

We want a single OpenAI-backed assistant that opens every conversation already knowing: *"this is a 34-year-old farmer in Nashik with 1.2 ha of tomato (45 days after sowing) and 0.3 ha of onion (12 days after sowing). Yesterday was 36 °C with 18 mm of rain; tomorrow expects 38 °C and no rain."* — and answers accordingly, in the farmer's chosen language, without sending those same 3 kB of context over the wire on every turn.

## 2. Goals (must-have)

1. **Provider-pluggable AI backend with admin-controlled selection.** Two first-class providers — **OpenAI (ChatGPT)** and **Google Vertex AI** — behind a common `ProviderInterface`. The admin panel picks which provider is active and stores its credentials (encrypted). The chosen provider serves **all** users for all chat/vision/summarization calls. Groq and Gemini are removed from runtime paths. Switching providers is one click and zero-downtime. Exactly one provider is active at a time (with optional auto-fallback to the other on outage).
2. **Detailed farm profile at signup.** After OTP verification, the user completes a **multi-step onboarding** that captures:
   - Farmer basics: full name, age, gender, preferred language, location (lat/lon + address).
   - Farm: total land area, unit (acre/hectare/bigha/gunta), ownership (owned/leased), soil type (sandy/loam/clay/black/red/laterite — multi-select), irrigation source (borewell/canal/rainfed/drip/sprinkler — multi-select), experience in years.
   - **Crops (1..N)** — for each crop: crop (from master list), variety (free text or master), area under this crop, sowing date, growth stage (auto-derived + editable), planting method, expected harvest date (auto-derived + editable).
3. **Multiple crops.** User can add, edit, and remove crops freely — both during onboarding and later from Profile → My Farm.
4. **AI calls use the profile.** The profile + ±3-day weather is assembled server-side into the system prompt; the mobile app only sends the user's message + chat id.
5. **±3-day weather window.** Every AI turn carries weather for the 3 days *before* today and the 3-day forecast *after* today (7 days total including today). Data is fetched server-side, cached per location bucket.
6. **Token-reduction context tree.** Server assembles the system prompt as cached, hierarchical layers (see doc 07). Target: ≤2500 input tokens per routine chat turn, ≤4000 for image turns.
7. **No frontend regression.** Existing chat UX (streaming, image, multi-image, rate-limit display, history, languages) must still work — regardless of which provider is active.
8. **Observable cost.** Per-user, per-request, **per-provider** token counts, $ cost, cache hit rate, latency — all logged and dashboarded.
9. **Secure credential handling.** Admin-supplied keys / service-account JSONs are AES-256-GCM encrypted with a KMS-managed (or env-supplied) master key; never logged; admin UI only ever shows fingerprints + metadata, never plaintext.

## 3. Non-goals

- Not replacing OpenWeather with a custom weather provider.
- Not building our own crop master dataset beyond what `Crop` model already has.
- Not redesigning the chat UI layout.
- Not changing the subscription/quota tiers.
- Not migrating old chats' metadata — old chats stay as-is; only *new* chats use the tree.
- Not building a recommendations/feed system on top of the profile (separate epic).

## 4. Success criteria / KPIs

| KPI | Baseline | Target | How measured |
|-----|----------|--------|-------------|
| Avg input tokens / chat turn | ~1.4 k (Groq tokenizer est.) | **≤ 0.9 k** | `openai.usage.prompt_tokens` logged per request |
| Avg input tokens / image turn | ~2.5 k | **≤ 1.6 k** | same |
| OpenAI prompt-cache hit rate | 0 % | **≥ 55 %** | `openai.cached_tokens` / `prompt_tokens` |
| P50 chat latency (first token) | ~2.4 s | **≤ 1.6 s** | SSE timing, server side |
| P95 chat latency (full response) | ~6 s | **≤ 4.5 s** | same |
| $ / 1 k chat turns | ~$2.10 (Groq public rates est.) | **≤ $2.50** with gpt-4.1-mini | cost aggregation from usage |
| Onboarding completion rate | n/a | **≥ 80 %** of new users finish the farm profile | analytics event `farm_profile_completed` |
| % AI turns with real weather | 0 % | **≥ 95 %** | server log: `weather.source != "client-stub"` |
| Crash rate (mobile signup) | baseline | no regression | Crashlytics |

## 5. Stakeholder asks (verbatim → interpretation)

| Ask | Interpretation |
|-----|---------------|
| "use the chatgpt api key" | OpenAI SDK, keys sourced from the `AiProviderConfig` record the admin saves (decrypted at call time). Legacy env-var fallback only during bootstrap. Supports 1..N keys with rotation (mirroring current Gemini pattern). |
| "add setup of google vertex" | Second provider behind the same interface. Admin supplies project, region, and a Service-Account JSON (or WIF). See doc 06b. |
| "from admin panel i set which ai provider to use and configure the credentials" | New admin screen `/settings/ai-provider` lets admin create/edit configs for each provider, validate credentials, and click "Activate". See doc 13. |
| "if i selected chatgpt with api key then use chatgpt … if enabled vertex with credentials then use vertex for all users" | Exactly-one active `AiProviderConfig` enforced by partial unique index. ProviderFactory reads it (Redis-cached) on every request. Switch is atomic + global (no per-user split). |
| "complete end-to-end ai feature" | Chat, vision, title generation, summarization, intent routing — all via the active provider. No Gemini/Groq runtime calls. |
| "take all detailed info like what crop he planted, age of crop, how much land" | See Goal #2 above. "Age of crop" = sowing date (→ derived days-since-sowing); "how much land" = total + per-crop area. |
| "user can select the multiple crops" | `FarmProfile.crops: [{cropId, …}]`; UI supports add/remove/edit. |
| "ai feature provides this information as system prompt" | System-prompt tree layers 2–4 (see doc 07). |
| "weather details of 3 days ago and 3 days ahead" | 7-day window (D-3, D-2, D-1, D, D+1, D+2, D+3) injected as a compact layer. |
| "build such a tree that token usage will reduced" | Hierarchical, cacheable context tree (doc 07). Not a literal data-structure tree — a **layered prompt assembly**. |
| "detailed implementation plan" | This `plan/krishi-ai/` folder. |

## 6. Constraints

- **Budget guardrail:** monthly OpenAI spend must stay under $X (TBD with PM). Hard kill switch via feature flag if exceeded.
- **Latency:** first-token ≤ 2 s P95 or we'll get complaints. Streaming mandatory.
- **Privacy:** farm location + profile is PII. No logging the whole profile to CloudWatch in plain text; log hashed user id + counts only.
- **Offline-friendly:** mobile signup must cache the onboarding draft locally — users often lose signal mid-form on 2G.
- **Languages:** keep the 13 Indian languages the app already supports. Translation still happens on the backend via the OpenAI system-prompt instruction (no separate translation call).
- **Back-compat:** the mobile app still supports old chats. The `/api/ai/chat` response shape stays the same; we only *add* fields.

## 7. Risks

| Risk | Severity | Mitigation |
|------|----------|-----------|
| Provider bill runaway (OpenAI or Vertex) | High | Hard daily $ cap per user + per-provider global minute cap + kill-switch flag + token budget per turn. |
| Active provider outage | High | Circuit-breaker; optional **auto-fallback** to the other configured provider if admin enabled it. Otherwise user-visible "AI is down, try again". |
| Credential leak | High | AES-256-GCM with KMS key; no plaintext on disk or in logs; admin UI shows only fingerprint/metadata; audit log of every credential read/write. |
| Admin sets bad credentials and activates | Med | `/activate` endpoint requires a successful `/validate` within the last 15 min. Bad creds can't be activated. |
| Provider-specific behavioral regressions after switch (different phrasing, refusals) | Med | Prompt files are provider-aware in doc 09; regression harness runs against both providers weekly. |
| Profile quality is garbage (users skip fields) | Med | Required: at least 1 crop + location. "Skip for now" allowed but banner in AI screen nudges completion. |
| Weather provider rate-limits | Med | Per-location bucket cache (60-min TTL). Open-Meteo is free; OpenWeather OneCall is paid but more detail. Plan for both. |
| Prompt cache miss because tree layers are slightly different per turn | Med | Deterministic serialization of each layer; canonical JSON; content fingerprinting. See doc 07 §4. |
| Users with dozens of crops blow past token budget | Low | Cap at 6 most-relevant crops per turn (intent router picks). |
| Mobile app version skew after backend rollout | Med | Gateway routes old `/api/ai/*` paths transparently; old clients still work (they just miss profile benefits). |

## 8. Open questions

- [ ] Which OpenAI model tier is approved? Default assumed: `gpt-4.1-mini` for chat, `gpt-4o-mini` for vision.
- [ ] Which Vertex models? Default assumed: `gemini-2.5-flash` for chat+vision, `text-embedding-005` for embeddings.
- [ ] Which GCP region(s) for Vertex? Default assumed: `asia-south1` (Mumbai) primary, `us-central1` fallback.
- [ ] KMS key source for credential encryption — GCP KMS, AWS KMS, or env-supplied master key? (Plan supports all three; pick one in staging.)
- [ ] Should admin be able to configure **per-feature** providers (e.g. OpenAI for chat, Vertex for vision)? Plan treats this as phase 2; v1 is one-provider-for-all.
- [ ] Which weather provider? Default assumed: Open-Meteo free tier (no key, but rate-limited) with OpenWeather OneCall 3.0 as paid fallback.
- [ ] Is crop *variety* free-text or master-list? (Plan assumes: dropdown of common varieties + "other → free text".)
- [ ] Do we want an admin console to edit crop master list? (Out of scope here; handled by existing admin panel if exists.)
- [ ] Are we comfortable storing lat/lon with ~100 m precision? (Assumed yes, same as today.)
