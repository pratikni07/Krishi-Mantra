# 04 — Data Model Changes

All schemas are Mongoose. File paths are the *target* locations (new files).

## 1. New: `FarmProfile`

**Location:** `Backend-JS/main-service/src/model/FarmProfile.js`

One document per user. Deliberately separate from `UserDetail` so it can grow (crops, practices, equipment, IoT devices) without bloating the user document.

```js
const mongoose = require("mongoose");

const cropEntrySchema = new mongoose.Schema(
  {
    cropId:      { type: mongoose.Schema.Types.ObjectId, ref: "Crop", required: true, index: true },
    cropName:    { type: String, required: true },              // denormalized for prompt speed
    variety:     { type: String, trim: true },                  // free text or dropdown value
    area:        { type: Number, required: true, min: 0 },      // in the unit below
    areaUnit:    { type: String, enum: ["acre", "hectare", "bigha", "gunta"], default: "acre" },
    sowingDate:  { type: Date, required: true, index: true },
    expectedHarvestDate: { type: Date },                        // auto-derived from growingPeriod, editable
    growthStage: {
      type: String,
      enum: [
        "pre_sowing", "germination", "seedling", "vegetative",
        "flowering", "fruiting", "maturity", "harvested"
      ],
      default: "vegetative",
    },
    plantingMethod: {
      type: String,
      enum: ["direct_sowing", "transplanting", "broadcasting", "line_sowing", "other"],
    },
    irrigationMethod: {
      type: String,
      enum: ["rainfed", "drip", "sprinkler", "flood", "furrow", "other"],
    },
    notes: { type: String, maxlength: 500 },
    isActive: { type: Boolean, default: true }, // soft-delete a crop w/o loading history
  },
  { timestamps: true, _id: true }
);

const farmProfileSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId, ref: "User",
      required: true, unique: true, index: true,
    },

    // Farmer basics
    age:    { type: Number, min: 10, max: 120 },
    gender: { type: String, enum: ["male", "female", "other", "prefer_not_to_say"] },
    preferredLanguage: { type: String, default: "en" },         // ISO 639-1

    // Location
    location: {
      type: { type: String, enum: ["Point"], default: "Point" },
      coordinates: { type: [Number], required: true }, // [lon, lat]
    },
    address: {
      village: String,
      taluka:  String,
      district:{ type: String, index: true },
      state:   { type: String, index: true },
      country: { type: String, default: "India" },
      pincode: String,
    },

    // Farm
    totalArea:         { type: Number, min: 0 },
    totalAreaUnit:     { type: String, enum: ["acre", "hectare", "bigha", "gunta"], default: "acre" },
    ownership:         { type: String, enum: ["owned", "leased", "shared", "mixed"] },
    soilTypes:         [{ type: String, enum: ["sandy","loam","clay","black","red","laterite","alluvial","silty"] }],
    irrigationSources: [{ type: String, enum: ["borewell","canal","river","pond","rainfed","drip","sprinkler"] }],
    experienceYears:   { type: Number, min: 0, default: 0 },

    // Many-crop support
    crops: [cropEntrySchema],

    // For the context-tree
    profileFingerprint: { type: String, index: true }, // sha1 of canonicalized profile
    profileVersion:     { type: Number, default: 1 },  // bumped on every save; cache-buster
    onboardingStatus: {
      type: String, enum: ["not_started", "in_progress", "completed"], default: "not_started",
    },
  },
  { timestamps: true }
);

farmProfileSchema.index({ location: "2dsphere" });
farmProfileSchema.index({ "address.state": 1, "address.district": 1 });

// Bump version + rewrite fingerprint on any save
farmProfileSchema.pre("save", function (next) {
  if (this.isModified() && !this.isNew) this.profileVersion += 1;
  this.profileFingerprint = require("../utils/fingerprint").farmProfile(this);
  next();
});

module.exports = mongoose.model("FarmProfile", farmProfileSchema);
```

### Indexing rationale
- `userId` unique — look up by user is by far the dominant read.
- `location: 2dsphere` — used for weather-bucket assignment and regional cohort analytics.
- `(state, district)` — for admin/regional dashboards.
- `profileFingerprint` — used by context-tree cache lookup (see doc 07).

### Why not nest in `UserDetail`?
`UserDetail` is a thin social profile (followers, subscription, rating). `FarmProfile` is domain data that a whole subsystem (AI) reads every turn. Keeping them separate:
- Lets us cache `FarmProfile` alone in Redis without pulling follower lists.
- Lets us version it without churning UserDetail.
- Matches the "single-purpose collection" hygiene already present elsewhere (`CropCalendar`, `Region`).

