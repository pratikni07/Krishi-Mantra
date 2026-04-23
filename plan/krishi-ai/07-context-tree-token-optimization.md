# 07 — Context Tree & Token Optimization

**This is the central doc for "build a tree so token usage is reduced."** It defines the layered prompt architecture, cache strategy, fingerprinting, budget math, and the concrete service that assembles it.

## 1. The idea in one paragraph

A farmer's chat turn doesn't need the whole world. It needs:
- a stable **core** identity/instructions (same for every farmer, every turn),
- their **farm profile** (changes daily at most),
- the relevant **crop blocks** (usually 1–2 of their crops),
- the local **±3-day weather** (same for everyone in ~1 km² for ~1 h),
- the **chat summary** so far (grows slowly),
- and the **last few verbatim turns** (the only per-turn-volatile bit).

Treat each piece as a **layer** with an independent TTL, fingerprint, and cache key. Assemble top-to-bottom. The top of the prompt — the parts that are byte-identical across turns — triggers OpenAI's built-in prompt caching (50% discount, lower latency). The bottom changes per turn and is tiny.

## 2. The tree

```
                 System Prompt (assembled top-to-bottom)
                 ═══════════════════════════════════════
                 │
          ┌──────┴───────┐
          ▼              ▼
   ┌───────────┐   ┌────────────┐
   │  L0 CORE  │   │  L1 PROFILE │ ◀── per user
   │  persona  │   │  farmer bio │     (TTL 1h)
   │  rules    │   │  location   │
   │  language │   │  soil, exp. │
   │  (TTL 24h)│   └──────┬──────┘
   └───────────┘          │
        (TTL 24h,    ┌────┴─────┐
        per-language)│          │
                     ▼          ▼
              ┌────────────┐ ┌──────────┐
              │ L2 CROPS   │ │ L3 WEATHER│ ◀── per bucket
              │ filtered   │ │ 7-day ±3  │     (TTL 30m)
              │ to intent  │ └──────────┘
              │ (TTL 1h    │
              │  per crop) │
              └─────┬──────┘
                    │
                    ▼
              ┌────────────┐
              │ L4 SUMMARY │ ◀── per chat
              │ old turns  │     (TTL 2h)
              └─────┬──────┘
                    │
                    ▼
              ┌────────────┐
              │ L5 WINDOW  │ ◀── per chat, mutable
              │ last N     │     (no cache, DB only)
              │  turns     │
              └─────┬──────┘
                    │
                    ▼
              ┌────────────┐
              │ L6 TURN    │ ◀── user's current message
              │ (now)      │     (ephemeral)
              └────────────┘
```

Rendered prompt (order matters — stable first):
```
L0_CORE
L1_PROFILE
L2_CROPS
L3_WEATHER
L4_SUMMARY
(conversation) messages = L5_WINDOW ++ [L6_TURN]
```

L0–L4 collapse into a single `system` message so the prefix is contiguous and prompt-cacheable. L5 are `user`/`assistant` messages. L6 is the current `user` message.

## 3. Why this specific order

OpenAI's prompt caching requires a **byte-identical prefix** (anchored at position 0). So stable layers must come first, least-stable last:

| Layer | Stability | Changes on… |
|-------|-----------|-------------|
| L0 Core | very stable | language toggle; version bumps |
| L1 Profile | stable-ish | user edits profile (rare) |
| L2 Crops | medium | user adds/removes crops; growth stage advances |
| L3 Weather | every 30–60 min | time passes |
| L4 Summary | every 12 turns | chat grows |
| L5 Window | per turn | every turn |
| L6 Turn | per turn | every turn |

We pay the "cache miss" only on the first turn or when L0/L1 change. Subsequent turns reuse the prefix up to whichever layer changed.

## 4. Fingerprinting — the cache correctness trick

OpenAI's cache is byte-exact. Our own Redis cache is keyed by a fingerprint of the *inputs* to the layer. If we can guarantee "same inputs → same output string", we can cache aggressively.

