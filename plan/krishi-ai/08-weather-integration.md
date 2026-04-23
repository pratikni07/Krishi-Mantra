# 08 — Weather Integration (±3 days)

The AI prompt needs a **7-day window**: D-3, D-2, D-1, D (today), D+1, D+2, D+3. This doc covers provider choice, bucketing, caching, refresh jobs, API surface, mobile integration, and failure modes.

## 1. Provider choice

Two candidates considered:

| | Open-Meteo | OpenWeather OneCall 3.0 |
|--|------------|--------------------------|
| Cost | Free (non-commercial) / €29/mo commercial | $0.0015/call after 1k/day free |
| Past data | ✓ (historical endpoint) up to 7 days recent | ✓ (History API, paid extra) |
| Forecast | ✓ 16-day | ✓ 7-day |
| Hourly resolution | ✓ | ✓ |
| Keyless | ✓ | ✗ |
| Rate limit | ~10k calls/day (soft) | Plan-based |
| Reliability | Generally good, occasional 429s | Very high |

**Plan:** use Open-Meteo as the default provider; keep OpenWeather as a drop-in fallback behind `WEATHER_PROVIDER=openweather`. Abstraction layer makes switching easy.

Rationale:
- Zero cost at our current scale.
- Past + future in one geographic context without two separate endpoints.
- Aligns with the 1 h Redis TTL — we don't hammer them.

## 2. Endpoints

### Open-Meteo request (server-side)
```
GET https://api.open-meteo.com/v1/forecast
  ?latitude=19.99&longitude=73.79
  &past_days=3&forecast_days=4
  &daily=temperature_2m_max,temperature_2m_min,precipitation_sum,
        relative_humidity_2m_mean,wind_speed_10m_max,weather_code
  &timezone=auto
```

Returns `daily` arrays of length 7, aligned to `daily.time[]` (strings `YYYY-MM-DD`). We map 1:1 to our `WeatherSnapshot.days[]`.

### OpenWeather request (fallback)
```
GET https://api.openweathermap.org/data/3.0/onecall
  ?lat=19.99&lon=73.79&units=metric&exclude=minutely,hourly,alerts&appid=$KEY
+ GET .../onecall/timemachine?lat=…&lon=…&dt=…  (3 calls for past days)
```

Combined into the same 7-day shape.

## 3. Bucket strategy (to maximize cache hit)

Two farmers in the same ~1 km² should share a snapshot.

- **Key = `lat,lon` rounded to 2 decimal places** → ~1.1 km cell.
- Example: farm at (19.9923, 73.7871) → bucket `"19.99,73.79"`.
- Separate bucket for each village-ish cell. 2 decimals is a sweet spot: fine enough that microclimate differences rarely matter for day-scale guidance, coarse enough that hundreds of farmers in the same taluka share.

## 4. Cache layers (defense in depth)

```
Caller → Redis (15 min TTL) → Mongo (1 h TTL via index) → Provider API
```

1. **Redis `weather:{bucket}`** — JSON serialized snapshot, TTL 15 min, primary cache.
2. **Mongo `weather_snapshots`** — TTL 1 h via `expireAfterSeconds: 0` on `expiresAt`. Keeps a snapshot usable even if Redis is flushed.
3. **Provider API** — last resort on cold cache.

`WeatherService.get7Day(lat, lon)` logic:
```js
const bucket = bucketKey(lat, lon);
let snap = await redis.getJSON(`weather:${bucket}`);
if (snap && snap.expiresAt > now) return snap;

snap = await WeatherSnapshot.findOne({ bucket });
if (snap && snap.expiresAt > now) {
  await redis.setJSON(`weather:${bucket}`, snap, 15*60);
  return snap;
}

// single-flight lock so we don't hammer provider
const lockAcquired = await redis.set(`weather:lock:${bucket}`, "1", "NX", "EX", 10);
if (!lockAcquired) { await sleep(200); return get7Day(lat, lon); } // tiny retry

const fresh = await provider.fetch(lat, lon);
snap = await WeatherSnapshot.findOneAndUpdate(
  { bucket },
  { ...fresh, bucket, lat, lon, asOf: new Date(), expiresAt: new Date(Date.now() + 60*60*1000) },
  { upsert: true, new: true }
);
await redis.setJSON(`weather:${bucket}`, snap, 15*60);
await redis.del(`weather:lock:${bucket}`);
return snap;
```

## 5. Proactive refresh job

An hourly cron hits popular buckets so the first farmer of the hour doesn't pay the fetch latency:

