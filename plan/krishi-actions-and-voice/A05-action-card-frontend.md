# A05 — Today's Action Card: Mobile Implementation

The mobile slice is small but UX-sensitive. It's the screen the farmer opens at 5 AM — every detail matters more than usual.

## 1. Module layout (Flutter)

```
Frontend/krishimantra/lib/
├── data/
│   ├── models/
│   │   ├── action_card.dart                  NEW
│   │   ├── action_item.dart                  NEW
│   │   └── activity_journal_entry.dart       NEW
│   ├── repositories/
│   │   ├── action_card_repository.dart       NEW
│   │   └── activity_journal_repository.dart  NEW
│   └── services/
│       └── push_notification_service.dart    EXTENDED — handle morning push tap
├── presentation/
│   ├── controllers/
│   │   ├── action_card_controller.dart       NEW
│   │   └── activity_journal_controller.dart  NEW
│   ├── widgets/
│   │   └── action_card/
│   │       ├── action_card_widget.dart       NEW — the home-screen card
│   │       ├── action_item_tile.dart         NEW — one row
│   │       ├── action_item_status_chip.dart  NEW — done/skip/snooze chips
│   │       ├── empty_action_card.dart        NEW — "complete onboarding" state
│   │       └── action_card_header.dart       NEW — date + refresh
│   └── screens/
│       └── activity_journal/
│           ├── journal_screen.dart           NEW
│           └── journal_log_sheet.dart        NEW — manual log bottom sheet
└── core/
    └── constants/
        └── api_constants.dart                EXTENDED — new endpoints
```

## 2. Models (Dart)

`action_item.dart` mirrors the server's `actionItemSchema` 1:1 — same field names where possible to keep the deserialization trivial.

```dart
class ActionItem {
  final String itemId;
  final String cropEntryId;
  final String cropName;
  final String? cropVariety;
  final String? templateId;
  final String source; // template | ai | weather_alert | manual
  final String verb;
  final String title;
  final String? detail;
  final String? chemical;
  final String? dose;
  final String? safetyNote;
  final String urgency; // low | normal | high | urgent
  final List<String> rationaleTags;
  final String status;  // pending | done | skipped | snoozed
  final DateTime? statusUpdatedAt;
  final DateTime? snoozeUntil;

  const ActionItem({...});
  factory ActionItem.fromJson(Map<String, dynamic> j) {...}
  ActionItem copyWith({...});
  bool get isPending => status == 'pending';
  bool get isUrgent => urgency == 'urgent' || urgency == 'high';
}
```

`action_card.dart` wraps the list:

```dart
class ActionCard {
  final String localDate;
  final String timezone;
  final List<ActionItem> items;
  final bool cached;
  final bool generatedOnDemand;
  // ... plus computed: pendingCount, doneCount, hasUrgent.
}
```

`activity_journal_entry.dart` mirrors `ActivityJournal`.

## 3. Repository

`action_card_repository.dart`:

```dart
class ActionCardRepository {
  final ApiService _api;
  ActionCardRepository(this._api);

  Future<ActionCard?> today({String? etag}) async {
    final res = await _api.get(
      ApiConstants.ACTION_CARD_TODAY,
      options: dio.Options(
        validateStatus: (s) => s != null && (s == 304 || (s >= 200 && s < 300)),
        headers: etag != null ? { 'If-None-Match': etag } : null,
      ),
      cacheDuration: const Duration(minutes: 30),
    );
    if (res.statusCode == 304) return null; // unchanged
    if (res.statusCode != 200) return null;
    final data = res.data['success'] == true ? res.data : null;
    if (data == null) return null;
    return ActionCard.fromJson(data);
  }

  Future<List<ActionCard>> history({int limit = 14}) async {...}

  Future<ActionItem> markDone(String cardId, String itemId, {String? notes}) async {...}
  Future<ActionItem> markSkipped(String cardId, String itemId, {String? reason}) async {...}
  Future<ActionItem> markSnoozed(String cardId, String itemId, int hours) async {...}
  Future<ActionCard> regenerate({String? reason}) async {...}
}
```

