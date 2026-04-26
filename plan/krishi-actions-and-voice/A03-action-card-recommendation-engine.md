# A03 — Today's Action Card: Recommendation Engine

The engine answers, for one farmer on one day:

> Given the farmer's `FarmProfile` (crops + location), the local 7-day weather, the activity journal of the last 30 days, and the curated `CropTaskTemplate` library — pick **the best 1–3 actions** for today and return them already localized.

Two-stage design: a **rule engine** does 90% of the work (cheap, deterministic, auditable), with an **AI fallback** that fills gaps — "this farmer has a niche crop we don't have a template for" or "the rule engine produced 0 items but the journal looks unhappy."

## 1. End-to-end flow

```
generate(userId, localDate):
    1. Load FarmProfile + active crops              [main-service Mongo]
    2. For each crop:
         - Compute days_since_sowing + stage
         - Look up matching CropTaskTemplate(s)     [stage + day window + region]
         - Filter by weather gates                   [WeatherSnapshot for user's bucket]
         - Filter by cooldown                        [ActivityJournal last N days]
         - Score each candidate
       Yield candidate items per crop
    3. Cross-crop dedupe + global cap (3 items default)
    4. If candidate count < min_target (default 1) AND user has a profile:
         - Call AI generator for missing slots
    5. Localize each item to user's preferredLanguage
    6. Persist DailyActionCard
    7. Mirror urgent items to push notifications
```

Total wall-clock target: **< 200 ms per user** in the cron path (rule engine only).
**+ < 1.5 s per user** if AI fallback fires (≤ 5% of users in steady state).

## 2. Inputs the engine consumes

| Source | What we pull | Why |
|--------|-------------|-----|
| `FarmProfile` | crops[] (active), location, district/state, language | base personalization |
| `WeatherSnapshot.days[]` | tomorrow's rainfall + 7-day window | weather gating |
| `ActivityJournal` last 30d | `(verb, cropEntryId, occurredAt)` | cooldown, journal-aware nudges |
| `CropTaskTemplate` | curated rules per crop+stage | rule engine source |
| Active AI provider | `provider.chat()` — only on fallback | niche-crop generation |

The engine **never** writes to FarmProfile, weather, or templates — it's pure read except for the action card output.

## 3. Stage and day-since-sowing

```js
function stageFromDays(crop, days) {
  // Crop-specific overrides could come from CropCalendar; default fallback:
  if (days < 0)  return "pre_sowing";
  if (days < 14) return "germination";
  if (days < 30) return "seedling";
  if (days < 60) return "vegetative";
  if (days < 80) return "flowering";
  if (days < 110) return "fruiting";
  if (days < 140) return "maturity";
  return "harvested";
}
```

**Important:** if the farmer set `growthStage` manually on the crop entry (from EditFarm), trust that over the date math. The date math is the fallback.

## 4. Template matching

```js
function eligibleTemplates({ cropId, stage, daysSinceSowing, season, region }) {
  return CropTaskTemplate.find({
    cropId,
    isActive: true,
    stage,
    daysFromSowingMin: { $lte: daysSinceSowing },
    daysFromSowingMax: { $gte: daysSinceSowing },
    $or: [
      { seasons: { $size: 0 } },
      { seasons: season },
    ],
    $or: [
      { regions: { $size: 0 } },
      { regions: region },
    ],
  });
}
```

A small Redis cache on `(cropId, stage)` for 6 h removes the repeat-hit cost during the cron sweep.

## 5. Weather gating

For each candidate template, check the relevant day(s) of `WeatherSnapshot`:

```js
function weatherAllows(template, snapshot) {
  if (!snapshot) return true; // fail-open if weather is unavailable

  const today = snapshot.days[3];      // index 3 = today (D-3..D+3 layout)
  const tomorrow = snapshot.days[4];

  if (template.weather.requiresDryDays > 0) {
    const lookahead = snapshot.days.slice(4, 4 + template.weather.requiresDryDays);
    if (lookahead.some(d => (d.rainfallMm || 0) > 1)) return false;
  }
  if (template.weather.maxRainfallMmTomorrow != null) {
    if ((tomorrow?.rainfallMm || 0) > template.weather.maxRainfallMmTomorrow) return false;
  }
  if (template.weather.minTempC != null && (today?.tempMin ?? 99) < template.weather.minTempC)  return false;
  if (template.weather.maxTempC != null && (today?.tempMax ?? -99) > template.weather.maxTempC) return false;
  if (template.weather.requiresMoistSoil) {
    const last48 = snapshot.days.slice(1, 4);
    const totalRain = last48.reduce((s, d) => s + (d.rainfallMm || 0), 0);
    if (totalRain < 2) return false;
  }
  return true;
}
```

