# B05 — Voice Chat: Cost Model & Rate Limits

Voice multiplies the per-turn cost vs text. STT, TTS, AI all bill per turn. This doc nails the unit economics, sets safe defaults, and defines what happens when costs spike.

## 1. Per-turn cost breakdown (typical Marathi farming Q)

Reference turn:
- User audio: 8 seconds.
- STT cost (Google Cloud Speech V2 logged): 8 s × ($0.016/min ÷ 60) = **$0.0021**.
- AI text in: ~150 tokens (transcript) + ~750 cached/uncached system tokens.
- AI completion out: ~250 tokens.
- AI cost (gpt-4.1-mini, 50% cached prompt): **$0.00025**.
- TTS output: ~250 chars × 18 s of audio at 24kHz = output, billed by char-count input.
- TTS cost (Google TTS Neural2 at $16/1M chars): 250 × ($16 / 1e6) = **$0.0040**.
- **Total: $0.0066** per typical voice turn.

Add 30% margin for longer-than-typical turns and provider variance → **target cap of $0.012/turn**.

## 2. Cost per active voice user per month

| Profile | Voice turns/day | Days active/mo | Monthly cost |
|---------|-----------------|----------------|--------------|
| Light user | 1 | 8 | $0.05 |
| Medium user | 3 | 15 | $0.30 |
| Heavy user | 10 | 25 | $1.65 |
| Spike abuse | 100 | 25 | $16.50 (caught by hard cap) |

At 100k MAUs with 35% voice-active and a medium-user mix → ~$10k/month voice spend. That's fine for the audience-unlock value; not fine if uncapped.

## 3. Subscription tier mapping

We re-use the existing subscription tiers (free / premium / pro). Daily voice turn limits:

| Tier | Soft daily limit | Hard daily limit | Per-turn audio max | Notes |
|------|------------------|------------------|---------------------|-------|
| Free | 10 voice turns | 30 | 30 s | A "voice turn" is a successful STT→AI→TTS cycle. STT-only failures don't count. |
| Premium (₹49/mo) | 50 | 100 | 60 s | Aligns with current premium daily message cap × 1.5. |
| Pro (₹149/mo) | unlimited (soft fair-use) | 300 | 60 s | Hard cap protects against runaway scripts. |

The soft limit shows a friendly nudge ("you've used 10/10 free voice turns today") with a tier-upgrade CTA. The hard limit returns 429 with `code: VOICE_QUOTA`.

Enforced server-side in `voice-quota.service.js` (B03 §8). Both limits live in env vars so we can tune without code release:

```
VOICE_FREE_SOFT_LIMIT=10
VOICE_FREE_HARD_LIMIT=30
VOICE_PREMIUM_SOFT_LIMIT=50
VOICE_PREMIUM_HARD_LIMIT=100
VOICE_PRO_HARD_LIMIT=300
VOICE_MAX_AUDIO_SEC_FREE=30
VOICE_MAX_AUDIO_SEC_PAID=60
```

## 4. Per-turn caps

Independent of tier:

| Cap | Value | Why |
|-----|-------|-----|
| Audio file size | 1 MB | Hard upload limit; 60s of AAC is ~120 KB so this is just a guard rail. |
| Audio duration | 60 s | Force focused questions; longer is usually unfocused. |
| AI input tokens (post-tree fitting) | 2500 | Same as text-chat budget. |
| AI output tokens | 800 | Same as text-chat. |
| TTS output chars | 1500 | Caps a runaway answer at ~90 s of audio. |

If the AI reply exceeds the TTS cap, we synthesize the first 1500 chars and append a `[contd. — read text]` cue at the end. The text bubble still shows the full answer; voice mode just stops speaking after 90s.

## 5. Global service-level caps

| Cap | Value | Behavior on hit |
|-----|-------|-----------------|
| Voice turns per minute (whole service) | 600 | New requests get 503 `code: SERVICE_VOICE_BUSY` until the minute rolls. |
| Voice cost / minute (USD) | $5 | Engages `ai:killswitch:voice` for 5 min and pages oncall. |
| Voice cost / hour (USD) | $50 | Engages a 1-hour killswitch and pages. |
| Voice cost / day (USD) | $500 | Hard kill until manual review. |

