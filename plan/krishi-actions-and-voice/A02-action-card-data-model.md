# A02 — Today's Action Card: Data Model

All schemas are Mongoose. New collections live in **main-service** (next to `FarmProfile`). The `DailyActionCard` and `ActivityJournal` collections are write-heavy — the cron and the mobile app both write — so indexes are tight.

## 1. New: `CropTaskTemplate`

The author-once knowledge base of "what should you do for crop X at stage Y under weather W". Built up by the agronomy team; seedable from the existing `CropCalendar.Activity` records.

**Location:** `Backend-JS/main-service/src/model/CropTaskTemplate.js`

```js
const mongoose = require("mongoose");

const cropTaskTemplateSchema = new mongoose.Schema(
  {
    cropId: { type: mongoose.Schema.Types.ObjectId, ref: "Crop", required: true, index: true },
    cropName: { type: String, required: true, index: true }, // denormalized for fast text match

    stage: {
      type: String,
      enum: [
        "pre_sowing", "germination", "seedling", "vegetative",
        "flowering", "fruiting", "maturity", "harvested",
      ],
      required: true, index: true,
    },

    // Window relative to sowing date (in days). Both bounds inclusive.
    daysFromSowingMin: { type: Number, required: true, min: 0 },
    daysFromSowingMax: { type: Number, required: true, min: 0 },

    // Action verb shown on the card. Used as a key for translations.
    verb: {
      type: String,
      enum: [
        "spray_fungicide", "spray_insecticide", "spray_herbicide",
        "fertilize", "irrigate", "scout", "weed", "prune",
        "stake", "thin", "harvest_check", "soil_test", "mulch",
      ],
      required: true,
    },

    // Free-text title in EN — translated at render time. Variables substituted:
    //   {crop}, {variety}, {dose}, {chemical}, {dosePerLitre}.
    titleTemplate: { type: String, required: true, maxlength: 200 },
    detailTemplate: { type: String, maxlength: 600 },

    chemical: { type: String },          // generic active; null if not chem-related
    dose: { type: String },              // e.g. "2.5 g/L spray", "50 kg/acre"
    safetyNote: { type: String, maxlength: 200 },

    urgency: {
      type: String,
      enum: ["low", "normal", "high", "urgent"],
      default: "normal",
    },

    // Weather gating — action is suggested only if these conditions hold.
    weather: {
      requiresDryDays: { type: Number, default: 0 },   // e.g. 1 = no rain in next 24 h
      maxRainfallMmTomorrow: { type: Number },         // skip spray if rain > this
      minTempC: { type: Number },
      maxTempC: { type: Number },
      requiresMoistSoil: { type: Boolean, default: false }, // crude proxy: rain in last 48 h
    },

    // Cooldown — don't suggest the same template twice within this many days
    // for the same user/crop pair.
    cooldownDays: { type: Number, default: 7 },

    // Region/season filters (optional; null means "any").
    seasons: [{ type: String, enum: ["Kharif", "Rabi", "Zaid"] }],
    regions: [String],   // state names — broad filter

    isActive: { type: Boolean, default: true, index: true },
    sourceRefs: [String], // doc URLs / agronomist sign-off id
  },
  { timestamps: true }
);

cropTaskTemplateSchema.index({ cropId: 1, stage: 1, isActive: 1 });
cropTaskTemplateSchema.index({ cropName: "text" });

module.exports = mongoose.model("CropTaskTemplate", cropTaskTemplateSchema);
```

### Indexing rationale
- `(cropId, stage, isActive)` — the engine's primary lookup.
- `cropName` text — fallback when intent-router gives a crop name not in `Crop` master.

### Why a new collection vs reusing `CropCalendar.Activity`?
`CropCalendar.Activity` is a free-form list of activities with a `Crop` link. It doesn't carry weather gating, urgency, dose templates, or i18n keys. Rather than overload it, we **import** from it during seeding and add the engine-specific fields here. The agronomy team curates the templates; the existing calendar data feeds the seed script.

