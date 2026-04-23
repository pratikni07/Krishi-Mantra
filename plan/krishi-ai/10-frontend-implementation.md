# 10 — Frontend (Flutter) Implementation

Scope: onboarding screens, edit-farm screen, AI chat changes (SSE streaming + profile banner), weather plumbing, model/repository/controller additions. Existing Get-based structure is kept.

## 1. File map (target)

```
Frontend/krishimantra/lib/
├── data/
│   ├── models/
│   │   ├── farm_profile.dart                   NEW
│   │   ├── crop_entry.dart                     NEW
│   │   ├── seven_day_weather.dart              NEW
│   │   ├── user_model.dart                     EXTENDED (add farmProfileId)
│   │   └── ai_chat.dart                        EXTENDED (usage, summary)
│   ├── repositories/
│   │   ├── farm_profile_repository.dart        NEW
│   │   ├── weather_repository.dart             NEW (replaces direct OWM calls)
│   │   └── ai_chat_repository.dart             PATCHED (SSE support)
│   ├── services/
│   │   ├── weather_service.dart                REWORKED (calls our API)
│   │   ├── ai_stream_service.dart              NEW (SSE client)
│   │   └── location_service.dart               NEW (wrap geolocator, reverse geocode)
│   └── sources/
│       └── farm_profile_draft_local.dart       NEW (SharedPreferences draft)
├── presentation/
│   ├── screens/
│   │   ├── onboarding/
│   │   │   ├── onboarding_screen.dart          NEW (orchestrates steps)
│   │   │   ├── step_location.dart              NEW
│   │   │   ├── step_farm.dart                  NEW
│   │   │   ├── step_crops.dart                 NEW
│   │   │   └── step_review.dart                NEW
│   │   ├── farm_profile/
│   │   │   ├── farm_profile_screen.dart        NEW (edit, 3 tabs)
│   │   │   └── widgets/
│   │   │       ├── crop_card.dart              NEW
│   │   │       └── crop_picker_sheet.dart      NEW
│   │   ├── ai_chat/
│   │   │   └── ai_chat_screen.dart             PATCHED (banner + stream)
│   │   └── auth/
│   │       └── signup_screen.dart              PATCHED (navigate to onboarding)
│   ├── controllers/
│   │   ├── farm_profile_controller.dart        NEW
│   │   ├── onboarding_controller.dart          NEW
│   │   └── ai_chat_controller.dart             PATCHED (SSE; drop stubbed loc/wx)
│   └── widgets/
│       └── complete_profile_banner.dart        NEW
├── routes/app_routes.dart                      PATCHED
└── core/utils/
    └── derive_growth_stage.dart                NEW (client mirror of server logic)
```

## 2. Models

### `farm_profile.dart`
```dart
class FarmProfile {
  final String id;
  final String userId;
  final int? age;
  final String? gender;
  final String preferredLanguage;
  final LatLng? location;       // LatLng from google_maps_flutter or plain Point
  final Address? address;
  final double? totalArea;
  final String totalAreaUnit;   // acre|hectare|bigha|gunta
  final String? ownership;
  final List<String> soilTypes;
  final List<String> irrigationSources;
  final int experienceYears;
  final List<CropEntry> crops;
  final String onboardingStatus; // not_started|in_progress|completed
  final int profileVersion;

  factory FarmProfile.fromJson(Map<String, dynamic> json) { ... }
  Map<String, dynamic> toJson() { ... }
  FarmProfile copyWith({...}) { ... }
}

class Address {
  final String? village, taluka, district, state, country, pincode;
}

class CropEntry {
  final String id;              // server-assigned
  final String cropId;
  final String cropName;
  final String? variety;
  final double area;
  final String areaUnit;
  final DateTime sowingDate;
  final DateTime? expectedHarvestDate;
  final String growthStage;
  final String? plantingMethod;
  final String? irrigationMethod;
  final String? notes;

  int get daysSinceSowing =>
      DateTime.now().difference(sowingDate).inDays;
}
```

