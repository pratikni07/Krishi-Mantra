# A08 — AI-First Multimodal Recommendations (Vertex)

> Pivot from rule-engine-first to AI-first action-card recommendations, with multimodal context: 7-day image history (AI chat + consultant chat), full activity journal, weather, farm profile, and a daily farmer-input field.

## 1. What changes vs Sprint 1 of Build A

| Aspect | Sprint 1 (rule-first) | A08 (AI-first) |
|---|---|---|
| Primary engine | Curated `CropTaskTemplate` rules | Google Vertex AI multimodal (`gemini-2.5-flash`) |
| AI usage | Fallback only (~5% of cards, 2/user/day cap) | Every card (cap-controlled) |
| Inputs | profile + crops + weather + journal | profile + crops + weather + journal + **last-7d images** + **farmer's daily input** |
| Cost per card | ~$0 | ~$0.005–0.012 (3–5 images per call) |
| Determinism | yes (auditable) | no (provider-side); we log inputs for replay |
| Rule engine role | primary | safety net — runs in parallel; used when AI fails or returns invalid output |
| Templates | the recommendation source | now act as **agronomy guardrails** (verb enum, banned-chemical list, dose sanity) |
| UI | display-only | **gains a daily farmer-input field** (text + photo) that feeds tomorrow's card |

## 2. End-to-end flow (AI-first)

```
buildCardForUser(userId, localDate):

  1. Load profile + active crops                     [main-service Mongo]
  2. Load weather                                     [WeatherSnapshotClient]
  3. Load activity journal (last 30d)                 [ActivityJournal]
  4. Load image context (last 7d):                    [NEW — image-context.service]
       a. AIChat.messages[].imageUrl WHERE userId
       b. Message.mediaType ∈ {image,text_image} WHERE chat has user
       c. previous DailyActionCard.farmerInput.imageUrls
       d. Disease-detection saves (if any)
       → returns ≤ 5 most recent presigned URLs
  5. Load yesterday's farmerInput from yesterday's DailyActionCard.   [carries forward]

  6. AI-first path (parallel with rule fallback):
       a. Build multimodal prompt (system + structured user JSON + N image parts)
       b. Vertex `analyzeImages` via internal AI endpoint
            → strict JSON: items[ {cropEntryId, verb, title, detail, chemical?, dose?,
                                     safetyNote?, urgency, rationaleTags[]} ]
       c. Validate against guardrails: verb ∈ enum, chemical ∉ banned list,
            dose pattern OK, urgency ∈ enum
  7. Rule fallback (always runs, cheap):
       - Run the existing recommendation.engine for safety-net items
  8. Merge: AI items first; rule items fill any gap; cap globally at 3.
  9. Localize → persist DailyActionCard → Redis write-through → push.
```

The critical change: **AI is no longer a fallback for niche crops. It's the primary**, with the rule engine demoted to a deterministic safety net.

## 3. Why Vertex specifically

- **Native multimodal** in a single call — `gemini-2.5-flash` accepts images and text in one prompt, no separate vision pass.
- **Asia-South1 region** — 200–400 ms lower latency than OpenAI for the cron's batch of Indian users.
- **Already wired** in our provider registry from the krishi-ai sprint (`vertex.provider.js`).
- **Strong on agriculture imagery** (general benchmark; pending our domain validation).
- **Cost-effective** for vision: $0.075/M input tokens, $0.30/M output. ~$0.003 per 5-image multimodal call typical.

We keep the provider abstraction — `factory.active()` still resolves the configured provider — but the action-card builder hard-prefers `vertex` for its calls. If admin switches the active provider to OpenAI, the same multimodal contract works (via the existing `analyzeImages` interface), just at higher latency from us.

## 4. Data model changes

### Extend `DailyActionCard.farmerInput`

```js
farmerInput: {
  text: { type: String, maxlength: 500 },
  imageUrls: [{ type: String }],   // S3 URLs from existing presigned-URL flow
  voiceUrl: { type: String },      // future (Build B) — voice note uploaded
  submittedAt: Date,
  acknowledged: { type: Boolean, default: false }, // becomes true once consumed by next-day generation
}
```

Whatever the farmer types/photographs into the card today is **the most important context** for tomorrow's AI call. It's the farmer's eyes on their own field.

### New: `ActionCardImageContext` (NOT a collection — a runtime object)

We don't persist this. The `image-context.service` computes it on the fly each cron run by reading existing AI-chat / consultant-chat / card-input collections. Keeps the storage story simple.

## 5. New module layout