Each layer builder is a **pure function** of explicit inputs, using canonical JSON (sorted keys, no whitespace) internally for determinism. Pseudocode:

```js
// L1 profile layer
function buildProfileLayer(profile) {
  const canonical = {
    age: profile.age ?? null,
    gender: profile.gender ?? null,
    language: profile.preferredLanguage,
    loc: [round2(profile.location.coordinates[0]), round2(profile.location.coordinates[1])],
    district: profile.address?.district,
    state:    profile.address?.state,
    totalArea: profile.totalArea, unit: profile.totalAreaUnit,
    ownership: profile.ownership,
    soils: [...(profile.soilTypes||[])].sort(),
    irrig: [...(profile.irrigationSources||[])].sort(),
    exp: profile.experienceYears,
  };
  const fp = sha1(JSON.stringify(canonical));
  const text = renderProfile(canonical);
  return { text, fp, tokens: approxTokens(text) };
}
```

Redis key: `ctx-layer:profile:{fp}` → value: `text` (TTL 1h).
If cache hit, skip `renderProfile`. This saves CPU on the server and ensures *byte-identical output*, which in turn triggers OpenAI prompt-cache hits.

## 5. Layer specifications

### L0 Core (per language, ~220 tokens)
Author-once, stored in a Ruby/JS constant. One per `preferredLanguage`.

Example (English):
```
You are Krishi-Mantra AI, an agronomy assistant for Indian farmers. Follow these rules:
1. Use plain, practical language. No jargon without explanation.
2. Ground every recommendation in the farmer's profile, crops, and weather below.
3. Cite typical local units (acre, bigha, kg, litre) and INR for prices.
4. When suggesting chemicals, include safe application rate AND safety note.
5. If critical data is missing, ask ONE clarifying question first.
6. Keep responses under 250 words unless the user asks for detail.
7. Respond in: {{LANG_NAME}}.
Sections you may use: Diagnosis, Why, Action, Caution, Follow-up.
```

Cached in Redis 24 h. There are 13 such variants (one per supported language). The `{{LANG_NAME}}` is substituted at generation time and baked into the cached string (no further template interpolation at runtime).

### L1 Profile (per user, ~120 tokens)
Rendered as key-value block for compactness (JSON-like is cheaper than prose for structured data).
```
FARMER
- Age: 38, Gender: male
- Location: Sinnar, Nashik, Maharashtra (19.99N, 73.79E)
- Farm: 1.5 ha owned, soils: black/loam, irrigation: borewell+drip
- Experience: 15 years
```
Cached 1 h (bumped to 24 h if `profileVersion` unchanged for >6 h — self-tuning).

### L2 Crops (per user, filtered by intent router, ~80–200 tokens)
One sub-block per crop, max 3 crops included per turn (intent-router picks which):

```
CROPS
- TOMATO (Himsona): 1.2 ha, drip, transplanted 2026-03-05 (47 days ago, fruiting stage)
- ONION (N-53): 0.3 ha, sprinkler, sown 2026-04-09 (12 days ago, seedling stage)
```

Derived fields (days-since-sowing, stage) computed at assembly time. Cached per `(userId, intent, setOfCropIds, dateBucket)` for 6 h — "dateBucket" is the day so stages tick forward daily.