## 4. Controller — `ActionCardController`

```dart
class ActionCardController extends GetxController {
  final ActionCardRepository _repo;
  ActionCardController(this._repo);

  final card = Rxn<ActionCard>();
  final isLoading = false.obs;
  final isRefreshing = false.obs;
  final isMutating = <String>{}.obs;     // itemIds currently being mutated
  final errorMessage = ''.obs;

  String? _etag;

  // Pending = items shown above the fold; done/skipped collapse into "completed today"
  RxList<ActionItem> get pending =>
      (card.value?.items.where((i) => i.isPending).toList() ?? <ActionItem>[]).obs;

  RxList<ActionItem> get completed =>
      (card.value?.items.where((i) => !i.isPending).toList() ?? <ActionItem>[]).obs;

  Future<void> load({bool force = false}) async {
    isLoading.value = true;
    try {
      final fresh = await _repo.today(etag: force ? null : _etag);
      if (fresh != null) card.value = fresh;
    } catch (e) {
      errorMessage.value = _readable(e);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> markDone(ActionItem item, {String? notes}) async {
    if (card.value == null) return;
    isMutating.add(item.itemId);
    final cardId = card.value!.itemId; // server returns full card._id; stored on the card
    // Optimistic update
    _patchItem(item.copyWith(status: 'done', statusUpdatedAt: DateTime.now()));
    try {
      final updated = await _repo.markDone(cardId, item.itemId, notes: notes);
      _patchItem(updated);
    } catch (e) {
      // Roll back
      _patchItem(item.copyWith(status: 'pending'));
      Get.snackbar('Could not save', _readable(e),
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      isMutating.remove(item.itemId);
    }
  }

  // skip / snooze mirror this shape
  Future<void> refresh() async => load(force: true);
}
```

The optimistic-update pattern matters: tapping "Done" needs to feel instant even on slow 4G. Server confirmation is allowed up to 4 s before we roll back.

## 5. Widget — `ActionCardWidget`

Visual targets:
- Top of the home screen, above the existing weather widget.
- Collapsible if all done. If 0 pending → small "✓ All caught up" strip; tappable to expand history.
- Each item is a card-row with: crop avatar, title (largest), urgency tag, detail (smaller), 3 buttons.
- Buttons: **Done** (primary green), **Skip** (subtle outline), **Tell me more** (icon button → AI chat with context pre-seeded).

ASCII layout:

```
┌────────────────────────────────────────────────────────┐
│  Today's actions — 25 Apr (मराठी)              ↻       │
│                                                        │
│  ┌────────────────────────────────────────────────┐   │
│  │ 🌱 टोमॅटो                              ⚠ urgent │   │
│  │                                                │   │
│  │ टोमॅटोवर मॅन्कोझेब फवारणी                          │   │
│  │ 2.5 g/L मॅन्कोझेब. पाने दोन्ही बाजूंनी झाकून...      │   │
│  │ ⚠ हातमोजे + मास्क घाला.                          │   │
│  │                                                │   │
│  │ [✓ केले]   [⏭ नंतर]   [💬 अधिक]                  │   │
│  └────────────────────────────────────────────────┘   │
│                                                        │
│  ┌────────────────────────────────────────────────┐   │
│  │ 🌾 कांदा                                      │   │
│  │ कांद्यासाठी हलकी NPK फवारणी                    │   │
│  │ ...                                            │   │
│  │ [✓ केले]   [⏭ नंतर]   [💬 अधिक]                │   │
│  └────────────────────────────────────────────────┘   │
│                                                        │
│  ✓ 1 task completed today                              │
└────────────────────────────────────────────────────────┘
```

### Sketch (`action_card_widget.dart`)