Fail-open on missing weather is intentional — we'd rather suggest a borderline action than show an empty card. The action's safety note still applies.

## 6. Cooldown

A template that fires today shouldn't fire again for `cooldownDays` for the same `(userId, cropEntryId)`. Cheaper than running the full template scan over the journal — pull the journal slice once per user and bucket by verb:

```js
const recentVerbs = journalLast30d.reduce((map, row) => {
  const key = `${row.cropEntryId}:${row.verb}`;
  const prev = map.get(key);
  if (!prev || row.occurredAt > prev) map.set(key, row.occurredAt);
  return map;
}, new Map());

function passesCooldown(template, cropEntryId) {
  const last = recentVerbs.get(`${cropEntryId}:${template.verb}`);
  if (!last) return true;
  const days = (Date.now() - last.getTime()) / 86_400_000;
  return days >= template.cooldownDays;
}
```

## 7. Scoring

Multiple eligible templates may match. Score them and pick top-K per crop:

```
score = base[urgency]                      // urgent=100, high=70, normal=40, low=20
      + journal_signal                     // +25 if recent "skipped" same verb (try a different one)
                                           // +15 if user logged "scout" with notes mentioning the verb
      + stage_fit                          // +10 if days_since_sowing in middle 50% of template window
      + weather_pressure                   // +20 if requiresDryDays > 0 AND only today is dry
      - repetition_penalty                 // -20 if same verb already scheduled for this user today
```

Per-crop cap at launch: **1 item per crop** (limits cognitive load). Global cap: **3 items**.

If a farmer has 5 crops, we still only show 3 — picked by:
1. crops with `urgent` items first,
2. then `high`,
3. then alphabetical-by-cropName as a tiebreaker (predictable, not "newest crop wins").

## 8. AI fallback

Triggers only when:
- The farmer has at least 1 active crop, AND
- The rule engine produced 0 items for that crop (no matching templates after weather + cooldown filters).

We do **not** call AI for every item — the rule engine handles the common case for free. Cost-controlled.

```js
async function aiSuggestAction({ profile, crop, weather, recentJournal, lang }) {
  const provider = await activeProvider();
  const messages = [
    {
      role: "system",
      content:
        "You are an agronomist. Output ONE recommended action for this farmer today as strict JSON: " +
        "{verb, title, detail, chemical?, dose?, safetyNote?, urgency, rationaleTags[]}. " +
        "Use only generic active ingredients (no brand names). " +
        "Reply must be in: " + LANG_NAMES[lang] + ". 60 words max in detail.",
    },
    {
      role: "user",
      content: JSON.stringify({
        crop: { name: crop.cropName, variety: crop.variety, daysSinceSowing: ..., stage: ... },
        farm: { area: profile.totalArea, areaUnit: profile.totalAreaUnit, soils: profile.soilTypes },
        weather: snapshotToCompactString(weather),
        recentActivity: recentJournal.slice(0, 8).map(r => `${r.verb}@${r.localDate}`),
      }),
    },
  ];
  const result = await provider.chat({
    messages, maxTokens: 220, temperature: 0.2,
    userId: profile.userId,
  });
  return safeJsonParse(result.text);
}
```

Cost cap: per-user-per-day at most **2 AI fallback calls**. If a farmer has 5 niche crops, they see 2 AI-generated actions on the card; the rest fall back to a "no recommendation today" placeholder.

## 9. Localization

Each candidate item (template or AI) ships through one final localization pass:

```js
function localize(item, lang) {
  // Templates carry titleTemplate / detailTemplate in EN with {placeholders}.
  // AI items return localized strings already (we asked for the user's lang).
  if (item.source === "template") {
    return {
      ...item,
      title: render(translate(item.titleTemplate, lang), item),
      detail: item.detailTemplate ? render(translate(item.detailTemplate, lang), item) : undefined,
      safetyNote: item.safetyNote ? translate(item.safetyNote, lang) : undefined,
    };
  }
  return item;
}
```