## 2. New: `DailyActionCard`

One document per user per local-day. Cron writes it overnight; app reads it in the morning. TTL'd after 30 days.

**Location:** `Backend-JS/main-service/src/model/DailyActionCard.js`

```js
const mongoose = require("mongoose");

const actionItemSchema = new mongoose.Schema(
  {
    // Stable id — reused if the same template + crop + day is regenerated.
    itemId: { type: String, required: true },

    cropEntryId: { type: mongoose.Schema.Types.ObjectId, required: true }, // FarmProfile.crops._id
    cropName: { type: String, required: true },
    cropVariety: { type: String },

    templateId: { type: mongoose.Schema.Types.ObjectId, ref: "CropTaskTemplate" }, // null if AI-generated
    source: { type: String, enum: ["template", "ai", "weather_alert", "manual"], required: true },

    verb: { type: String, required: true },          // matches CropTaskTemplate.verb
    title: { type: String, required: true },         // already localized
    detail: { type: String },                        // already localized
    chemical: { type: String },
    dose: { type: String },
    safetyNote: { type: String },

    urgency: { type: String, enum: ["low", "normal", "high", "urgent"], default: "normal" },
    rationaleTags: [String], // e.g. ["fruiting_stage", "no_rain_48h", "47_days_after_sowing"]

    status: {
      type: String,
      enum: ["pending", "done", "skipped", "snoozed"],
      default: "pending",
      index: true,
    },
    statusUpdatedAt: { type: Date },
    snoozeUntil: { type: Date },
  },
  { _id: false }
);

const dailyActionCardSchema = new mongoose.Schema(
  {
    userId: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true, index: true },

    // Local-date key for the user's TZ. Format: "YYYY-MM-DD". One card per day.
    localDate: { type: String, required: true, index: true },
    timezone: { type: String, default: "Asia/Kolkata" },

    items: { type: [actionItemSchema], default: [] },

    // Generation metadata for debugging/regenerate logic.
    generatedAt: { type: Date, default: Date.now },
    weatherSnapshotBucket: String,
    farmProfileVersion: Number,
    generator: { type: String, enum: ["cron", "on_demand"], default: "cron" },

    // Per-card cost ledger so we can audit AI spend on action generation.
    aiUsageUsd: { type: Number, default: 0 },

    expiresAt: { type: Date, index: { expires: 0 } }, // TTL: 30 days
  },
  { timestamps: true }
);

dailyActionCardSchema.index({ userId: 1, localDate: -1 }, { unique: true });

module.exports = mongoose.model("DailyActionCard", dailyActionCardSchema);
```

### Why this shape

- `localDate` as a string: makes the unique-per-day constraint trivial and is timezone-correct without storing a `Date` of midnight in some tz.
- `items[].itemId` is a stable hash of `(templateId or "ai", cropEntryId, day_bucket)` so that if the cron runs twice on the same day (idempotency, retry) we don't duplicate items, but we *do* want to keep status changes.
- `status` lives on the item, not in a separate journal. The journal is for cross-day analytics; the card's status drives the UI.

## 3. New: `ActivityJournal`

The append-only log of what the farmer actually did. Two write paths:
1. Implicit — when they tap "Done" on an action item, we mirror to the journal.
2. Explicit — they tap "Log activity" on a crop card and pick from a quick list.

**Location:** `Backend-JS/main-service/src/model/ActivityJournal.js`