### `seven_day_weather.dart`
```dart
class SevenDayWeather {
  final DateTime asOf;
  final double lat, lon;
  final List<DayWeather> days;   // length 7

  DayWeather get today => days.firstWhere(
    (d) => _isSameDay(d.date, DateTime.now()),
    orElse: () => days[3],
  );
}

class DayWeather {
  final DateTime date;
  final double tempMin, tempMax;
  final double humidityMean, rainfallMm, windSpeedKmh;
  final String condition;
}
```

## 3. Repositories

### `farm_profile_repository.dart`
Thin layer over `ApiService`. Methods:
- `Future<FarmProfile> getMine()` → `GET /api/farm-profile/me`
- `Future<FarmProfile> upsert(FarmProfile p)` → `POST /api/farm-profile`
- `Future<FarmProfile> patch(Map<String, dynamic> delta)` → `PATCH /api/farm-profile`
- `Future<CropEntry> addCrop(CropEntry)` → `POST /crops`
- `Future<CropEntry> patchCrop(String id, Map delta)` → `PATCH /crops/:id`
- `Future<void> deleteCrop(String id)` → `DELETE /crops/:id`
- `Future<List<CropMaster>> searchCropMaster(String q)` → `GET /master/crops`

Caches last `getMine()` in-memory (Get service) so the AI screen can show crop chips without a network hit on every open.

### `weather_repository.dart`
- `Future<SevenDayWeather> get7Day(double lat, double lon)` → our new endpoint.
- Falls back to OpenWeather via the existing `weather_service.dart` if our API returns 5xx for one release, then the fallback is removed.

## 4. Controllers

### `onboarding_controller.dart`
Manages the 4-step flow. Reactive state:
- `Rx<int> step = 1.obs`
- `Rx<FarmProfile> draft = FarmProfile.empty().obs`
- `RxBool busy = false.obs`

Methods:
- `goNext()` → validates current step, calls repo, persists draft locally, advances.
- `goBack()`
- `skip()` → sets `onboardingStatus=in_progress`, navigates home.
- `restoreDraft()` → loads from `SharedPreferences` on init.

### `farm_profile_controller.dart`
Used by the post-onboarding edit screen. Same repo, atomic saves per tab.

### `ai_chat_controller.dart` patches
- **Remove** stub for location/weather in request body.
- **Add** SSE streaming:
  - On send, opens SSE via `AIStreamService` and emits tokens into the UI as they arrive.
  - On `{type: "done"}`, closes stream, updates rate-limit info.
  - Fall back to non-streaming POST if device is on a constrained network (≈`ConnectivityResult.mobile` with low signal — heuristic).
- **Add** banner logic: show `CompleteProfileBanner` if `FarmProfileController.profile.value?.onboardingStatus != "completed"`.

## 5. SSE client

`ai_stream_service.dart` uses `http` package with `request.send()` and reads the body stream line-by-line:

```dart
Stream<AIChatEvent> stream({required String chatId, required String message, required String language}) async* {
  final req = http.Request("POST", Uri.parse("$baseUrl/api/ai/chat"))
    ..headers["Authorization"] = "Bearer ${await AuthStore.token()}"
    ..headers["Accept"]        = "text/event-stream"
    ..headers["Content-Type"]  = "application/json"
    ..body = jsonEncode({
      "chatId": chatId, "message": message, "preferredLanguage": language,
    });

  final resp = await req.send();
  if (resp.statusCode != 200) {
    throw _parseError(resp);
  }
  final lines = resp.stream.transform(utf8.decoder).transform(const LineSplitter());
  await for (final line in lines) {
    if (!line.startsWith("data:")) continue;
    final payload = jsonDecode(line.substring(5).trim());
    yield AIChatEvent.fromJson(payload); // {type: "delta"|"done"|"error", ...}
  }
}
```

Events:
- `delta` → append text to the assistant bubble.
- `done` → finalize message, update `remainingMessages`.
- `error` → show toast, mark message failed (retry button).

## 6. Onboarding screens