```js
// Backend-JS/message-svc/src/jobs/weather-refresh.job.js
cron.schedule("*/30 * * * *", async () => {
  const activeBuckets = await redis.smembers("weather:active-buckets");
  for (const b of activeBuckets) {
    if (await redis.ttl(`weather:${b}`) < 300) {
      await WeatherService.get7Day(...parseBucket(b));
    }
  }
});
```

`weather:active-buckets` is a Redis SET populated on every `get7Day` call (with a 7-day expiry per entry — implemented with a sorted set scored by last-access timestamp and a trim). Target: keep set size <5000.

## 6. Integration with the AI context tree

Context-tree L3 builder calls `WeatherService.get7Day(profile.location.coordinates)` and renders:

```
WEATHER (Sinnar, Nashik — ±3 days around 2026-04-21)
- 04-18: 22–35°C, 0 mm, sunny
- 04-19: 23–36°C, 0 mm, sunny
- 04-20: 23–37°C, 0 mm, sunny
- 04-21: 24–38°C, 0 mm, mostly-sunny  (today)
- 04-22: 24–38°C, 0 mm, mostly-sunny
- 04-23: 23–36°C, 3 mm, light rain
- 04-24: 22–34°C, 8 mm, rain
```

Ordering is critical: past first, today marked, future. Makes model reasoning ("it rained yesterday, so…") straightforward.

Layer fingerprint includes bucket + today's date (`YYYY-MM-DD`), so caches rotate correctly at midnight.

## 7. API surface for mobile

The mobile app also shows weather on the home screen. Today it calls OpenWeather directly from the client. Plan:

- Expose `GET /api/weather/7day?lat=…&lon=…` from message-svc (proxied via gateway).
- Mobile switches from calling OpenWeather directly → calling our endpoint.
- Benefit: single cache for both AI + UI, one API key to manage, fewer external API keys distributed in mobile app (the current `weather_service.dart` has the key embedded — security smell).

Response shape:
```json
{
  "bucket": "19.99,73.79",
  "location": { "lat": 19.99, "lon": 73.79 },
  "asOf": "2026-04-21T03:00:00Z",
  "days": [
    { "date": "2026-04-18", "tempMin": 22, "tempMax": 35, "humidityMean": 48,
      "rainfallMm": 0, "windSpeedKmh": 9, "condition": "sunny" },
    ...
  ]
}
```

Back-compat: keep `weather_service.dart` working against OpenWeather for one release as a fallback path. Then remove.

## 8. Failure modes

| Failure | Behavior |
|---------|----------|
| Redis down | Go to Mongo, then provider. |
| Mongo down | Still respond via Redis; provider as last resort. |
| Provider 5xx/timeout (10s) | Try OpenWeather fallback if configured. |
| Both providers down | Return last known snapshot regardless of staleness; log `weather.stale_served`; AI layer adds note "weather data ≥1 h old". |
| No location on profile | Layer L3 skipped entirely; AI proceeds without weather. |
| Location outside provider coverage (unlikely in India) | Default to nearest 0.25° bucket; log `weather.coverage_fallback`. |

## 9. Privacy & security

- Lat/lon never logged in plaintext; we log the bucket key only.
- Provider requests go out over HTTPS with our server IP; user identity never passes to provider.
- No PII (name, phone) ever goes to weather providers.

## 10. Storage cost estimate

- ~10k active buckets across India × ~1 kB per snapshot × rebuilt every 60 min = 10 MB steady. Negligible.
- TTL index prunes expired docs automatically.

## 11. Units & localization

- Internal storage always metric (°C, mm, km/h).
- Presentation layer (mobile UI, AI prompt) localizes. In India we stay metric everywhere.
- Rain is `precipitation_sum` in mm (Open-Meteo default).

## 12. Implementation checklist

- [ ] `services/weather.service.js` with `get7Day(lat, lon)` contract
- [ ] `providers/open-meteo.provider.js`
- [ ] `providers/openweather.provider.js` (fallback)
- [ ] `models/weather-snapshot.model.js` (doc 04)
- [ ] Route `GET /api/weather/7day` with JWT + rate-limit
- [ ] Gateway proxy rule
- [ ] Proactive refresh cron
- [ ] Metrics: `weather_fetches_total{provider,status}`, `weather_cache_hits_total{layer}`, `weather_stale_serves_total`
- [ ] Unit tests with nock recordings of both providers
- [ ] Chaos test: provider 500 → fallback verified
