# 04 — Admin Panel Dashboards

The admin panel exists (`Frontend/admin-panel/`, Next.js + Tailwind + Recharts) and already has wrappers for every analytics endpoint in `lib/api.ts`. The `/analytics` page is a skeleton. This file lists exactly what should render where.

## Principle

Build for **decisions**, not just charts. Each dashboard answers a specific question a product/business person actually asks.

## Dashboard 1 — Realtime pulse (top of `/analytics`)

Already partially wired via `engagementAPI.getRealTimeStats()`.

Render:
- **Active users last 5 min** (large number).
- Active sessions last 1 h.
- Top 5 currently-viewed screens (live ranking).
- Events/sec for the last 60 min as a sparkline.
- Most-active region (city or state) — pulls from `event.location.city`.

Refresh every 15 s. If the count drops to 0 for 5+ min, surface a warning banner — likely an SDK or backend problem.

## Dashboard 2 — Feature interest ("which features are users using?")

This is the question the user explicitly asked: *"depending on the user interest we will build more features."*

Page: `/analytics/features` (new sub-route).

Sources: `engagementAPI.getFeatureUsage()` and `getEngagementBreakdown()`.

Render:
- Stacked bar of events by `eventCategory` over the selected window. Each bar = one day.
- Per-feature row table:
  - Feature name (feed, reels, ai_chat, consultant_chat, marketplace, crop_calendar, video_tutorials, schemes, weather, mandi, disease_detection, subscription).
  - Unique users (last 7 d, last 30 d).
  - Total events.
  - **Average minutes per user per day** (uses `screen_exit.properties.duration` summed by screenName mapping → feature).
  - 7-day trend (sparkline + delta %).
- "Adoption funnel" widget per feature — % of users who:
  1. Visited the feature screen at least once.
  2. Took at least one action (feed_like, ai_message_send, etc., per-feature mapping).
  3. Returned within 7 days.

**Required mapping table** (a constant in admin code, source-of-truth for the dashboard):

```ts
const FEATURE_MAP = {
  feed: { screens: ['feed','feed_details'], actions: ['feed_view','feed_like','feed_comment','feed_create'] },
  reels: { screens: ['reels'], actions: ['reel_view','reel_like','reel_comment','reel_complete'] },
  consultant_chat: { screens: ['chat_list','chat_detail'], actions: ['consultant_chat_request','chat_message_sent'] },
  ai_chat: { screens: ['ai_chat'], actions: ['ai_chat_start','ai_chat_message','ai_image_analyze'] },
  marketplace: { screens: ['marketplace','product_details'], actions: ['product_view','product_search','product_inquiry'] },
  crop_calendar: { screens: ['crop_calendar','crop_details'], actions: ['crop_calendar_view','crop_activity_view'] },
  // …
};
```

This is the join key between screen-level and action-level signals. Without it, the dashboard either undercounts (only events) or overcounts (every passive scroll). With it, the answer is real.

## Dashboard 3 — Screen-time heatmap

Page: `/analytics/screens`.

Source: `engagementAPI.getTopScreens()` augmented with `screen_exit` durations.

Render:
- Bar chart: **median time-on-screen per screen** (top 20).
- Heatmap: rows = screen, columns = hour-of-day (0–23), cell intensity = total visits.
- "Bounce" rate per screen — % of visits where `duration < 3 s`. Above 30% is suspicious — UI confusion or instant-back navigation.

## Dashboard 4 — User retention & churn

Pages: `/analytics/retention`, `/analytics/churn`.

Sources: `engagementAPI.getRetentionMetrics()`, `getChurnRiskAnalysis()`.

Render:
- Cohort retention table: rows = signup week, columns = weeks since signup, cells = % active.
- Daily active / weekly active / monthly active line chart.
- Churn-risk users list (sortable, exportable). Clicking → user analytics drill-down.

## Dashboard 5 — Consultant leaderboard (`03-consultant-analytics.md`)

Page: `/consultants` augmented as described in file 03. The headline answer to "which consultants get more requests."

## Dashboard 6 — Conversion funnels

Page: `/analytics/funnels`.

Two pre-built funnels matter most:

**Onboarding funnel:**
1. `app_open` (first session ever)
2. `screen_view` of `language_selection`
3. `screen_view` of `phone_number`
4. `user_signup`
5. `onboarding_completed`
6. First content interaction (any of: `feed_view`, `reel_view`, `ai_chat_start`, etc.)

Where do new users drop off? If 60% complete onboarding but only 20% take a content action that day, the home screen needs work.

**Consultant request funnel:**
1. `consultant_directory_view`
2. `consultant_profile_view`
3. `consultant_chat_request`
4. `consultant_chat_accepted`
5. `consultant_chat_completed`

Each step shows count + % surviving. Click a step → list of `userId`s who reached step N but not step N+1 (within 24 h).

## Dashboard 7 — Per-user drill-down

Page: `/users/:userId/activity` (new sub-route on the existing `/users` page).

Source: `engagementAPI.getUserAnalytics(userId)`.

Render:
- User's session history (last 30 d).
- Time spent per feature.
- Most-viewed content.
- Last 100 events as a table (eventName, screenName, timestamp, properties JSON).
- Streak / engagement score / churn risk badge.

Useful for support when a user reports "the app didn't work" — you can see what they actually did.

## Implementation notes

- Use the existing `engagementAPI` wrapper in `Frontend/admin-panel/src/lib/api.ts`. Add new methods (`getConsultantsLeaderboard`, `getFunnel`) as small additions, not rewrites.
- Charts: stick with Recharts (already imported on `analytics/page.tsx`). No new chart library.
- All dashboards default to "last 7 days" window with a date-range picker. Persist last-used window in admin settings.
- Server-side caching: every analytics endpoint should cache its response in Redis for 60 s. Single user refreshing the dashboard shouldn't hammer the time-series collection.

## Authorization

The admin panel must require `accountType === 'admin'`. The existing gateway middleware should already enforce this — verify before exposing engagement data, since events include device + location for every user.