These are circuit breakers, not throttles for normal load. With current pricing, hitting $50/hr means ~7000 voice turns/hr — well above projected steady-state, so a hit would mean abuse, runaway loop, or genuine viral moment.

## 6. Killswitch design

Two layers:

### Provider-level (existing)
- `ai:killswitch:voice` set to "1" in Redis.
- Voice controller short-circuits; mobile feature flag also flips.

### Tier-aware (new)
A finer killswitch in case STT goes bad but TTS is fine, or vice versa:
- `voice:killswitch:stt` — STT call returns `STT_DISABLED`; voice button hidden.
- `voice:killswitch:tts` — TTS skipped; turns become text-only with the transcript still shown.

All three are admin-toggleable via `/api/admin/ai-ops/killswitch/:target` (the existing endpoint we wired in T35). Targets get extended:
```js
const KILLSWITCH_KEYS = {
  global:    'ai:killswitch:global',
  openai:    'ai:killswitch:openai',
  vertex:    'ai:killswitch:vertex',
  voice:     'ai:killswitch:voice',
  voice_stt: 'voice:killswitch:stt',
  voice_tts: 'voice:killswitch:tts',
};
```

## 7. Provider-level RPM ceilings

Google Cloud Speech V2 has a default 900 RPM in asia-south1. We cap our own usage at 600 RPM so a burst doesn't trip provider throttling. Same for TTS (default 1000 RPM, we cap at 800).

Implementation: a token-bucket per provider at the factory layer:

```js
// services/voice-rate-limiter.service.js
const sttBucket = new TokenBucket({ capacity: 600, refillPerSec: 10 });
const ttsBucket = new TokenBucket({ capacity: 800, refillPerSec: 13 });
```

If a token isn't available within 200 ms, the request fails fast with `code: PROVIDER_THROTTLED` and the voice turn returns an error event. Rare in steady state.

## 8. Cost ledger

Every successful voice turn writes to the existing `AIChat.usage` plus a new `voice` block:

```js
chat.voice = chat.voice || { turns: 0, sttCostUsd: 0, ttsCostUsd: 0, totalAudioSec: 0 };
chat.voice.turns += 1;
chat.voice.sttCostUsd += sttCost;
chat.voice.ttsCostUsd += ttsCost;
chat.voice.totalAudioSec += audioOutSec;
chat.usage.estimatedUsdCost += (sttCost + ttsCost + aiCost);
```

This means the existing admin usage card (T46e) shows total cost; we add a "Voice" row that breaks out STT vs TTS vs AI.

## 9. Per-day per-user rolling cost cap

In addition to turn-count limits, we enforce a daily $-cap per user:

| Tier | Daily $ cap |
|------|-------------|
| Free | $0.50 |
| Premium | $1.50 |
| Pro | $5.00 |

This protects against runaway in cases where the AI somehow generates a 4000-character reply (TTS spend balloons). Implementation: extends `token-usage.service.dailyCostUsd(userId)` to include voice spend.

## 10. Refund policy

If a voice turn fails before AI starts (STT empty, STT error, audio too short), we **refund** the quota count — the user shouldn't be punished for STT misreads. Cost-wise:
- STT call still bills us — that's a sunk cost we eat.
- AI + TTS not invoked — no spend.

If a voice turn fails after AI starts (TTS errors mid-way), we **don't refund** — the user got a useful text answer; the playback is the loss. We log `partial_voice_turn` for analytics.

## 11. Abuse mitigation

| Vector | Mitigation |
|--------|-----------|
| Single user holding the button forever | 60s hard stop on the recorder + 1 MB upload limit. |
| Script firing voice POSTs | Per-user daily hard cap (30 free, 100 premium). Per-IP rate limit at gateway (existing). Auth required. |
| Replay endpoint hammered | 60/min/user rate limit. Audio is only served for messages owned by the requester. |
| Long-form prompt injection ("respond with 50,000 chars") | TTS char cap (1500) + text answer's existing 800-token output cap. |
| "Free" abuse via ephemeral signups | Phone verification + per-phone-number daily cap (auth layer; existing). |
| Misuse of TTS to generate audio for unrelated content | TOS enforcement; rate limits make bulk extraction infeasible. Replay endpoint only returns audio tied to a chat message that was an AI reply to that user. |