### `step_location.dart`
- Tap "Use current location" → `LocationService.getPositionWithPermission()`.
- Or pin on a Google Map (requires maps API key already in project).
- Reverse-geocode via `geocoding` package → fills `village/taluka/district/state/pincode` (editable).
- Age (optional), gender (radio chips), language (pre-filled from LanguageService).
- "Next" enabled only when `location != null`.

### `step_farm.dart`
- Numeric field with unit toggle (acre/hectare/bigha/gunta).
- Ownership segmented control.
- Soil types — chip multi-select (icons).
- Irrigation sources — chip multi-select.
- Experience slider.

### `step_crops.dart`
- List of `CropCard` widgets, one per crop in draft.
- Floating "+ Add crop" → opens `crop_picker_sheet.dart` (searchable typeahead over `master/crops`, pulls crop image + default `growingPeriod`).
- Inside `CropCard`: area input, sowing date picker, derived growth stage (edit override), planting/irrigation method.
- Validation per card inline; top banner summarizes "2 crops added".
- "Next" requires ≥1 crop OR explicit "skip crops".

### `step_review.dart`
- Read-only summary with "Edit" chips linking back to step 1/2/3.
- "Confirm and continue" button fires `controller.finalize()`.

## 7. Edit Farm screen

`farm_profile_screen.dart` — 3 tabs: Location · Farm · Crops. Each tab is a Form with "Save" button that fires the matching PATCH. Uses the same widgets as onboarding but without the step progression.

Entry points:
- Profile screen → "My Farm" card tap.
- AI chat banner → tap opens edit-crops tab directly.
- Settings → "Farming info".

## 8. Routes

`app_routes.dart` additions:
```dart
static const ONBOARDING       = '/onboarding';
static const ONBOARDING_STEP  = '/onboarding/:step';  // for deep-linking a nudge
static const FARM_PROFILE     = '/farm-profile';
```

Signup success navigates to `/onboarding` if `profile.onboardingStatus != "completed"`, else `/home`.

## 9. `AI chat screen` changes

Minimal visual delta:
1. Above the input area, show `CompleteProfileBanner` if profile incomplete. Tapping → `/farm-profile`.
2. Streaming assistant bubbles with a thin blinking caret at the tail during `delta` events.
3. Small chip row showing crops in context for the current chat (from first backend response metadata). Helps farmer verify the AI "knows" what they grow.

Request body is now just:
```dart
{ "chatId": chatId, "message": message, "preferredLanguage": language }
```
No more `location` / `weather` stubs.

## 10. Localization

- Add strings in `home_localizations.dart` for all new screens (step titles, validation errors, button labels).
- Crop master names come pre-localized from backend (in `name`/`nameLocalized.<lang>` fields — phase 2 if not already present).

## 11. Offline / draft behavior

`farm_profile_draft_local.dart`:
- Single JSON blob in `SharedPreferences` under key `farm_profile_draft_v1`.
- Write on every "Next" in onboarding.
- Cleared on `onboardingStatus=completed` server response.
- On app start, if server says `in_progress` but local draft exists with more recent `updatedAt`, prompt user: "Resume where you left off?"

## 12. Weather in Home screen

Existing home weather widget switches to `WeatherRepository.get7Day()`. UI shows:
- Top card: today's current (from the `today` day in the 7-day object).
- Row of 7 mini-cards: tappable to see per-day details.
- "As of …" timestamp.
- Pull-to-refresh invalidates local in-memory cache (server's Redis TTL unaffected).

## 13. Testing

- Widget tests for each onboarding step validating "Next" enabled/disabled transitions.
- Controller tests for draft save/restore.
- Integration test (patrol or integration_test): fresh install → OTP → full onboarding → AI chat → verify banner disappears.
- Mock SSE server for `ai_stream_service.dart` tests.

## 14. Rollout (mobile side)

- Ship behind a client flag `NEW_AI_ENABLED` (remote-config).
- Day 1: 5% of users. Monitor crash rate + onboarding completion.
- Day 3: 25%. 
- Day 7: 100%.
- Old builds keep working because backend stays back-compat (see doc 03).