## 1a. New: `AiProviderConfig` (admin-managed)

**Location:** `Backend-JS/main-service/src/model/AiProviderConfig.js`

One document per configured provider. Exactly one has `isActive: true` at any time — enforced by a partial unique index.

```js
const mongoose = require("mongoose");

const encryptedBlobSchema = new mongoose.Schema(
  {
    iv:         { type: String, required: true },  // base64, 12 bytes
    tag:        { type: String, required: true },  // base64, 16 bytes (GCM auth tag)
    ciphertext: { type: String, required: true },  // base64
    kekAlias:   { type: String },                  // KMS key alias / "local" for env-key
  },
  { _id: false }
);

const credentialsSchema = new mongoose.Schema(
  {
    type: {
      type: String,
      enum: ["api_key", "service_account_json", "wif"],
      required: true,
    },
    payload:       { type: encryptedBlobSchema, required: true },
    fingerprint:   { type: String, required: true }, // sha256 of plaintext, hex
    lastRotatedAt: { type: Date,   default: Date.now },
  },
  { _id: false }
);

const aiProviderConfigSchema = new mongoose.Schema(
  {
    provider:    { type: String, enum: ["openai", "vertex"], required: true, index: true },
    displayName: { type: String, required: true },

    models: {
      chat:   { type: String, required: true },  // "gpt-4.1-mini" | "gemini-2.5-flash" | ...
      vision: { type: String, required: true },
      embed:  { type: String, required: true },
    },

    credentials: { type: credentialsSchema, required: true },

    extras: {
      // OpenAI: orgId, apiKeysCount (derived), baseUrl (optional override)
      // Vertex: project, location, regions[], safetySettings{}
      type: mongoose.Schema.Types.Mixed, default: {},
    },

    status: {
      type: String,
      enum: ["unvalidated", "valid", "credential_invalid", "error"],
      default: "unvalidated",
    },
    lastValidatedAt: Date,
    lastError:       String,

    autoFallback: { type: Boolean, default: false }, // allow failover to another config if this goes red

    isActive: { type: Boolean, default: false },

    createdBy: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
    updatedBy: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
  },
  { timestamps: true }
);

// Exactly one active config at a time
aiProviderConfigSchema.index(
  { isActive: 1 },
  { unique: true, partialFilterExpression: { isActive: true } }
);

module.exports = mongoose.model("AiProviderConfig", aiProviderConfigSchema);
```

### Indexing rationale
- Partial unique on `isActive=true` is the DB-level guard against two providers active simultaneously. Admin mutations still use a Mongo session, but this is the belt for the suspenders.
- Non-unique on `provider` for list queries grouped by provider.

### `AiProviderAudit`
```js
{
  configId:  ObjectId, provider: String,
  action:    enum["create","update","validate","activate","deactivate","rotate","delete"],
  actor:     ObjectId (User),
  diff:      Mixed,         // redacted (never includes plaintext credentials)
  at:        Date, ip:      String, userAgent: String,
}
```
Retained 2 years. Queried by `/api/admin/ai-provider/audit`.