```js
const mongoose = require("mongoose");

const activityJournalSchema = new mongoose.Schema(
  {
    userId: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true, index: true },
    cropEntryId: { type: mongoose.Schema.Types.ObjectId, required: true, index: true },
    cropName: { type: String, required: true },

    verb: { type: String, required: true },
    chemical: { type: String },
    dose: { type: String },
    notes: { type: String, maxlength: 500 },

    source: {
      type: String,
      enum: ["card_done", "card_skipped", "manual_log", "ai_inferred"],
      required: true,
    },

    // For card_done/skipped, the item we mirrored from.
    cardItemId: { type: String },
    cardLocalDate: { type: String },

    // Optional photo proof — points to the existing presigned-url uploader.
    imageUrl: { type: String },

    // Local-date copy for fast queries by day.
    localDate: { type: String, required: true, index: true },
    timezone: { type: String, default: "Asia/Kolkata" },

    occurredAt: { type: Date, default: Date.now, index: true },
  },
  { timestamps: true }
);

activityJournalSchema.index({ userId: 1, occurredAt: -1 });
activityJournalSchema.index({ userId: 1, cropEntryId: 1, occurredAt: -1 });
activityJournalSchema.index({ userId: 1, verb: 1, occurredAt: -1 });

module.exports = mongoose.model("ActivityJournal", activityJournalSchema);
```

Retained 2 years. The recommendation engine queries the last 30 days; analytics queries the full set.

## 4. Amended: `FarmProfile` — notification preferences

Add a small block to the existing `FarmProfile` (doc 04 in krishi-ai); no new collection needed.

```js
notifyPrefs: {
  morningCardEnabled: { type: Boolean, default: true },
  morningCardLocalTime: { type: String, default: "07:00" }, // "HH:mm" 24h
  weatherAlertsEnabled: { type: Boolean, default: true },
  preferredChannel: { type: String, enum: ["push", "sms", "none"], default: "push" },
},
```

The morning local time is stored per user so a farmer who wakes at 4 AM can opt to be pinged at 5 AM, while another can take 8 AM. Cron schedules per-user using these.

## 5. Redis key shapes

| Key | Value | TTL | Set by |
|-----|-------|-----|--------|
| `action-card:{userId}:{yyyy-mm-dd}` | JSON of today's `DailyActionCard.items` | 24 h | cron + on-demand generator |
| `action-card-cron-lock` | "1" | 10 min | cron entrypoint (single-flight) |
| `action-card-progress:{batchId}` | "<n>/<total>" | 1 h | cron (for ops dashboard) |
| `journal-cache:{userId}:30d` | last-30-days journal slice | 1 h | engine when fetching |
| `template-cache:{cropId}:{stage}` | matching templates JSON | 6 h | engine on miss |
| `weather-stale-served:{bucket}` | "1" | 30 min | engine when fetching weather |

## 6. Migrations

### M-A1 — create the new collections
Up: create `croptasktemplates`, `dailyactioncards`, `activityjournals`. Add indexes. Idempotent.

### M-A2 — seed `CropTaskTemplate` from `CropCalendar.Activity`
- Read every `Activity` linked to an active `Crop`.
- Map `Activity.type → verb` via a hardcoded dictionary (in the script).
- Default `daysFromSowingMin/Max` to the activity's day window if present, else stage defaults.
- Mark each seed row as `source: "calendar_seed"` in `extras` so agronomy can review/promote.
- 100% manual sign-off required before flipping `isActive=true` per template.

### M-A3 — backfill `FarmProfile.notifyPrefs`
Default-on for `morningCardEnabled` because the user can opt out from the home screen banner the first morning.

### M-A4 — seed templates for the top 10 crops
Manual content step, not a code migration. Tracked separately. The 10 (in priority order):
tomato, onion, paddy/rice, wheat, cotton, sugarcane, soybean, maize, chilli, groundnut.

## 7. Sample documents

