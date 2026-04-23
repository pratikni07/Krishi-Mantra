# 05 — Onboarding & Profile Flow

Covers the new multi-step signup, the "edit my farm" flow, and the backend contract that powers both.

## 1. Overall UX flow

```
Language pick  →  Phone + OTP  →  Signup (name, photo)
     (existing, unchanged)
                                         │
                                         ▼
                             ┌──────────────────────┐
                             │  Onboarding Step 1    │   Location + basic farmer info
                             │  "Where is your farm?"│
                             └──────────┬────────────┘
                                        ▼
                             ┌──────────────────────┐
                             │  Onboarding Step 2    │   Farm size, ownership,
                             │  "About your farm"    │   soil, irrigation, experience
                             └──────────┬────────────┘
                                        ▼
                             ┌──────────────────────┐
                             │  Onboarding Step 3    │   Add crops (1..N)
                             │  "What do you grow?"  │   multi-select + per-crop details
                             └──────────┬────────────┘
                                        ▼
                             ┌──────────────────────┐
                             │  Onboarding Step 4    │   Review & confirm
                             │  "Does this look right?"│
                             └──────────┬────────────┘
                                        ▼
                             ┌──────────────────────┐
                             │     Home screen       │
                             └──────────────────────┘
```

### Principles
- **All four steps can be skipped** (except Step 1 location, which is required to fetch weather). Skip → `onboardingStatus = "in_progress"`, user lands on home, but a persistent banner on the AI screen says "Complete your farm profile for personalized advice" until done.
- **Every step autosaves to local storage** on "Next", so a dropped 2G call doesn't lose the form.
- **Each step submits to backend on "Next"** (not just at the end) so if the user gets a push notification and leaves the flow, their data is durable.
- **Back navigation is allowed** between steps.
- **Existing signup** (name, photo) stays as Step 0. Only adds four new screens after it.

## 2. Step-by-step field list

### Step 1 — Location & you
| Field | Type | Required | Source | Notes |
|-------|------|----------|--------|-------|
| Location | GPS auto-detect + manual override map | **yes** | `geolocator` | Store `[lon, lat]`. If GPS denied, manual pin on map. |
| Address | Computed from reverse-geocode (Nominatim or existing geo API), editable | no | | Fill `village, taluka, district, state, pincode`. |
| Age | Number | no | manual | 10–120. |
| Gender | Dropdown | no | manual | male / female / other / prefer not to say. |
| Preferred language | Dropdown | yes (pre-filled) | `LanguageService` | Pre-filled from Language Selection screen. |

On submit → `POST /api/farm-profile` with just these fields → backend creates doc with `onboardingStatus: "in_progress"`.

### Step 2 — About your farm
| Field | Type | Required | Notes |
|-------|------|----------|-------|
| Total land area | Number | yes | |
| Unit | Segmented: acre / hectare / bigha / gunta | yes | Remembered as default for per-crop area. |
| Ownership | Segmented: owned / leased / shared / mixed | no | |
| Soil types | Multi-select chips | no | sandy, loam, clay, black, red, laterite, alluvial, silty. |
| Irrigation sources | Multi-select chips | no | borewell, canal, river, pond, rainfed, drip, sprinkler. |
| Experience (years) | Number slider 0–70 | no | |

On submit → `PATCH /api/farm-profile` with step-2 fields.

### Step 3 — Crops
Multi-crop editor. For each crop a card lets the user fill:

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| Crop | Searchable dropdown from `GET /api/farm-profile/master/crops` | yes | Typeahead over `Crop` master. |
| Variety | Free text with suggestions | no | Phase 2: pull suggestions per crop. |
| Area | Number + unit | yes | Unit defaults to step-2 unit. |
| Sowing date | Date picker, max = today | yes | This is the "age of crop". |
| Growth stage | Auto-suggested from sowing date + `Crop.growingPeriod`, editable | no | `pre_sowing → seedling → vegetative → flowering → fruiting → maturity → harvested`. |
| Expected harvest | Auto = sowing + growingPeriod, editable | no | |
| Planting method | Dropdown | no | |
| Irrigation method | Dropdown, default from step-2 irrigation sources | no | |

Controls:
- `[+ Add another crop]` button → new card, validation fires per card.
- Card can be collapsed/expanded (summary row: "🍅 Tomato · 1.2 ha · 47 days").
- Swipe-to-delete with confirmation.

On "Next" with ≥1 crop → `POST /api/farm-profile/crops` (bulk or one-by-one; we pick one-by-one for per-crop error granularity).

### Step 4 — Review & confirm
Read-only summary of steps 1–3 with "Edit" chips jumping back. "Confirm" → `PATCH /api/farm-profile { onboardingStatus: "completed" }`.

## 3. Backend contracts