### Why a dedicated collection and not a settings key-value row?
- Rich structure (per-model selection, per-provider `extras`, encrypted blob) doesn't fit a flat KV.
- Multiple saved configs exist simultaneously (switching between them shouldn't require re-typing credentials).
- Audit trail + validation status need their own indexed fields.

## 2. Amended: `UserDetail`

Add only a **pointer** so main-service can populate quickly without denormalizing:

```js
farmProfile: { type: mongoose.Schema.Types.ObjectId, ref: "FarmProfile" }
```

Everything else stays.

## 3. New: `WeatherSnapshot`

**Location:** `Backend-JS/message-svc/src/models/weather-snapshot.model.js`

Cache-grade storage — most reads go through Redis first, Mongo is the durability tier.

```js
const mongoose = require("mongoose");

const dayWxSchema = new mongoose.Schema(
  {
    date:            { type: Date, required: true },       // 00:00 UTC of that day
    tempMin:         Number,  // °C
    tempMax:         Number,
    humidityMean:    Number,  // %
    rainfallMm:      Number,
    windSpeedKmh:    Number,
    conditionCode:   Number,  // WMO code
    conditionLabel:  String,  // "sunny", "rainy", "cloudy", …
  },
  { _id: false }
);

const snapshotSchema = new mongoose.Schema(
  {
    bucket: { type: String, required: true, unique: true, index: true }, // e.g. "19.99,73.78"
    lat:    { type: Number, required: true },
    lon:    { type: Number, required: true },
    asOf:   { type: Date, required: true },                 // fetchedAt
    days:   { type: [dayWxSchema], validate: v => v.length === 7 }, // D-3..D+3
    provider: { type: String, enum: ["open-meteo", "openweather"], required: true },
    expiresAt: { type: Date, index: { expires: 0 } },        // TTL index → auto-delete
  },
  { timestamps: true }
);

module.exports = mongoose.model("WeatherSnapshot", snapshotSchema);
```

- `bucket` is rounded `lat,lon` to 2 decimal places (~1.1 km) so nearby farmers share a snapshot.
- TTL (`expiresAt`) typically `asOf + 1h`. The Redis layer's TTL is shorter (15 min) — Mongo is the fallback if Redis evicts.

## 4. Amended: `AIChat`

Add the following fields to `messages[]` and the top level.

### Top-level additions
```js
farmProfileRef: {
  profileId:         { type: mongoose.Schema.Types.ObjectId, ref: "FarmProfile" },
  profileVersionAtCreation: Number,     // for future audit of which profile led to this chat
},

usage: {
  totalPromptTokens:     { type: Number, default: 0 },
  totalCachedTokens:     { type: Number, default: 0 },
  totalCompletionTokens: { type: Number, default: 0 },
  estimatedUsdCost:      { type: Number, default: 0 },
  modelBreakdown: { type: Map, of: Number, default: {} }, // {"gpt-4.1-mini": 12345, "gpt-4o-mini": 500}
},

summary: {
  text:          { type: String, default: "" },  // running summary of collapsed turns
  summarizedUpTo:{ type: Number, default: 0 },   // index in messages[] up to which summary covers
  summaryTokens: { type: Number, default: 0 },
},

contextFingerprint: String,   // last assembled-tree hash; debug aid
```

### Per-message additions (on the existing embedded schema)
```js
tokenUsage: {
  prompt:     Number,
  cached:     Number,
  completion: Number,
  costUsd:    Number,
},
model:  String,            // "gpt-4.1-mini" / "gpt-4o-mini"
provider: { type: String, default: "openai" },
```

Nothing is renamed. Old chats keep working — new fields default to zeros/empty.

## 5. New (optional, phase 2): `ContextCacheDoc`

If Redis proves insufficient for stable layer caching (unlikely — we expect <1 GB), we can persist cached prompt layers:

```js
{
  fingerprint: { type: String, unique: true, index: true },
  layerName:   { type: String, index: true },   // "farm-profile" | "weather" | "chat-summary"
  content:     String,
  tokenEst:    Number,
  builtAt:     Date,
  expiresAt:   { type: Date, index: { expires: 0 } },
}
```

Default plan: **skip this model**. Redis-only is enough.

## 6. Migrations

### Migration M1 — create `farm_profiles` collection
Up: create empty `FarmProfile` collection, create indexes.
Down: drop collection.
Safe on live traffic.

### Migration M2 — backfill `UserDetail.farmProfile` pointer
For every existing `UserDetail` with no `farmProfile`, create an empty `FarmProfile` doc with `onboardingStatus: "not_started"` and point to it.
- Forces all existing users through the new onboarding on next login (see doc 05 §6 for the "complete your profile" nudge).
- Batched, 500 users/batch, runs via `scripts/backfillFarmProfiles.js`.
- Idempotent — checks for existing pointer first.

### Migration M3 — add `ai_chats.usage`, `.summary`, `.farmProfileRef`
Up: `$set` defaults on all docs missing the fields. Low priority; lazy-init on next chat write also works.
Down: `$unset`.

### Migration M4 — create `weather_snapshots` with TTL index
Up: create collection + `{ expiresAt: 1, expireAfterSeconds: 0 }`.
Down: drop.

### Migration M5 — seed `AiProviderConfig` from existing env (bootstrap)
- One-off script. If no `AiProviderConfig` rows exist AND env has legacy keys, create an initial row:
  - If `OPENAI_API_KEYS` set → seed an OpenAI config, validate, `isActive=true`.
  - Else skip; admin must create manually.
- Idempotent (checks existing rows before insert).
- Purpose: avoids a cold-start state where the `registry` mode has no active provider.

Scripts placed under `Backend-JS/main-service/src/scripts/migrations/` and run via `node seedAll.js migrations` (existing entrypoint).

## 7. Redis key shapes

| Key | Value | TTL | Set by |
|-----|-------|-----|--------|
| `farm-profile:{userId}` | JSON FarmProfile (lean) | 10 min | main-service on write, invalidated by pub/sub |
| `farm-profile:fp:{userId}` | profileFingerprint | 10 min | same |
| `weather:{bucket}` | JSON WeatherSnapshot | 15 min | weather.service |
| `ctx-layer:core:{lang}` | assembled core-prompt string | 24 h | context-tree.service (rarely changes) |
| `ctx-layer:profile:{fp}` | assembled profile string | 1 h | context-tree.service |
| `ctx-layer:weather:{bucket}:{date}` | assembled weather string | 30 min | context-tree.service |
| `ctx-layer:summary:{chatId}:{summarizedUpTo}` | assembled summary string | 2 h | context-tree.service |
| `chat-turns:{chatId}` | last 10 turns (JSON) | 6 h | ai.controller write-through |
| `ai:provider-override:{userId}` | config id (not provider name) | none | manual, for beta testing |
| `ai:daily-cost:{userId}:{yyyy-mm-dd}` | cumulative $ cents | 48 h | Provider module |
| `ai-config:active-provider` | JSON serialized `AiProviderConfig` (lean) | 5 min | ai-config.service; invalidated by `ai-config.changed` pub/sub |
| `vertex:ctx-cache:{fp}` | Vertex cached-content resource name | 1 h | vertex.provider (when prefix ≥ 4k tokens) |
| `ai:killswitch:openai` / `:vertex` / `:global` | `"1"` | none | ops |

All keys prefixed with env (`prod:`, `stg:`) via existing Redis client config.

## 8. Sample documents (realistic, for review)

### A `FarmProfile` with 2 crops
```json
{
  "_id": "66293...",
  "userId": "6612a...",
  "age": 38,
  "gender": "male",
  "preferredLanguage": "mr",
  "location": { "type":"Point", "coordinates":[73.79,19.99] },
  "address": { "village":"Sinnar","taluka":"Sinnar","district":"Nashik","state":"Maharashtra","country":"India","pincode":"422103" },
  "totalArea": 1.5, "totalAreaUnit": "hectare",
  "ownership": "owned",
  "soilTypes": ["black","loam"],
  "irrigationSources": ["borewell","drip"],
  "experienceYears": 15,
  "crops": [
    {
      "_id":"c1","cropId":"6f2...","cropName":"Tomato","variety":"Himsona",
      "area":1.2,"areaUnit":"hectare","sowingDate":"2026-03-05T00:00:00Z",
      "expectedHarvestDate":"2026-06-10T00:00:00Z",
      "growthStage":"fruiting","plantingMethod":"transplanting","irrigationMethod":"drip",
      "isActive":true
    },
    {
      "_id":"c2","cropId":"7b1...","cropName":"Onion","variety":"N-53",
      "area":0.3,"areaUnit":"hectare","sowingDate":"2026-04-09T00:00:00Z",
      "growthStage":"seedling","plantingMethod":"direct_sowing","irrigationMethod":"sprinkler",
      "isActive":true
    }
  ],
  "profileFingerprint": "9a1e…",
  "profileVersion": 4,
  "onboardingStatus": "completed"
}
```

### A `WeatherSnapshot`
```json
{
  "bucket":"19.99,73.79",
  "lat":19.99,"lon":73.79,
  "asOf":"2026-04-21T03:00:00Z",
  "provider":"open-meteo",
  "days":[
    { "date":"2026-04-18","tempMin":22,"tempMax":35,"humidityMean":48,"rainfallMm":0,"windSpeedKmh":9,"conditionCode":1,"conditionLabel":"sunny" },
    { "date":"2026-04-19","tempMin":23,"tempMax":36,"humidityMean":45,"rainfallMm":0,"windSpeedKmh":11,"conditionCode":1,"conditionLabel":"sunny" },
    { "date":"2026-04-20","tempMin":23,"tempMax":37,"humidityMean":42,"rainfallMm":0,"windSpeedKmh":13,"conditionCode":2,"conditionLabel":"mostly-sunny" },
    { "date":"2026-04-21","tempMin":24,"tempMax":38,"humidityMean":40,"rainfallMm":0,"windSpeedKmh":14,"conditionCode":2,"conditionLabel":"mostly-sunny" },
    { "date":"2026-04-22","tempMin":24,"tempMax":38,"humidityMean":41,"rainfallMm":0,"windSpeedKmh":12,"conditionCode":2,"conditionLabel":"mostly-sunny" },
    { "date":"2026-04-23","tempMin":23,"tempMax":36,"humidityMean":55,"rainfallMm":3,"windSpeedKmh":15,"conditionCode":61,"conditionLabel":"light-rain" },
    { "date":"2026-04-24","tempMin":22,"tempMax":34,"humidityMean":62,"rainfallMm":8,"windSpeedKmh":18,"conditionCode":63,"conditionLabel":"rain" }
  ],
  "expiresAt":"2026-04-21T04:00:00Z"
}
```