### Sample `CropTaskTemplate` (tomato fungicide spray)
```json
{
  "cropId": "6f2a...",
  "cropName": "Tomato",
  "stage": "fruiting",
  "daysFromSowingMin": 40, "daysFromSowingMax": 75,
  "verb": "spray_fungicide",
  "titleTemplate": "Spray mancozeb on {crop}",
  "detailTemplate": "{dose} {chemical}. Cover both leaf surfaces. Repeat after 7 days if symptoms persist.",
  "chemical": "mancozeb",
  "dose": "2.5 g/L",
  "safetyNote": "Wear gloves and a mask. Do not spray within 7 days of harvest.",
  "urgency": "high",
  "weather": { "requiresDryDays": 1, "maxRainfallMmTomorrow": 2 },
  "cooldownDays": 6,
  "seasons": ["Kharif", "Rabi"],
  "regions": ["Maharashtra", "Karnataka", "Andhra Pradesh"],
  "isActive": true
}
```

### Sample `DailyActionCard`
```json
{
  "userId": "6612a...",
  "localDate": "2026-04-25",
  "timezone": "Asia/Kolkata",
  "items": [
    {
      "itemId": "tpl_aaa_2026-04-25_c1",
      "cropEntryId": "c1",
      "cropName": "Tomato",
      "cropVariety": "Himsona",
      "templateId": "tpl_aaa",
      "source": "template",
      "verb": "spray_fungicide",
      "title": "टोमॅटोवर मॅन्कोझेब फवारणी",
      "detail": "2.5 g/L मॅन्कोझेब. पाने दोन्ही बाजूंनी झाकून फवारा. पुढील 7 दिवसांत पुन्हा.",
      "chemical": "mancozeb",
      "dose": "2.5 g/L",
      "safetyNote": "हातमोजे + मास्क घाला. कापणीच्या 7 दिवसांत फवारू नका.",
      "urgency": "high",
      "rationaleTags": ["47_days_after_sowing", "fruiting_stage", "no_rain_48h"],
      "status": "pending"
    },
    {
      "itemId": "tpl_bbb_2026-04-25_c2",
      "cropEntryId": "c2",
      "cropName": "Onion",
      "templateId": "tpl_bbb",
      "source": "template",
      "verb": "irrigate",
      "title": "कांद्याला पाणी द्या (drip 45 मि.)",
      "detail": "जमिनीतील ओलावा कमी. पुढील 3 दिवसांत पाऊस नाही.",
      "urgency": "normal",
      "rationaleTags": ["12_days_after_sowing", "seedling_stage", "soil_dry"],
      "status": "pending"
    }
  ],
  "generatedAt": "2026-04-25T01:30:00Z",
  "weatherSnapshotBucket": "19.99,73.79",
  "farmProfileVersion": 4,
  "generator": "cron",
  "aiUsageUsd": 0,
  "expiresAt": "2026-05-25T01:30:00Z"
}
```

### Sample `ActivityJournal` row (mirrored from "Done")
```json
{
  "userId": "6612a...",
  "cropEntryId": "c1",
  "cropName": "Tomato",
  "verb": "spray_fungicide",
  "chemical": "mancozeb",
  "dose": "2.5 g/L",
  "source": "card_done",
  "cardItemId": "tpl_aaa_2026-04-25_c1",
  "cardLocalDate": "2026-04-25",
  "localDate": "2026-04-25",
  "timezone": "Asia/Kolkata",
  "occurredAt": "2026-04-25T07:14:22Z"
}
```

## 8. Storage size estimate

- 100k DAU × 1 card/day × ~1 KB ≈ 100 MB/day. With 30-day TTL → ~3 GB steady. Fine.
- 100k DAU × 6 journal rows/week × 0.4 KB ≈ 25 GB/year (no TTL). Fine.
- `CropTaskTemplate`: < 5k rows total ever. Negligible.

## 9. Pub/Sub events

To keep the AI context tree fresh, publish on every journal write:

| Channel | Payload | Subscribers |
|---------|---------|-------------|
| `activity.logged` | `{ userId, cropEntryId, verb, occurredAt }` | message-svc → invalidates `ctx-layer:activities:{userId}:*` |
| `action-card.regenerated` | `{ userId, localDate }` | (future) home-screen socket update |

Reuses the same Redis pub/sub plumbing already wired up for `farm-profile.updated`.