```
Backend-JS/main-service/src/
└── services/action-card/
    ├── image-context.service.js        NEW — pulls 7d images
    ├── ai-builder.service.js           NEW — Vertex multimodal orchestrator
    ├── ai-prompt.builder.js            NEW — strict-JSON prompt assembly
    ├── ai-response.validator.js        NEW — schema + guardrails
    ├── recommendation.engine.js        UNCHANGED — now acts as safety net
    ├── card.builder.js                 EXTENDED — AI-first, rule-fallback merge
    ├── localizer.js                    UNCHANGED
    └── farmer-input.service.js         NEW — handles POST /api/action-card/:id/farmer-input

Backend-JS/main-service/src/controller/
└── ActionCardController.js             EXTENDED — farmer-input endpoint

Backend-JS/message-svc/src/controllers/
└── ai-internal.controller.js           EXTENDED — vision multipart support
```

## 6. Vertex prompt structure (rendered at runtime)

System message (English source; output language is the user's `preferredLanguage`):

```
You are an agronomist helping an Indian farmer. Output a STRICT JSON object only.
Schema: { "items": [
  { "cropEntryId": str, "verb": one of [<13 verbs>],
    "title": str ≤ 80 chars, "detail": str ≤ 60 words,
    "chemical"?: str (generic active only — NEVER brand names),
    "dose"?: e.g. "2.5 g/L", "safetyNote"?: ≤ 25 words,
    "urgency": one of [low, normal, high, urgent],
    "rationaleTags": short snake_case tokens [...]
  }
]}
Constraints:
- 1–3 items total across all crops; pick the most consequential.
- NO brand names. NO banned chemicals: endosulfan, monocrotophos, phorate, methyl-parathion.
- If images show pest/disease symptoms, prefer that crop.
- Reply MUST be in: <Lang Name>.
- Every dose must include unit (g/L, ml/L, kg/acre).
```

User content (JSON object + image parts):

```json
{
  "farm": { "totalArea": 1.5, "unit": "hectare", "soils": ["black","loam"], "irrigation": ["borewell","drip"], "state": "Maharashtra", "district": "Nashik" },
  "crops": [
    { "cropEntryId": "c1", "name": "Tomato", "variety": "Himsona", "daysSinceSowing": 47, "stage": "fruiting", "irrigationMethod": "drip", "area": 1.2 },
    { "cropEntryId": "c2", "name": "Onion", "variety": "N-53", "daysSinceSowing": 12, "stage": "seedling", "irrigationMethod": "sprinkler", "area": 0.3 }
  ],
  "weather7d": [
    { "date": "2026-04-22", "tempMin": 23, "tempMax": 36, "rainfallMm": 0, "label": "sunny" },
    ...  // 7 entries D-3..D+3
  ],
  "recentActivity": [
    { "verb": "spray_fungicide", "crop": "Tomato", "date": "2026-04-17" },
    { "verb": "irrigate", "crop": "Onion", "date": "2026-04-20" }
  ],
  "farmerInputYesterday": "tomato leaves looking yellow on lower part",
  "imageContext": "5 photos attached — 3 from AI chat (2026-04-21), 1 from consultant chat (2026-04-23), 1 from yesterday's card input (2026-04-24). Look for pests, disease symptoms, fruit set, water stress."
}
```

Plus 5 image parts attached via Vertex's `inlineData` (presigned URL → buffer → base64) or `fileData` for public URLs.

## 7. Cost and latency

| Metric | Value |
|---|---|
| Avg input tokens per card call | ~1.8k (text) + ~5×258 image tokens = ~3k |
| Avg output tokens | ~250 |
| Cost @ Vertex `gemini-2.5-flash` | (3000/1M × $0.075) + (250/1M × $0.30) = **~$0.0003** |
| With 5 images at ~258 tokens each | ~$0.0006 |
| Latency P50 | ~1.5–2.5 s per call |
| Latency P95 | ~5 s |
| Cron worker pool size | 8 (existing) → bump to 16 for AI-first |

At 100k DAU × 1 call/day × $0.0006 = ~$60/day = ~$1,800/month. The cron's pool size + Vertex RPM cap (existing token-bucket from B05) keep us under provider quota.

If costs balloon (e.g., farmers upload 10+ images per turn): the image-context service caps at 5 images per call, picked by recency × diversity (see §10).

## 8. Image context selection algorithm

When pulling the last 7 days of images per user:

```
candidates = [
  ...AIChat images (with crop tags from chat metadata if available),
  ...consultant Message.mediaType=image|text_image (within chats this user is in),
  ...past 7 DailyActionCard.farmerInput.imageUrls,
  ...disease-detection saved images (if collection exists),
]
sort by occurredAt DESC

dedupe by URL (handle re-shares)
prefer at least 1 image per active crop if available (round-robin)
cap at 5 most recent

if no images at all → text-only call (cheaper; AI still gets profile+weather+journal)
```

Privacy: only images this user uploaded or that were sent IN A CHAT THIS USER IS A PART OF. We never pull images from chats the user isn't in.

## 9. Farmer-input flow (the new daily field)

Mobile UI adds a single input row at the bottom of the action card:

```
┌─────────────────────────────────────────────┐
│ 📝 आज शेतावर काय पाहिलं?                   │
│ [ टाइप करा किंवा 📷 फोटो जोडा ]            │
│                          [ साठवा ]          │
└─────────────────────────────────────────────┘
```

POST `/api/action-card/:cardId/farmer-input` body `{ text?, imageUrls? }`. Validates:
- text ≤ 500 chars
- imageUrls: each must be a presigned URL from our uploader (anti-SSRF)
- max 3 images per submission

Server writes to today's card's `farmerInput`. The next morning's cron consumes it and sets `acknowledged: true` after using it.

## 10. Validation guardrails

`ai-response.validator.js` enforces (server-side, not just LLM-side):

```js
validateItem(item, profile):
  - item.verb ∈ ALL_VERBS               (drop otherwise)
  - item.cropEntryId matches profile.crops    (drop otherwise)
  - item.chemical ∉ BANNED_CHEMICALS    (regex match; case-insensitive)
  - item.dose matches /\d+(\.\d+)?\s*(g|ml|kg|l|gm|grams?)\s*(\/L|\/litre|\/acre|\/ha|per litre|per acre)?/i
  - item.urgency ∈ ['low','normal','high','urgent']
  - item.title length ≤ 200
  - item.detail length ≤ 600
  - item.rationaleTags: array of snake_case strings, max 8
```

If 0 valid AI items survive → fall through entirely to the rule engine (Sprint 1 path).

## 11. Rollout

| Stage | Cohort | Duration | Watch |
|---|---|---|---|
| 1 — internal beta | 5 staff | 3 days | response quality, latency P95 |
| 2 — 5% users | 5k | 5 days | done/skip ratio, fallback rate, $/card |
| 3 — 20% users | 20k | 7 days | cost trajectory vs forecast |
| 4 — 50% users | 50k | 7 days | cron P95 wall-clock < 10 min |
| 5 — 100% | 100k | — | full rollout |

Feature flag: `FF_ACTION_CARD_AI_FIRST` (server-side, in `AiProviderConfig.extras` or env). If disabled, builder runs Sprint 1's rule-first path.

Killswitches (extend the existing `/api/admin/ai-ops/killswitch/:target`):
- `action_card_ai` — engages rule-only mode
- `action_card_images` — engages text-only AI calls (skips image fetching)

## 12. What we keep from Sprint 1

- Models (`CropTaskTemplate`, `DailyActionCard`, `ActivityJournal`).
- Rule engine (now safety net).
- Localizer.
- Verb glossary.
- Migrations.
- Internal AI endpoint (extended for vision).
- Smoke test (extended with multimodal scenarios).

## 13. Implementation order

1. **Schema** — extend `DailyActionCard.farmerInput`.
2. **image-context.service** — collect 7d images.
3. **ai-prompt.builder** + **ai-response.validator** — strict-JSON contract.
4. **ai-builder.service** — Vertex call via internal endpoint.
5. **Internal AI endpoint** — extend `/api/ai/internal/chat` with vision path (`/api/ai/internal/vision`).
6. **card.builder** — invert to AI-first; merge with rule fallback.
7. **farmer-input.service** + endpoint.
8. **Smoke test** with mocked Vertex.

That's roughly **3 engineer-days backend** + **0.5 day for the mobile farmer-input row** (Sprint 2 of Build A absorbs that). All other Sprint 1 work — models, migrations, rule engine, localizer — stays.

## 14. Risks

| Risk | Mitigation |
|---|---|
| Hallucinated chemical / dose | Server-side validator catches both. Bad item dropped, rule engine fills the slot. |
| Vertex multimodal quota throttle | Existing token-bucket rate limiter (200 ms wait, fail-fast). Worker pool of 16. |
| Cost overrun | Per-user daily $ cap (already exists). Per-card cap on image count (5). Killswitch downgrades to text-only or rule-only. |
| Stale images skewing AI ("yellow leaves last week") | Pass image timestamps in the prompt context; AI is told to weight recency. |
| Privacy leak via consultant images | Only images from chats the user participates in; image fetch goes through our presigned URL flow (auth'd). Vertex receives base64 inline data, not raw S3 URLs. |
| Farmer didn't share any images | AI call goes text-only — same shape, no images attached. Cost drops to ~$0.0002. |
| Farmer-input gets abused (spam) | Rate limit: 1 farmer-input write / hour / user. Validator on server. |
| Latency on flaky 4G | Generation is server-side cron, not request-blocking. Mobile reads the pre-built card. Latency only visible on `regenerate` POST. |

## 15. What this doesn't change

- Build B (voice chat) is still planned next. The farmer-input field is text+photo at launch; voice gets added when Build B ships.
- Mobile UI shape is identical — same card, same Done/Skip/Tell-me-more, just adds the farmer-input row at the bottom.
- The 13 launch templates (top-10 crops × ~5 templates) still get curated and seeded — they're the safety net + the agronomy team's training-data signal for what good recommendations look like.

---

Implementation starts now. See git for code.