Translation strategy:
1. **First-class**: hand-curated translations stored in `CropTaskTemplate.translations.{lang}` (`{title, detail, safetyNote}`). Phase 1: en/hi/mr.
2. **Fallback**: render English with placeholders if the translation row is missing. The AI fallback path is always native because we ask the model to output in the language directly.

We **never** auto-translate at runtime — translation latency would blow the cron budget.

See A06 for tone, dialect, and the full content matrix.

## 10. Worked example

**Farmer:** Sunita, mr, Sinnar/Maharashtra. Crops: Tomato (sowed 47 days ago, stage `fruiting`), Onion (sowed 12 days, stage `seedling`).

**Weather:** today sunny, no rain forecast next 48 h.
**Journal:** 5 days ago — `irrigate` on Onion (cropEntryId c2). 8 days ago — `spray_fungicide` on Tomato (c1). Nothing else recent.

### Rule pass

For Tomato (c1, fruiting, day 47):
| Template | Eligible? | Weather OK? | Cooldown OK? | Score |
|----------|-----------|-------------|--------------|-------|
| Spray mancozeb (`cooldown=6d`) | yes | yes (no rain) | yes (8d > 6d) | 70 + 10 stage_fit + 20 dry-only = **100** |
| Stake plants | yes | yes | yes | 40 |
| Foliar Ca for blossom-end rot | yes | yes | yes | 40 |

Top per crop: **Spray mancozeb**.

For Onion (c2, seedling, day 12):
| Template | Eligible? | Weather | Cooldown | Score |
|----------|-----------|---------|----------|-------|
| Irrigate (drip 45 min) | yes | yes (dry forecast) | NO — 5d < 7d cooldown | filtered out |
| Light NPK foliar | yes | yes | yes | 40 |
| Scout for thrips | yes | yes | yes | 40 |

Tie broken by template `urgency` then alphabetical: **Light NPK foliar**.

### Final card

Two items (cap 3, both crops have one). No AI fallback needed.

### Localized output (mr)

```
1. टोमॅटोवर मॅन्कोझेब फवारणी           (urgency: high)
   2.5 g/L मॅन्कोझेब. पाने दोन्ही बाजूंनी झाकून फवारा. पुढील 7 दिवसांत पुन्हा.
   ⚠ हातमोजे + मास्क घाला. कापणीच्या 7 दिवसांत फवारू नका.

2. कांद्यासाठी हलकी NPK फवारणी          (urgency: normal)
   ...
```

## 11. Edge cases & failure modes

| Case | Behavior |
|------|---------|
| User has 0 active crops | Card returns `items: []`. Mobile shows "Complete your farm profile to see today's actions" with deep-link to FARM_ONBOARDING. |
| Weather snapshot fetch fails | Fail-open per §5. We log `weather_unavailable_for_card` and tag rationale `no_weather_check`. |
| All templates filtered out by weather | Per crop, fall through to AI fallback. If AI also fails, show a "no urgent action today; check on your crops" placeholder. |
| Template seed not yet curated for crop | Engine returns 0 candidates for that crop → AI fallback for the slot. |
| Cron retry duplicates | Idempotent: `itemId` is `(templateOrAi, cropEntryId, dayBucket)` — second cron run finds the existing item and only updates rationale/scoring; never adds a duplicate. |
| User updated FarmProfile mid-day | On-demand regenerator runs (see A04 §6) — bumps `farmProfileVersion`, regenerates only items whose crop changed. |
| User in Antarctica or invalid coords | Skip weather; engine still runs with a `region: "global"` fallback. |
| `CropCalendar` lookup latency spike | 6h Redis cache on `(cropId, stage)` shields the cron. Stale templates by 6h are acceptable. |

## 12. Auditability

Every item carries `rationaleTags[]` and (for templates) `templateId`. We persist the inputs the engine saw on the card itself (`weatherSnapshotBucket`, `farmProfileVersion`). For complaints/regression debugging:

```
GET /api/admin/action-cards/audit?userId=...&date=2026-04-25
→ returns the card + the snapshot inputs and the eligible-but-filtered list.
```

This means a support agent can answer "why did Sunita see X?" without re-running the engine.

## 13. Quality safety net

Before flipping production traffic on:
- 50-farm regression set: known-good cards from agronomy. Engine output is diffed against these weekly.
- AI-fallback outputs go through the same regex content scan as the AI chat (no brand names, no banned chemicals).
- Hard list of banned chemicals (loose endosulfan-style) is enforced server-side regardless of model output.
