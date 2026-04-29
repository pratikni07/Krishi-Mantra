# 03 — Consultant Interaction Analytics

The user's specific request: track interactions with consultants, find which consultants get more requests. Today: zero tracking, zero analytics, no admin view.

## What "consultant interaction" means

Distinguish four moments of contact, each instrumented separately:

| Step | When | Event | Why it matters |
|---|---|---|---|
| 1. Discovery | User browses the consultant directory / search | `consultant_directory_view`, `consultant_search`, `consultant_filter` | What filters do users actually use? Where do they drop off? |
| 2. Profile look | User taps a consultant card | `consultant_profile_view` | Top-of-funnel. The "interest" signal even before contact. |
| 3. Request | User initiates a chat with the consultant | `consultant_chat_request` | The headline KPI: which consultants get more requests. |
| 4. Outcome | Consultant accepts / chat ends / user rates | `consultant_chat_accepted`, `consultant_chat_completed`, `consultant_rating_submitted` | Conversion + quality signals. |

Plus per-message volume from the existing `chat_message_sent`/`chat_message_received` events (already in the SDK), filtered to chats whose participants include a consultant.

## Frontend instrumentation

### Where these fire

- **`message_controller.dart`** is the existing chat controller. Most of the chat events live here. Extend it.
- **A consultant directory screen exists** — confirm via `lib/presentation/screens/cropcare/` (this is the consultant-chat module per the file structure). Update the corresponding controller too. If a separate `consultant_controller.dart` doesn't exist, the directory logic is likely inside `cropcare/ChatListScreen.dart` or a `ConsultantsScreen`. Trace once and put the events on the right path.

### Event details

```dart
// In EngagementService:
static const consultantDirectoryView = 'consultant_directory_view';
static const consultantProfileView   = 'consultant_profile_view';
static const consultantChatRequest   = 'consultant_chat_request';
static const consultantChatAccepted  = 'consultant_chat_accepted';
static const consultantChatCompleted = 'consultant_chat_completed';
static const consultantRatingSubmitted = 'consultant_rating_submitted';

void trackConsultantProfileView(String consultantId, {Map<String, dynamic>? properties}) {
  trackEvent(
    EventName.consultantProfileView,
    eventCategory: EventCategory.communication,
    properties: {
      'contentId': consultantId,
      'contentType': 'consultant',
      ...?properties,
    },
  );
}

void trackConsultantChatRequest(String consultantId, {required String source}) {
  trackEvent(
    EventName.consultantChatRequest,
    eventCategory: EventCategory.communication,
    properties: {
      'contentId': consultantId,
      'contentType': 'consultant',
      'source': source, // 'directory' | 'profile' | 'recommendation' | 'crop_calendar_link'
    },
  );
}
```

`source` is critical — answers "where did the request originate?" If 70% of consultant requests come from the crop-calendar deep-link, that's a product insight.

### What NOT to log

- Message contents (privacy + already covered by `chat_message_sent` count).
- Consultant phone numbers / personal contact.
- Specific medical / financial details users may share with consultants.

## Backend additions

### 1. Event-enum entries

Already listed in `02-gaps-and-instrumentation-plan.md` section D — add the six `consultant_*` names plus a `consultant` content-type entry to the `properties.contentType` enum on `event.model.js`.

### 2. Consultant analytics endpoint

The existing `/analytics/leaderboard` and `/analytics/users/:userId` endpoints can be re-purposed but they're user-generic. Add a consultant-specific aggregation:

`GET /api/engagement/analytics/consultants/leaderboard`