```dart
class ActionCardWidget extends StatelessWidget {
  const ActionCardWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<ActionCardController>();
    return Obx(() {
      if (c.isLoading.value && c.card.value == null) {
        return const _SkeletonCard();
      }
      final card = c.card.value;
      if (card == null || card.items.isEmpty) {
        return const EmptyActionCard();
      }
      final pending = card.items.where((i) => i.isPending).toList();
      final done = card.items.where((i) => !i.isPending).toList();
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        elevation: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ActionCardHeader(localDate: card.localDate, onRefresh: c.refresh),
            if (pending.isEmpty)
              const _AllDoneStrip()
            else
              ...pending.map((item) => ActionItemTile(item: item)),
            if (done.isNotEmpty)
              _CompletedStrip(items: done),
          ],
        ),
      );
    });
  }
}
```

### `ActionItemTile`

Key concerns:
- Big title (16-18 sp), detail (14 sp), buttons (44 dp tap target — Material spec).
- Color-coded left border by urgency: red `urgent`, amber `high`, default `normal`.
- Urgency tag pill in the top-right.
- Safety note prefixed with ⚠ in muted red so it's visually distinct.

### "Tell me more" — AI chat handoff

Tapping it routes to `KRISHI_AI` with a pre-seeded message. We pre-fill the AI chat's text input and immediately send it:

```dart
void onTellMeMore(ActionItem item) {
  Get.toNamed(AppRoutes.KRISHI_AI, arguments: {
    'autoSendMessage': _composeAutoMessage(item, lang),
    'sourceItemId': item.itemId,
  });
}
```

`_composeAutoMessage` produces:
> "Tell me more about: 'टोमॅटोवर मॅन्कोझेब फवारणी'. Crop: tomato (Himsona, 47 days, fruiting). Why this dose, and what to watch for?"

The chat controller checks `Get.arguments['autoSendMessage']` on init and (if set) auto-sends after the screen mounts. The user gets an immediate AI response in the language they're already using.

## 6. Empty / error states

| State | UI |
|-------|---|
| No FarmProfile / onboarding incomplete | Card with planting illustration + "Tell us about your farm" CTA → routes to `FARM_ONBOARDING`. |
| Profile complete, no active crops | "Add a crop to get today's actions" → routes to `EDIT_FARM` crops tab. |
| Cron hasn't run yet (cold path) | Skeleton → controller calls `regenerate()` once, then renders. Banner shows "Generating today's plan…". |
| Server error | Card collapses to a small "Couldn't load today's actions. Tap to retry." — never blocks the rest of the home screen. |
| Offline + no cached card | Same as above + a wifi-off icon. |
| Offline + cached card | Render card but show a small grey "Last updated: <timestamp>" footer. |

## 7. Done / Skip / Snooze flow

### Done (no input required)
1. Tap "✓ Done".
2. Optimistic flip to a green "✓ केले" pill (immediate).
3. Server confirms in background.
4. On confirm: subtle haptic + the row collapses into the "completed" strip.
5. On failure: row reverts; snackbar "Couldn't save — retry?".

### Skip (with reason chip)
1. Tap "⏭ Skip".
2. Sheet slides up with three quick-pick chips: **Already done**, **Not needed**, **Will do later**.
3. Tap a chip → server call → row collapses.
4. The chosen reason is sent in the journal so the engine learns.

### Snooze
- Long-press "Skip" → snooze options: 2h, 4h, tomorrow.
- Server stores `snoozeUntil`; the item still shows in the card but greyed with a clock icon. Clears at the snooze time.

## 8. Activity journal screen

`journal_screen.dart` — accessed from a chip on the action card ("3 actions logged this week"), or from the Edit-Farm "History" tab.

Layout:
- Top: filter strip (All / This week / Tomato / Onion / Sprays / Irrigation).
- List: each row = one journal entry, grouped by date.
- Row: crop avatar, verb localized, `chemical/dose` if any, time-ago (`5 hrs ago`), source pill (card / manual / AI inferred).
- Long-press → "Edit notes" or "Delete entry".
- FAB: **+ Log activity** opens `JournalLogSheet`.

