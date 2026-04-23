# 03 — Frontend Deep Dive

> Flutter farmer app, two Next.js admin panels, and the Vite landing page.

Table of contents:
- [3.1 Flutter app — krishimantra](#31-flutter-app--krishimantra)
- [3.2 admin-panel (Next.js 14)](#32-admin-panel-nextjs-14)
- [3.3 marketplace-admin (Next.js 15)](#33-marketplace-admin-nextjs-15)
- [3.4 landing-page (Vite static)](#34-landing-page-vite-static)
- [3.5 Cross-client concerns](#35-cross-client-concerns)

---

## 3.1 Flutter app — krishimantra

**Folder:** [Frontend/krishimantra/](../Frontend/krishimantra/)

Primary user surface. Dart SDK ≥3.6.1, Flutter, `get` for state + DI + routing, Dio for HTTP, Hive-backed cache, Socket.io-client for chat, TFLite + Gemini Vision for disease detection.

### 3.1.1 Architecture & DI

Clean-ish layering:
```
lib/
  core/               app-wide (config, constants, theme, utils, localization)
  data/               models, repositories, services (HTTP + side-effect wrappers)
  presentation/       screens, controllers (GetX), widgets, mixins
  routes/             app_routes.dart (36 named routes)
  main.dart
  dependency_injection.dart
```

DI is explicit through GetX's `Get.put` / `Get.lazyPut` in `dependency_injection.dart` — no runtime reflection. Services (Api, Socket, Location, Weather, Language, Engagement, DeviceRegistration) are singletons; controllers are put/lazyPut per screen.

### 3.1.2 State management

GetX reactive primitives (`Rx<T>`, `RxList`, `.obs`). Controllers expose streams; UI uses `Obx` / `GetBuilder`. Token refresh is synchronized by a `Completer<bool>`-based `TokenRefreshLock` so that only one refresh fires under concurrent 401s; other requests await the same completer. Good pattern.

### 3.1.3 HTTP layer

[lib/data/services/api_service.dart](../Frontend/krishimantra/lib/data/services/api_service.dart) wires Dio with five interceptors: logging (debug only), auth (Bearer header), cache (`dio_cache_interceptor_hive_store`), retry (`dio_smart_retry`, 3 attempts with exponential backoff), and a circuit breaker for repeat failures. Base URL resolves from `AppConfig` per environment.

Problem: `AppConfig._devHost = '192.168.1.46'` is a laptop IP hardcoded into the app. Any dev machine outside that subnet has to edit source. Move to `flutter_dotenv` with a checked-in `.env.example`.

### 3.1.4 Features & modules (≈30 screens, 21 controllers)

| Area | Screens | Controller | Notes |
|---|---|---|---|
| Auth | `LoginScreen`, `phone_number_screen`, `otp_verification_screen`, `LanguageSelectionPage` | `AuthController` | Phone OTP primary; email/password secondary. Tokens in `flutter_secure_storage`. |
| Shell | `splash_screen`, `MainScreen` (5-tab) | — | Bottom-nav: Home, Feed, Marketplace, Chat, Profile |
| Home | `home_screen` (~500 LOC) | — | Services grid, testimonials carousel, ads, hot products, schemes |
| Feed | `feed_screen`, `create_post_screen` | `FeedController` | Trending + recommended + interests |
| Reels | `reel_screen` | `ReelController` | Uses `video_player` for HLS |
| Chat | `ChatListScreen`, chat detail | `MessageController` | Socket.io client, typing/read indicators |
| AI chat | `ai_chat_screen` | `AIChatController` | Hits `/api/ai/*` (message-svc), provider selection |
| Weather | `weather_screen` | — | OpenWeather via `WeatherService` |
| Mandi (new) | `mandi_price_screen`, `mandi_product_detail_screen` | `MandiController` | MSP comparison from `msp_data.dart`, pagination 20/page |
| Disease detection | `disease_detection_screen` | `DiseaseDetectionController` | TFLite (38 classes) → Gemini fallback (currently disabled — empty key) |
| Farm measurement | `farm_measurement_screen` | `FarmMeasurementController` | OSM via `flutter_map` + `maps_toolkit` polygon area, hectare/sqm/bigha/guntha |
| IoT | `device_registration_screen`, `pump_control_screen` | — | Uses `DeviceRegistrationService` |
| Crop calendar | `cropcalendar/Crops.dart` | `CropController` | Region → Crop → Activity |
| Companies/products | `company/allcompanyscreen.dart`, `product_list_screen` | `CompanyController`, `ProductController` | |
| Marketplace | `marketplace_screen`, `marketplace_product_detail_screen`, `add_product_screen` | `MarketplaceController` | Farmer-to-farmer listings |
| Schemes | `gov_schemes_screen` | `SchemeController` | Central/state schemes |
| Videos | `video_list_screen` | `VideoTutorialController` | YouTube via `youtube_player_flutter` |
| Subscription | `subscription_plans_screen`, `payment_history_screen` | `SubscriptionController` | Stripe via `flutter_stripe` |
| Profile/settings | `ProfileScreen`, `settings_screen` | — | Edit profile is a TODO |
| Notifications | `notification_screen` | `NotificationController` | In-app feed; no FCM yet |

### 3.1.5 Localization

[lib/core/utils/home_localizations.dart](../Frontend/krishimantra/lib/core/utils/home_localizations.dart) — ≈630 lines, 100+ keys, 6 languages (en/hi/mr/gu/bn/ta). Runtime switching via `LanguageService` + `TranslationManager` broadcasting `LanguageChangedEvent`. Dynamic API strings go through `LanguageHelper` which batches calls to Google Translator.

Pattern in new screens (see [LANGUAGE_IMPLEMENTATION_GUIDE.md](../Frontend/krishimantra/LANGUAGE_IMPLEMENTATION_GUIDE.md)):
```dart
import 'package:krishimantra/core/utils/home_localizations.dart';

class MyScreen extends StatelessWidget with TranslationMixin {
  @override
  Widget build(BuildContext context) {
    return Text(_t('mandi_title'));
  }
}
```

### 3.1.6 Disease detection pipeline

[lib/data/services/disease_detection_service.dart](../Frontend/krishimantra/lib/data/services/disease_detection_service.dart)

1. Decode image → resize 224×224 → normalize → reshape to `(1,224,224,3)`.
2. Run TFLite interpreter on `assets/ml/plant_disease_model.tflite` with `assets/ml/labels.txt`.
3. If top confidence ≥ 80% → return local result.
4. Else if `_geminiApiKey != ''` → call `gemini-2.0-flash` multimodal with the image; parse structured `CROP / DISEASE / CONFIDENCE / DESCRIPTION / TREATMENT / PREVENTION` response.
5. Else → return unknown.

**Both tiers are currently disabled in-repo**: the TFLite model file is not committed (it's in `.gitignore`-style absence) and the Gemini key is literal empty string. Feature is effectively non-functional until a build step wires both.

### 3.1.7 Mandi prices (new)

- [lib/data/services/mandi_service.dart](../Frontend/krishimantra/lib/data/services/mandi_service.dart) — `data.gov.in` client with mock fallback.
- [lib/data/msp_data.dart](../Frontend/krishimantra/lib/data/msp_data.dart) — 26 commodities (Kharif + Rabi) hardcoded for 2025-26 season.
- [lib/presentation/controllers/mandi_controller.dart](../Frontend/krishimantra/lib/presentation/controllers/mandi_controller.dart) — filters by state/district/crop, pagination of 20, date picker.

Hardcoded MSP data means the app will quietly be wrong when MSPs update. Serve from main-service.

### 3.1.8 Notable code-quality issues

1. **Hardcoded dev IP** in `AppConfig` — blocks any dev not on that LAN.
2. **`print` calls with partial tokens** in `auth_repository.dart` — sensitive data in release logs unless tree-shaken.
3. **Empty `_geminiApiKey`** committed — stub state ships.
4. **Untyped `Map<String, dynamic>`** pattern throughout repositories (75+ occurrences estimated) — runtime-only type safety. Recommend `json_serializable` models for every response.
5. **God widget** — `home_screen.dart` ~500 LOC with API calls, layout, carousels, and business logic mixed.
6. **Business logic in `build`** in several feature screens (e.g. disease_detection, weather) — move to controllers and use `Obx`/`FutureBuilder` only for display.
7. **Missing `onClose()`** overrides in several controllers (e.g. `ConnectivityController`) → `StreamSubscription` leaks across logout/login cycles.
8. **`ListView.builder` without `physics` tuning** — janky scroll on low-end devices.
9. **`NSAllowsArbitraryLoads = true`** in `ios/Runner/Info.plist` — allows HTTP in release.
10. **Single `test/widget_test.dart` placeholder** — no real test coverage.

### 3.1.9 Offline & connectivity

`ConnectivityController` tracks state. `dio_cache_interceptor_hive_store` serves stale cache when offline (5m/1h/1d tiers). There is no outgoing write queue — posts made offline fail with a snackbar rather than queueing. Add an outbox for likes/comments/feed creation.

### 3.1.10 Permissions

- Android: location (fine/coarse), storage (legacy + 33+ media), camera, network, wake-lock, foreground-service, receive-boot-completed.
- iOS: location (when-in-use + always), photo library, camera — and the unsafe `NSAllowsArbitraryLoads`.
- `permission_handler` + `app_settings` deep-links to system settings on persistent denial.

---

## 3.2 admin-panel (Next.js 14)

**Folder:** [Frontend/admin-panel/](../Frontend/admin-panel/)

Super-admin. Next.js 14, TypeScript 5, Tailwind, shadcn/ui, Zustand with persistence, Axios, Recharts.

### 3.2.1 Routes (app router, 18 pages)

`/auth/login`, `/dashboard`, `/users`, `/companies`, `/products`, `/ads`, `/feeds`, `/reels`, `/videos`, `/news`, `/notifications`, `/subscriptions`, `/crop-calendar`, `/device-registrations`, `/schemes`, `/services`, `/analytics`, `/settings`. All **client components** (`"use client"`), all data fetched in `useEffect` — no SSR, no server actions, no React Query.

### 3.2.2 API layer

[src/lib/api.ts](../Frontend/admin-panel/src/lib/api.ts) instantiates **five** Axios clients for different gateway prefixes (`mainApi`, `feedApi`, `reelApi`, `notificationApi`, `engagementApi`). One shared auth interceptor (`Authorization: Bearer <token>` from localStorage) and a 401 handler that clears token and redirects to `/auth/login`.

18 API object groups (`authAPI`, `userAPI`, `newsAPI`, `companyAPI`, `productAPI`, `adsAPI` with 6 ad types, `analyticsAPI`, `engagementAPI`, `schemeAPI`, `serviceAPI`, `feedsAPI`, `reelsAPI`, `videosAPI`, `marketplaceAPI`, `notificationAPI`, `cropCalendarAPI`, `subscriptionAPI`, `iotAddonAPI`).

### 3.2.3 Auth

Zustand store ([src/store/auth.store.ts](../Frontend/admin-panel/src/store/auth.store.ts)) with `persist` middleware → localStorage key `auth-storage`, plus a raw `admin_token`. Protected pages check token in `MainLayout` and redirect. **No RBAC** — any admin sees everything.

### 3.2.4 Issues

1. **`any` types** throughout API DTOs — untype-safe payloads, bad IntelliSense.
2. **No Zod schemas** on forms → server is the only validator.
3. **No error boundaries** — a render exception blanks the page.
4. **Duplicate CRUD patterns** per entity (users/companies/products all reinvent the same Table + Dialog). Extract a `DataTable` + `CrudDrawer`.
5. **No loading/disabled state** on dialog submits — double-submit risk.
6. **Token in localStorage** → XSS steals auth. Move to HTTP-only cookie with CSRF.
7. **Inconsistent response shapes** — `{success, data}` in some endpoints vs `{count, data, total}` in others. Standardize.
8. 174 "test files" counted by the investigator appear to be placeholders (needs verification). Assume no meaningful coverage.

---

## 3.3 marketplace-admin (Next.js 15)

**Folder:** [Frontend/marketplace-admin/](../Frontend/marketplace-admin/)

Narrower admin for marketplace ops — products, companies, trending. 6 pages: `/login`, `/dashboard`, `/products`, `/marketplace`, `/companies`, `/trending`, `/settings`.

Differences vs admin-panel:
- **Newer Next.js (15)** and **Zustand 5**.
- **Sonner** toasts instead of Radix toast.
- **next-themes** dark-mode support.
- **Single Axios client** (only `/main` prefix).
- **Hydration-safe `mounted` check** in `MainLayout`.

Same structural issues: localStorage tokens, no RBAC, no Zod, no error boundaries, no React Query. Same `any` leakage but smaller surface.

---

## 3.4 landing-page (Vite static)

**Folder:** [Frontend/landing-page/](../Frontend/landing-page/)

Single `index.html` (~37 KB) + `style.css` (~38 KB) + `main.js` (~13 KB). No framework. Vite 6 just for bundling / HMR.

- Hero → 4-stat bar → 9 feature cards → 3-step flow → IoT showcase → testimonials (placeholder) → subscription/pricing → FAQ → CTA → footer.
- Navbar scroll listener + IntersectionObserver for fade-in + JS counter animation for stats.
- SEO: title, meta description, OG tags, Twitter card, Schema.org `SoftwareApplication`. Missing: `sitemap.xml`, `robots.txt`, real images (`assets/images/og-image.png` referenced but absent).
- No email capture, no app store links (hardcoded `/api` href), no analytics, no `prefers-reduced-motion` handling, no i18n despite the audience.

Verdict: pre-MVP marketing placeholder. Either productize (CMS-backed, analytics, real imagery, Hindi/regional) or replace with Vercel-hosted Next.js page sharing the admin's design system.

---

## 3.5 Cross-client concerns

### 3.5.1 Token model
Three different places: Flutter `flutter_secure_storage` (keychain — good), admin-panel and marketplace-admin both in `localStorage` (bad — XSS-exposed). Unify on HTTP-only cookies issued by main-service, with a short-lived access token and refresh-token rotation. Flutter can keep secure storage but should reuse the same lifetime semantics.

### 3.5.2 API contract
No shared OpenAPI / TypeScript types. Both admin panels maintain parallel hand-rolled `api.ts`. Flutter models are hand-rolled Dart classes. This is fine at 3 clients; it will calcify. Consider generating types from a single OpenAPI spec or using tRPC for the admin surfaces.

### 3.5.3 Design system
admin-panel (Radix shadcn) and marketplace-admin (same stack but older Sonner vs newer) already diverge. Factor out a shared `@krishi/ui` package with the shadcn primitives, layout shell, data table, drawer form, and theme tokens.

### 3.5.4 Feature flags
No flag system on any surface. Releases are all-or-nothing. Add Remote Config (Firebase) for Flutter, environment-gated for admin.

### 3.5.5 Accessibility
All three web surfaces are keyboard-navigable only by luck. No ARIA labeling audit, no focus-trap on dialogs, no skip-to-content, no reduced-motion. Flutter defaults are better (Material semantics) but custom widgets like the service grid should declare `Semantics` labels.

### 3.5.6 Testing
- Flutter: 1 placeholder test. Target 60% on models, repositories, and controllers. Use `mocktail` for repositories; golden tests for key widgets (disease card, mandi row, home service grid).
- Admin panels: 0 real tests. Vitest + React Testing Library for components; Playwright for login + CRUD happy-path smoke.
- Landing: add `@lhci/cli` Lighthouse-CI for performance/SEO regressions.
