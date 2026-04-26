# A04 — Today's Action Card: Backend Implementation

This doc covers the new modules in **main-service** and **message-svc**, the cron architecture, the API surface, and the wiring to the existing notification + push infrastructure.

## 1. Module layout

```
Backend-JS/main-service/src/
├── model/
│   ├── CropTaskTemplate.js              NEW — see A02 §1
│   ├── DailyActionCard.js               NEW — see A02 §2
│   └── ActivityJournal.js               NEW — see A02 §3
├── services/
│   ├── action-card/
│   │   ├── recommendation.engine.js     NEW — pure rule pass (A03 §3–7)
│   │   ├── ai-fallback.service.js       NEW — AI fallback (A03 §8)
│   │   ├── localizer.js                 NEW — template→localized text (A03 §9, A06)
│   │   ├── card.builder.js              NEW — orchestrates 1→2→3→4→5 in A03 §1
│   │   └── card.cron.js                 NEW — daily sweep, see §3
│   ├── activity-journal.service.js      NEW — writes ActivityJournal + pub/sub
│   └── notify.service.js                EXTENDED — push card to FCM/APNs
├── controller/
│   ├── ActionCardController.js          NEW — see §4
│   └── ActivityJournalController.js     NEW — see §5
├── routes/
│   ├── actionCardRoutes.js              NEW
│   └── activityJournalRoutes.js         NEW
└── scripts/migrations/
    ├── m-A1-create-collections.js       NEW
    ├── m-A2-seed-templates.js           NEW
    └── m-A3-backfill-notify-prefs.js    NEW
```

Reads from message-svc:
- `services/farm-profile.client.js` already exists; we extend it to also expose `getActiveCrops(userId)`.
- A new `weather-snapshot.client.js` reads the snapshot (or hits message-svc HTTP if cross-service).

> The action-card services live in **main-service** because that's where `FarmProfile` and `Crop` master live. The AI fallback inside the builder calls message-svc's `/api/ai/internal/chat` (see §7) so the provider registry is the single source of truth for AI access.

## 2. The card builder (`card.builder.js`)

Single function the cron and on-demand path both call:

```js
async function buildCardForUser(userId, { localDate, force = false } = {}) {
  const profile = await FarmProfile.findOne({ userId });
  if (!profile) return { skipped: "no_profile" };
  if (profile.onboardingStatus !== "completed") return { skipped: "onboarding_incomplete" };
  if (!profile.crops?.some(c => c.isActive)) return { skipped: "no_active_crops" };

  const dateKey = localDate || todayLocalDate(profile.timezone);
  const existing = await DailyActionCard.findOne({ userId, localDate: dateKey });
  if (existing && !force) return { skipped: "already_generated", cardId: existing._id };

  const [snapshot, journal] = await Promise.all([
    WeatherSnapshotClient.get(profile.location.coordinates),
    ActivityJournal.find({
      userId,
      occurredAt: { $gte: daysAgo(30) },
    }).lean(),
  ]);

  const ruleItems = await runRuleEngine(profile, snapshot, journal); // A03 §4–7
  const finalItems = await fillGapsWithAI(profile, snapshot, journal, ruleItems); // A03 §8

  const localized = finalItems.map(it => localize(it, profile.preferredLanguage));

  const card = await DailyActionCard.findOneAndUpdate(
    { userId, localDate: dateKey },
    {
      userId, localDate: dateKey,
      timezone: profile.timezone || "Asia/Kolkata",
      items: localized,
      generatedAt: new Date(),
      weatherSnapshotBucket: snapshot?.bucket,
      farmProfileVersion: profile.profileVersion,
      generator: existing ? "on_demand" : "cron",
      aiUsageUsd: aiCostAccumulator,
      expiresAt: addDays(new Date(), 30),
    },
    { upsert: true, new: true }
  );

  await redis.setex(`action-card:${userId}:${dateKey}`, 24 * 3600, JSON.stringify(card.items));
  return { cardId: card._id, items: card.items, generated: !existing };
}
```

Determinism: with the same inputs the builder produces the same `itemId`s (see A02 §2 — itemId is `sha1(template-or-ai|cropEntryId|dayBucket)`). Replays at any time are safe.

## 3. Cron architecture (`card.cron.js`)

Goals:
- Each user's card ready by `notifyPrefs.morningCardLocalTime − 30 min`.
- Total wall-clock < 10 min for 100k users.
- No thundering herd on the AI provider when many cards need fallback.