Response:
```json
{
  "from": "2026-04-01T00:00:00Z",
  "to": "2026-04-27T00:00:00Z",
  "consultants": [
    {
      "consultantId": "65a...",
      "name": "Dr. R. Kumar",     // joined from main-service Users collection
      "avatar": "https://...",
      "directoryViews": 4521,
      "profileViews": 1304,
      "chatRequests": 312,
      "chatsAccepted": 287,
      "chatsCompleted": 251,
      "uniqueUsersRequested": 268,
      "averageRating": 4.6,
      "responseAcceptanceRate": 0.92,
      "completionRate": 0.87,
      "trend7d": 0.14,             // +14% vs prior 7-day window
      "topRequestSources": [{"source":"profile","count":201},{"source":"directory","count":76}]
    }
  ]
}
```

Query params: `from`, `to`, `limit` (default 25), `sortBy` (`requests` | `acceptance` | `rating` | `trend`).

Implementation:
- Aggregate `events` collection on `eventName ∈ { consultant_* }` with `$group` by `properties.contentId` (the consultantId).
- Join with users (or pre-cache consultants in Redis on a 5-min TTL — admin reads can tolerate that latency).
- For `averageRating`, source from a `consultant_ratings` collection (next section) — not from events.

### 3. Consultant rating store

Events log the act of rating; the rating itself should also be a row in a real collection so it can be queried/edited/audited.

Add `consultantRating.model.js` in `main-service` (where Users live) or in `message-svc` if consultants are managed there:

```js
{
  consultantId: ObjectId,
  userId: ObjectId,
  chatId: ObjectId,
  rating: { type: Number, min: 1, max: 5 },
  reviewText: { type: String, max: 1000 },
  createdAt: Date,
}
```

Endpoint: `POST /api/main/consultants/:consultantId/rating` (auth required, one rating per (user, chat) pair, upsert allowed).

Consultant `averageRating` and `ratingCount` get computed live from this collection (or denormalized onto User on rating write).

### 4. Server-side authoritative events

The consultant-request flow is business-critical. Frontend SDK can be lossy. After the chat request lands on `message-svc` (`chat_create_direct` or whichever endpoint creates a consultant chat), emit a server-side `consultant_chat_request` event via the engagement-emitter helper. Same for `consultant_chat_accepted` when the consultant socket-acks.

**Detection of "is this a consultant chat":** check the participant's `accountType === 'consultant'` (assuming the User model has that flag — verify in `main-service/src/model/User.js`). If not, add the flag and a backfill migration.

## Admin panel — consultant page

Two surfaces:

### 5. New `/consultants` admin page (probably already a directory, confirm)

Standard list view of consultants pulled from `main-service`, filterable by `accountType === 'consultant'`. **Augment each row with the engagement KPIs** by calling the new `/analytics/consultants/leaderboard` endpoint and merging on `consultantId`:

Columns:
- Avatar, name, specialization
- Directory views (last 7 d / last 30 d)
- Profile views
- **Chat requests** (the headline number)
- Acceptance rate, completion rate
- Average rating, rating count
- Trend (7d sparkline)

Sorting + filter by date range + CSV export.

### 6. Consultant detail page

Click into a consultant → time-series of requests, hourly heatmap (when do users contact them), `topRequestSources` breakdown, request → accept → complete funnel, list of recent ratings + review text.

### 7. "Why isn't consultant X getting requests?" diagnostic

Useful product question. Show on the detail page:
- Profile view count (proxy for visibility) vs requests (proxy for conversion).
- A profile-view-to-request rate that's below the platform median is the bottleneck signal.
- Compare against similar consultants in the same specialization.

## Acceptance criteria

- [ ] After one production day: every step of the consultant funnel has at least one event recorded.
- [ ] `/api/engagement/analytics/consultants/leaderboard` returns sane data; manual spot-check matches what's in `events` collection.
- [ ] Admin can sort consultants by chat-request count and identify the top 5 / bottom 5.
- [ ] Discrepancy between server-side `consultant_chat_request` count and frontend-emitted count is < 5% (any larger gap is the FE losing events — investigate).
- [ ] No PII leaks audit: no message bodies, phone numbers, or rating text appear in `events` (rating text lives only in `consultant_ratings`).