## 12. Cohort cost simulation

Backend test (k6 or a simple Node script) that simulates:
- 1000 users at 5 voice turns/day each
- 50% English, 30% Hindi, 20% Marathi
- 8s avg audio, 250-char avg reply
- 7-day window

Assertions:
- Total spend ≤ $250.
- P95 turn latency ≤ 5s.
- 0 quota-exhausted users (matches expected limits).
- 0 STT throttle errors.

This is a launch-readiness gate — wired into the existing load-test job.

## 13. Forecast → budget signoff

Operations needs an answer to "what's the worst case if we ship this?". Provided:

| Scenario | Voice DAU | Avg turns/DAU | Daily spend |
|----------|-----------|---------------|-------------|
| Conservative | 5k | 2 | $66 |
| Expected | 25k | 3 | $495 |
| Spike | 75k | 5 | $2,475 |
| Runaway (kill at $500/day) | n/a | n/a | capped $500 |

Premium revenue more than covers expected spend; spike triggers the $50/hr killswitch automatically.

## 14. Feature-flag gradual rollout

Mirrors text-chat rollout:

| Stage | Cohort | Daily spend at this stage (conservative) |
|-------|--------|------------------------------------------|
| Internal beta | 5 staff | < $1/day |
| Stage 1 (5%) | 5k DAU | ~$60/day |
| Stage 2 (20%) | 20k | ~$240/day |
| Stage 3 (50%) | 50k | ~$600/day |
| Full | 100k | ~$1,200/day |

Each stage held for ≥ 3 days before promoting; the killswitch hold-points are an absolute backstop.

## 15. Cost reduction levers (for later)

If voice spend becomes a P0:

1. **Switch TTS to OGG-Opus output** — 30% smaller bytes, slightly cheaper egress; same cost from provider.
2. **Move STT to AI4Bharat self-hosted** — eliminate $/min STT cost (replace with hardware cost amortised).
3. **Cache TTS aggressively** — if many users get the same reply (templated answers), cache the audio keyed on `sha1(text + voice)` so a popular answer is synthesised once.
4. **Truncate AI replies more aggressively for voice** — voice users prefer shorter answers; cap output at 500 chars (~30s audio).
5. **Charge for voice in the premium tier** — current ₹49/mo includes voice; carve out a "voice add-on" if economics demand.

We intentionally keep all five out of scope for launch. Knowing they exist is enough.

## 16. Admin dashboard panels (extends T46e)

Add a "Voice" tab to the existing AI usage card:

| Stat | Source |
|------|--------|
| Voice turns today / 7d | `AIShadowLog`-style aggregate |
| Avg turn cost (last 24h) | sum(stt+tts+ai)/turns |
| STT vs TTS vs AI spend split | from chat.voice ledger |
| Top languages by turn count | from `AIChat.messages[].voice.language` |
| Quota-exhausted users today | from Redis quota counter snapshot |
| Provider error rate (last 1h) | `krishi_voice_provider_errors_total` |
| Killswitch state | from Redis |

Same Next.js stack as T46e; reuses the `aiStats` API client with a new `voice()` method.

## 17. Pricing page copy (mobile / website)

Once Voice ships:

- Free: "10 free voice questions per day, English/Hindi/Marathi."
- Premium ₹49/mo: "50 voice questions/day, replies in your language with audio playback."
- Pro ₹149/mo: "Unlimited voice questions (fair use), priority response."

## 18. SLA targets (post-launch)

| Metric | Target |
|--------|--------|
| Voice turn P50 latency (release → first audio play) | ≤ 2.5 s |
| Voice turn P95 latency | ≤ 4.5 s |
| Voice turn P99 latency | ≤ 8.0 s |
| Voice turn success rate | ≥ 97% |
| Daily cost variance vs forecast | within 30% |

Drive these via the Prometheus dashboards (B03 §13).