### Schedule

A node-cron entry inside main-service runs every 30 minutes:

```js
cron.schedule("0,30 * * * *", runWindow);
```

Each invocation processes the bucket of users whose `morningCardLocalTime` falls in the next ~60 min window for their TZ. So at 03:00 UTC we process IST 08:30+09:00 farmers, etc.

### Worker pool

Inside one process:

```
const POOL_SIZE = parseInt(process.env.ACTION_CARD_POOL_SIZE || "8");
const queue = pLimit(POOL_SIZE);
const work = users.map(u => queue(() => buildCardForUser(u._id)));
await Promise.allSettled(work);
```

Pool size 8 keeps the AI provider's RPM well within limits even if every user needed AI fallback (which shouldn't happen — most don't).

### Distributed coordination

Multiple message-svc/main-service replicas might run the cron. We use a Redis SETNX lock so only one replica runs the window:

```js
const lockKey = `action-card-cron-lock:${windowId}`;
const acquired = await redis.set(lockKey, hostname, "NX", "EX", 600); // 10 min
if (!acquired) return;
try { await runWindow(); } finally { await redis.del(lockKey); }
```

`windowId` = `${utcDate}-${slot}` (slot = `:00` or `:30`). Idempotent: if the lock holder dies the next slot retries; we skip users who already have today's card.

### Progress + observability

While running, we write `action-card-progress:{batchId} = "{n}/{total}"` to Redis so the admin panel (T46e-style) can show live progress. Every completed user emits a structured log:

```json
{
  "event": "action_card.built",
  "userId": "hashed",
  "items": 2,
  "ai_fallbacks": 0,
  "cost_usd": 0,
  "duration_ms": 142
}
```

### Failure handling

- Per-user errors are caught; the user is skipped and re-queued in the next 30-min slot (idempotency keeps it safe).
- Hard cron failures (DB down) page on Prometheus alert `action_card_cron_failure_total > 5/min`.

## 4. `ActionCardController.js`

Endpoints behind `auth` middleware (mounted at `/api/action-card`):

```
GET    /today              -> today's card (cache-first)
GET    /history?limit=14   -> last N days of cards
POST   /:cardId/items/:itemId/done       -> mark done
POST   /:cardId/items/:itemId/skip       -> mark skipped + reason
POST   /:cardId/items/:itemId/snooze     -> snooze (body: { hours })
POST   /regenerate                        -> on-demand regen (rate-limited)
GET    /audit?userId&date=YYYY-MM-DD     -> admin only (A03 §12)
```

### `GET /today`

```js
exports.today = asyncHandler(async (req, res) => {
  const userId = req.user.id;
  const profile = await FarmProfile.findOne({ userId }).select("timezone preferredLanguage onboardingStatus");
  const dateKey = todayLocalDate(profile?.timezone);

  // Fast path: Redis
  try {
    const cached = await redis.get(`action-card:${userId}:${dateKey}`);
    if (cached) {
      return res.json({
        success: true,
        localDate: dateKey,
        items: JSON.parse(cached),
        cached: true,
      });
    }
  } catch (_) {}

  // DB path
  const card = await DailyActionCard.findOne({ userId, localDate: dateKey });
  if (card) {
    return res.json({
      success: true,
      localDate: dateKey,
      items: card.items,
      cached: false,
    });
  }

  // Cold path: build on demand (rare — cron should cover most cases)
  const built = await CardBuilder.buildCardForUser(userId, { localDate: dateKey });
  return res.json({
    success: true,
    localDate: dateKey,
    items: built.items || [],
    cached: false,
    generatedOnDemand: true,
  });
});
```

The mobile app uses `If-None-Match` (`ETag` from `card._id + statusUpdatedAt-max`) for conditional fetch on subsequent opens — server returns 304 with no body when nothing has changed.

### `POST /:cardId/items/:itemId/done`