If intent = `weather`, this layer is *dropped entirely* (weather questions don't need crop listing).

### L3 Weather (per location bucket + date, ~130 tokens)
```
WEATHER (Sinnar, ±3 days around 2026-04-21)
- 04-18: 22–35°C, 0 mm, sunny
- 04-19: 23–36°C, 0 mm, sunny
- 04-20: 23–37°C, 0 mm, sunny
- 04-21: 24–38°C, 0 mm, mostly-sunny  ← today
- 04-22: 24–38°C, 0 mm, mostly-sunny
- 04-23: 23–36°C, 3 mm, light rain
- 04-24: 22–34°C, 8 mm, rain
```
Cached per `(bucket, yyyy-mm-dd)` for 30 min. Auto-refresh job runs hourly for active-user buckets.

### L4 Summary (per chat, ~0–150 tokens)
Runs only once chat has ≥12 turns. Produced by chat-summarizer.service. Reusable until the next summarization trigger. Cached 2 h keyed by `(chatId, summarizedUpTo)`.

If no summary yet → layer is empty (zero cost).

### L5 Window (per chat, ~50–600 tokens)
Last **6** turns verbatim. Not Redis-cached (it's already the most mutable). Read from DB with a single find on `AIChat` (we already keep only tail in memory).

### L6 Turn
User's current message. Trivial.

## 6. Assembly — the service

`services/context-tree.service.js`

```js
async function assemble({ userId, chat, message, routing, preferredLanguage }) {
  const layers = [];

  // L0
  layers.push(await buildCore(preferredLanguage));

  // L1
  const profile = await FarmProfileClient.get(userId);
  if (profile?.onboardingStatus === "completed") {
    layers.push(await buildProfile(profile));

    // L2
    if (routing.needsCropBlock !== false) {
      const crops = pickCrops(profile.crops, routing.cropsOfInterest, { max: 3 });
      if (crops.length) layers.push(await buildCrops(crops));
    }

    // L3
    if (routing.needsWeather !== false) {
      const wx = await WeatherService.get7Day(profile.location.coordinates);
      if (wx) layers.push(await buildWeather(wx, profile.address));
    }
  } else {
    layers.push(buildMinimalProfile(profile)); // just "user location unknown; generic advice mode"
  }

  // L4
  if (chat.summary?.text) layers.push(await buildSummary(chat.summary));

  // Combine L0..L4 into one system message (cacheable prefix)
  const systemPrompt = layers.map(l => l.text).join("\n\n");

  // L5 — window
  const window = chat.messages
    .slice(chat.summary?.summarizedUpTo || 0)
    .slice(-6)
    .map(m => ({ role: m.role, content: m.content }));

  // L6 — current turn is caller's responsibility

  return {
    messages: [{ role: "system", content: systemPrompt }, ...window],
    fingerprints: Object.fromEntries(layers.map(l => [l.name, l.fp])),
    tokenEstByLayer: Object.fromEntries(layers.map(l => [l.name, l.tokens])),
    model: routing.lowCostOk ? "gpt-4.1-mini" : "gpt-4.1",
    maxOutputTokens: routing.intent === "plant-health" ? 900 : 700,
  };
}
```

Invariants:
- Every layer produces a *deterministic* string given its inputs.
- Layers are always in the same order.
- Layer separators are a single `\n\n`. No timestamps in layer text (breaks determinism).

## 7. Token budget math

Expected typical turn (farmer with 2 crops, profile complete, 3 prior turns, no summary yet):

| Layer | Tokens | Cache eligible? |
|-------|--------|-----------------|
| L0 Core | 220 | OpenAI cache ✓, Redis ✓ |
| L1 Profile | 120 | ✓ / ✓ |
| L2 Crops (2) | 150 | ✓ / ✓ (per crop set) |
| L3 Weather | 130 | ✓ / ✓ (per bucket) |
| L4 Summary | 0 | — |
| L5 Window (3 turns × ~80) | 240 | ✗ / ✗ |
| L6 User turn | 50 | ✗ |
| **Total input** | **910** | **First 620 tokens cached ⇒ ~50% discount on those** |

Same query without the tree (naive "stuff everything"): ~2400–2800 tokens. **~60–65% reduction.**

Steady-state (turn 5+ in the chat):
- L0+L1 always cache-hit (byte-identical prefix)
- L2 cache-hits unless user edited crops or a day ticked over
- L3 cache-hits until 30-min TTL
- L5 always mis (but only ~240 tokens uncached)
- **Effective uncached tokens ≈ 290 → ~32% of total input.**
- OpenAI cached-input tokens = L0+L1+L2+L3+L4 ≈ 620 → billed at 50%.
- Per-turn cost ≈ `(290*$0.15 + 620*$0.075 + 500*$0.60) / 1M = $0.0004`.

Per 1k turns: ≈ $0.40. **Bill stays tiny even at scale.**

## 8. Pruning rules (when over budget)

Priority order to drop (lowest first):
1. Extra crops in L2 beyond top 2 (intent-scored).
2. Historical weather days beyond D-1 and forecast days beyond D+2.
3. Oldest turns in L5 until 4 remain.
4. Condense L4 summary (rerun summarizer with stricter cap).
5. Drop L4 entirely.
6. Drop L3 weather (last resort).
7. Escalate model.

Never drop L0, L1, or L6.

## 9. Cache invalidation rules

| Event | Invalidates |
|-------|-------------|
| User edits farm profile | `farm-profile:{uid}`, `farm-profile:fp:{uid}`, all `ctx-layer:profile:{oldFp}`, all `ctx-layer:crops:{uid}:*` |
| Crop added/removed/edited | same as above |
| Hourly weather refresh | `weather:{bucket}` + `ctx-layer:weather:{bucket}:{date}` for stale dates |
| Day rollover (midnight local) | `ctx-layer:weather:*:{yesterday}`, `ctx-layer:crops:*:{yesterday}` |
| Chat summarization | `ctx-layer:summary:{chatId}:*` |
| `TREE_VERSION` bumped in code | flush entire `ctx-layer:*` namespace |

Invalidation is **always a delete, never a write**. Next turn triggers a rebuild and repopulates. Cache stampede is avoided by jitter on TTL and single-flight locks on layer rebuild (Redis SETNX).

## 10. Correctness safety net

To catch the "cached content is wrong" class of bug:
- Every Nth turn (default N=50), bypass Redis and rebuild the layer from scratch; diff against cache; if differ, log `ctx_cache_mismatch` and evict.
- `TREE_VERSION` constant in `context-tree.service.js`. Any change to layer templates → bump. All Redis layer keys include `TREE_VERSION` so the old cache becomes unreachable.

## 11. Why not RAG / vector DB?

A RAG approach would store every chat turn embedded, retrieve by similarity at query time. Considered but rejected for v1:
- Farmer profile is tiny and **structured**, not unstructured corpus.
- Deterministic layers give repeatable behavior farmers can trust.
- No infra to stand up (vectors, ANN index, etc.).
- Future epic: add a **retrieval layer L3.5** that fetches top-3 past chats on similarity, for farmers with long histories. Design of the tree leaves room.

## 12. Quick walkthrough — a real turn

Farmer (Marathi, onboarded, tomato + onion) types: *"माझ्या टोमॅटोवर पिवळे डाग आहेत"* ("my tomato has yellow spots")

1. **Intent router:** regex matches `disease` words + crop `tomato` → `{ intent: "plant-health", cropsOfInterest: ["tomato"], needsWeather: true, needsCropBlock: true }`.
2. **Layer build:**
   - L0 (Marathi core) — cache hit.
   - L1 profile — cache hit.
   - L2 — filtered to just tomato crop (onion skipped by router). Cache hit on `(uid, ["tomato"], 2026-04-21)`.
   - L3 weather — cache hit (bucket fetched 12 min ago).
   - L4 summary — 3-turn chat, no summary yet.
   - L5 — 3 prior turns.
   - L6 — user message.
3. **Assembly + OpenAI:** 870 input tokens, 600 cached on OpenAI side ⇒ effective 270 uncached + 600 cached. First-token latency ~700 ms.
4. **Response streamed**, ~450 completion tokens. Cost ≈ $0.00035.
5. Chat saved, context extracted, no summary trigger yet (only 4 turns total).

Same flow for a farmer with no profile: L1 becomes "profile unknown; give generic advice" → L2/L3 dropped → ~320 input tokens. Works but less useful — which is the nudge to complete onboarding.