`JournalLogSheet` is a minimal form:
- Crop dropdown (filled to user's active crops).
- Verb chips (8 most common; "Other" expands a full list).
- Optional inputs: chemical, dose, notes (text, 200 chars), photo.
- Save → POST `/api/activity-journal/`, server publishes `activity.logged`.

## 9. Push notification handling

We extend the existing notification handler. New payload tag `action_card.<localDate>`:

```dart
void onPushTapped(Map<String, dynamic> data) {
  final tag = data['tag']?.toString() ?? '';
  if (tag.startsWith('action_card.')) {
    Get.offAllNamed(AppRoutes.MAIN); // ensure home is mounted
    // home screen auto-loads the card; no extra params needed
    return;
  }
  // ... existing handling
}
```

## 10. Caching + offline

- Every `today()` response is written to SharedPreferences under `action_card_cache:{userId}:{localDate}` with a 24h expiry.
- App launch reads from cache and renders instantly while a background refresh runs.
- Status mutations (done/skip/snooze) are queued in a small SQLite-backed outbox if the network call fails; the next network-available cycle replays.
- Outbox replay uses idempotency: server's status transition is a no-op if already in target state.

## 11. Animations & micro-interactions

- Item completion: a 250ms scale-and-fade-out, then the row pops into the "completed" strip. Avoid jarring list jumps — wrap with `AnimatedSize`.
- Pull-to-refresh on the whole home screen → triggers `controller.refresh()`.
- New-day rollover: at local midnight, the controller listens for date changes and clears the card so the morning's fresh load shows fully.

## 12. Accessibility (a11y) — critical for our user base

- Minimum tap target: 48 dp (Material) on every action button.
- Default font size respects system text scale (some farmers use 1.3× scale).
- All button labels readable by screen readers — no icon-only critical buttons.
- Color contrast ≥ 4.5:1 on text and ≥ 3:1 on graphical elements.
- "Tell me more" supports the existing TTS toggle (Build B) when that ships.

## 13. Routes

`app_routes.dart` additions:

```dart
static const String ACTIVITY_JOURNAL = '/activity-journal';
static const String JOURNAL_LOG = '/activity-journal/log';
```

GetPage entries register the new screens. The action card itself doesn't need a route — it's a widget on the home screen.

## 14. Dependency injection

`dependency_injection.dart`:
```dart
Get.lazyPut(() => ActionCardRepository(Get.find<ApiService>()), fenix: true);
Get.lazyPut(() => ActivityJournalRepository(Get.find<ApiService>()), fenix: true);

Get.lazyPut(() => ActionCardController(Get.find<ActionCardRepository>()), fenix: true);
Get.lazyPut(() => ActivityJournalController(Get.find<ActivityJournalRepository>()), fenix: true);
```

Both controllers are instantiated lazily; the home screen `find()`s them on first build, which triggers the initial `load()`.

## 15. Testing

- **Widget tests** for `ActionItemTile`: pending/done/skipped/snoozed states, urgency border colors, button enable/disable.
- **Controller tests**: optimistic update + rollback on failure; refresh debounce.
- **Snapshot tests** for the empty state in en/hi/mr.
- **Integration test (golden path)**: open home → see card → tap done → row moves to completed.
- **Localization sweep**: assert no English fallback strings in mr/hi snapshots.

## 16. Performance

- Widget tree depth target: ≤ 8 from `Scaffold` → `ActionItemTile`. Avoid re-rendering siblings on a single status change.
- Use `keys` on items (`ValueKey(item.itemId)`) so AnimatedList preserves identity.
- Card render cost ≤ 6 ms on a Snapdragon 460 (lowest device we test on).

## 17. Telemetry the mobile side emits

Reuse the existing `engagement_service`:

```
ai.action_card.viewed              { items, pending, lang }
ai.action_card.item.tap.done       { verb, urgency, source }
ai.action_card.item.tap.skip       { verb, reason }
ai.action_card.item.tap.snooze     { verb, hours }
ai.action_card.item.tap.tellmemore { verb, source }
ai.action_card.refresh             { reason }
ai.action_card.empty.shown         { reason }
```

The funnel "viewed → first tap" is the key product KPI; `done`/`skip` ratio per verb is the content-quality dial.