```js
exports.markDone = asyncHandler(async (req, res) => {
  const userId = req.user.id;
  const { cardId, itemId } = req.params;
  const { notes } = req.body || {};

  const card = await DailyActionCard.findOne({ _id: cardId, userId });
  if (!card) return res.status(404).json({ success: false, message: "Card not found" });
  const item = card.items.find(i => i.itemId === itemId);
  if (!item) return res.status(404).json({ success: false, message: "Item not found" });
  if (item.status !== "pending") {
    return res.status(409).json({ success: false, message: `Already ${item.status}` });
  }

  item.status = "done";
  item.statusUpdatedAt = new Date();
  await card.save();
  await redis.del(`action-card:${userId}:${card.localDate}`);

  // Mirror to journal
  await ActivityJournalService.write({
    userId,
    cropEntryId: item.cropEntryId,
    cropName: item.cropName,
    verb: item.verb,
    chemical: item.chemical,
    dose: item.dose,
    notes,
    source: "card_done",
    cardItemId: item.itemId,
    cardLocalDate: card.localDate,
    timezone: card.timezone,
  });

  return res.json({ success: true, item });
});
```

`skip` and `snooze` mirror this shape; only `skip` writes a `card_skipped` journal row (so the engine can learn "user dislikes this verb").

### Rate limits

- `GET /today` — 60/min/user (mobile retries on flaky 4G).
- `POST /regenerate` — 3/hour/user. Uses `force: true`.
- `done`/`skip`/`snooze` — 60/min/user. Audit log on every call.

## 5. `ActivityJournalController.js`

Endpoints at `/api/activity-journal`:

```
GET   /                    -> paginated journal (default last 50)
POST  /                    -> manual log entry  (body: { cropEntryId, verb, chemical?, dose?, notes?, imageUrl? })
GET   /by-crop/:cropEntryId
DELETE /:id                -> soft delete (sets isDeleted; UI hides)
```

`POST /` is the explicit-log path — used by EditFarm "Log activity" and by future quick-log buttons on the home screen. It writes via `ActivityJournalService.write` (same internal as card-done) so all entries flow through one validator + pub/sub publisher.

## 6. On-demand regeneration

When does a user trigger one?
- They edit FarmProfile (add a crop, change variety).
- They manually log a journal entry (might invalidate "you should spray today").
- They tap the "Refresh" button on the action card.

Implementation:

```js
async function regenerateOnDemand(userId, reason) {
  if (await isRateLimited(userId, "card_regen", 3, 3600)) {
    throw new ApiError(429, "Too many regenerations; try again in an hour");
  }
  const result = await CardBuilder.buildCardForUser(userId, { force: true });
  await redis.publish("action-card.regenerated", JSON.stringify({ userId, reason }));
  return result;
}
```

Triggered automatically (no user tap) on `farm-profile.updated` and `activity.logged` pub/sub events — handled by a small subscriber. Latency target: regenerated within 60 s of the trigger.

## 7. AI access

The fallback path needs the active provider. Two ways to wire it:

**Option A (chosen):** main-service calls a new internal endpoint on message-svc:
```
POST /api/ai/internal/chat   (server-to-server, JWT-shared-secret)
body: { messages, model?, maxTokens, temperature, userId, purpose: "action_card_fallback" }
```
This keeps the provider registry in one place (message-svc) and lets the cost ledger tag spend by `purpose`.

**Option B (rejected):** main-service imports message-svc's provider module. Tight coupling, breaks service boundaries.

The internal endpoint:
- Reuses `factory.active()` and the registry kill-switch.
- Validates the shared secret header `X-Internal-Auth: <hmac>`.
- Logs spend with `purpose: "action_card_fallback"` so we can break out cost in the admin usage card.

## 8. Push notifications

Reuse the existing `notification-service` + RabbitMQ + FCM pipeline. After the cron writes a card:

```js
async function maybeNotify(userId, card) {
  const prefs = await getNotifyPrefs(userId);
  if (!prefs.morningCardEnabled) return;
  if (prefs.preferredChannel === "none") return;

  const localTime = toLocalTime(prefs.morningCardLocalTime, prefs.timezone);
  const fireAt = nextOccurrence(localTime); // next ISO time at that local clock

  await notificationQueue.publish("scheduled-push", {
    userId,
    fireAt,
    payload: {
      title: localize("action_card.push_title", lang), // "Today on your farm"
      body: localize("action_card.push_body", lang, {
        n: card.items.filter(i => i.status === "pending").length,
        topItem: card.items[0]?.title,
      }),
      deeplink: `krishimantra://home?focus=action_card`,
      tag: `action_card.${card.localDate}`,
    },
  });
}
```

The queue worker fires at `fireAt`; the `tag` field collapses re-pushes (e.g. if the cron regenerates) so the user sees a single morning notification.

Weather-emergency push (separate channel) skips the schedule and fires immediately when the weather snapshot drops a hail/flood code in the next 24 h.

## 9. Caching

| Layer | Key | TTL | Invalidator |
|-------|-----|-----|-------------|
| Redis card | `action-card:{userId}:{date}` | 24 h | controller writes; pub/sub on regen |
| Redis templates | `tpl-cache:{cropId}:{stage}` | 6 h | TTL only |
| Redis journal slice | `journal-cache:{userId}:30d` | 1 h | invalidated on `activity.logged` |
| Redis weather | existing `weather:{bucket}` | 15 min | (handled by weather.service) |

The 1 h `journal-cache` TTL means the engine picks up new journal entries within an hour even without an explicit invalidation; the pub/sub invalidation makes that immediate.

## 10. Observability

New Prometheus metrics:

```
krishi_action_card_built_total{generator}                 counter
krishi_action_card_build_duration_seconds                 histogram
krishi_action_card_items_total{source}                    counter (template / ai / weather_alert)
krishi_action_card_ai_fallback_total                      counter
krishi_action_card_no_template_total{cropName}            counter (gap-finder for content team)
krishi_action_card_done_total{verb}                       counter
krishi_action_card_skip_total{verb}                       counter
krishi_action_card_skip_ratio_5m{verb}                    gauge   (alert if a verb is being skipped > 70%)
krishi_action_card_cron_lag_seconds                       gauge   (now - last successful run)
krishi_action_card_cost_usd_total{purpose}                counter
```

Grafana dashboard panels:
1. Cards built per 30-min window (with target line at expected user count).
2. `done` vs `skip` ratio per verb — flags content quality issues.
3. Per-crop "no template found" — drives the content roadmap.
4. AI fallback rate — should be < 5% in steady state.
5. Cost-per-card by source (template = $0, AI = ~$0.0002).

## 11. Environment variables

Added:
```
ACTION_CARD_POOL_SIZE=8
ACTION_CARD_AI_FALLBACK_DAILY_PER_USER=2
ACTION_CARD_DEFAULT_TIMEZONE=Asia/Kolkata
ACTION_CARD_INTERNAL_SHARED_SECRET=<hmac-key>
```

## 12. Security

- All endpoints under `auth`. `audit` and `regenerate-other-user` admin-only.
- Internal AI endpoint uses HMAC + IP allowlist.
- Activity journal writes are authenticated; client cannot forge `cardItemId`.
- Photos uploaded via existing presigned-URL service (already validates bucket + ContentType).
- We never log a user's exact lat/lon — only the bucket key.

## 13. Rollout

Phase 1 (week 1, 2 days): deploy the model migrations + seed top-10-crop templates. No UI yet. Cron in dry-run mode (logs cards but doesn't write).

Phase 2 (week 1, 1 day): flip cron to write real cards. Mobile UI behind `FF_ACTION_CARD_ENABLED=false`.

Phase 3 (week 2, 1 day): enable mobile UI for internal beta (5 users). Iterate copy/UX.

Phase 4 (week 2, 1 day): 5% production cohort. Monitor `done`/`skip` ratios.

Phase 5 (week 3, 1 day): 50% rollout. Open the audit endpoint to support team.

Phase 6 (week 3, 0.5 day): 100% + push notifications enabled.

Kill-switch: `redis SET action-card:killswitch 1` makes the cron exit early and the API return an empty card with a `disabled` flag. Mobile hides the card.

## 14. Testing

- Unit: rule engine deterministic on a fixed input (50 fixtures).
- Snapshot: serialized card fixtures across en/hi/mr.
- Integration: compose stack with a seeded user, weather, journal — assert items match.
- Load: 100k user batch in under 10 min on staging (pool 8, AI fallback simulated at 5%).
- Chaos: weather provider returns 503 → engine still produces non-empty cards via fail-open.
- Localization: end-to-end render in mr — assert no English fallback strings on top-10 templates.

## 15. Future hooks (not in scope; called out for forward-compat)

- `verb: "harvest_window"` requires harvest-time price data — already on the roadmap.
- "Why this action?" full audit trail on the mobile card — needs a new endpoint that returns rationale + alternatives. Cheap to add later because we already persist `rationaleTags`.
- Action card "follow-up" chain ("you sprayed Tuesday — scout for symptoms today") needs the journal we're building, plus a state-machine. Punt.