### `POST /api/farm-profile`
Auth: JWT. Body (step 1):
```json
{
  "location": { "coordinates": [73.79, 19.99] },
  "address": { "village":"…","district":"…","state":"…","pincode":"…" },
  "age": 38, "gender": "male",
  "preferredLanguage": "mr",
  "onboardingStatus": "in_progress"
}
```
Behavior: upsert by `userId`. 200 returns the full document.

### `PATCH /api/farm-profile`
Partial update. Enforces ownership (caller must be `userId`). Fields of steps 2/4 go here.

### `POST /api/farm-profile/crops`
Body:
```json
{
  "cropId": "6f2…", "variety":"Himsona",
  "area":1.2, "areaUnit":"hectare",
  "sowingDate":"2026-03-05",
  "growthStage":"fruiting",
  "plantingMethod":"transplanting",
  "irrigationMethod":"drip"
}
```
Returns the created crop entry's `_id`.

### `PATCH /api/farm-profile/crops/:cropEntryId`
Partial update.

### `DELETE /api/farm-profile/crops/:cropEntryId`
Soft-deletes (`isActive: false`) by default. `?hard=true` for actual pull.

### `GET /api/farm-profile/master/crops?q=tom&limit=20`
Searches `Crop` master by `name` / `scientificName` (case-insensitive, prefix + fuzzy). Returns:
```json
[{ "_id":"6f2…","name":"Tomato","scientificName":"Solanum lycopersicum","imageUrl":"…","growingPeriod":90 }, …]
```

### `GET /api/farm-profile/me`
Returns full profile with crops expanded. Used on app resume and on "Edit Farm" screen.

### Error responses
Uniform: `{ success: false, code: "BAD_AREA", message: "…" }`. Validation errors are per-field:
```json
{ "success": false, "errors": { "sowingDate": "cannot be in the future" } }
```

## 4. Controllers (main-service)

New file `Backend-JS/main-service/src/controller/FarmProfile.js`:

- `upsertProfile` — validate location, upsert, bump `profileVersion`, publish `farm-profile.updated`.
- `patchProfile` — merge, validate, publish.
- `addCrop`, `patchCrop`, `deleteCrop` — stitch into the embedded array; validate per-crop; publish.
- `searchCrops` — simple Mongo regex on `Crop.name`. Cap at 50 results.

Pub/sub on Redis channel `farm-profile.updated`:
```json
{ "userId":"6612a…", "profileVersion":5, "fingerprint":"9a1e…" }
```
`message-svc` subscribes and deletes `farm-profile:{userId}` + `ctx-layer:profile:{oldFp}` from its Redis.

## 5. Edit farm profile (post-onboarding)

Entry points:
1. Profile screen → "My Farm" card.
2. AI chat → empty-state card "Complete your farm profile".
3. Settings screen → "Farming info".

Screen reuses the three step widgets as a tabbed view (`Location | Farm | Crops`). Saves are per-tab via the same PATCH endpoints. No "submit all at once" — every "Save" is atomic.

## 6. Nudging existing users

All users pre-migration will have `onboardingStatus: "not_started"` (M2 backfill). Behavior:
- **AI screen:** show a non-dismissible banner — "For best advice, tell us about your farm → Complete profile". Tapping opens the onboarding flow (exits to home on completion).
- **Home:** show a soft card on day 1, 3, 7 after first login if still incomplete. Dismissible but reappears after 7 days.
- We do **not** block the AI feature — farmers without a profile still get generic advice (core layer only). We just can't personalize.

## 7. Validation rules (server enforced)

- `location.coordinates` required; `lon ∈ [-180,180]`, `lat ∈ [-90,90]`.
- `age` if provided: 10–120.
- `totalArea > 0`.
- `sowingDate ≤ today + 7d` (allow 1-week look-ahead for planning).
- `expectedHarvestDate > sowingDate`.
- Per-crop `area > 0`, `area ≤ totalArea` (warning only, not blocking — user might have more land than they declared).
- Max 20 crops per profile. (Unlikely to hit; protects from pathological input.)
- `preferredLanguage` must be in supported list.

## 8. Analytics events

Emit via existing tracker:
- `farm_profile_started` (step entered)
- `farm_profile_step_completed` `{ step, timeSpentMs }`
- `farm_profile_completed` `{ totalTimeMs, cropCount }`
- `farm_profile_skipped` `{ lastStepCompleted }`
- `crop_added` `{ cropName }` / `crop_removed`

Used for funnel analysis and tuning defaults (e.g. if 80% of users skip "irrigation sources", we simplify).

## 9. Offline/draft handling (mobile)

- Every "Next" writes to a single `SharedPreferences` key `farm_profile_draft` as JSON.
- Draft merged with server response on app open if `onboardingStatus != completed`.
- Cleared on `farm_profile_completed`.

## 10. Accessibility / i18n

- All labels translated via `LanguageService`. Language pre-selected from earlier step.
- Large touch targets (≥48 dp) for farmers on field.
- Area input accepts local decimal separator.
- Date picker uses local calendar format.
- Images/icons for crops from `Crop.imageUrl` for visual recognition (farmers often don't read well).
