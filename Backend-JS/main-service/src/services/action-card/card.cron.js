const FarmProfile = require('../../model/FarmProfile');
const DailyActionCard = require('../../model/DailyActionCard');
const CardBuilder = require('./card.builder');

let cron;
try {
  cron = require('node-cron');
} catch (err) {
  cron = null;
}

let redis;
try {
  redis = require('../../config/redis');
} catch (err) {
  redis = null;
}

let logger;
try {
  logger = require('../../utils/logger');
} catch (err) {
  logger = { info: () => {}, warn: () => {}, error: () => {}, debug: () => {} };
}

const SCHEDULE = process.env.ACTION_CARD_CRON_SCHEDULE || '0,30 * * * *';
const POOL_SIZE = Math.max(1, parseInt(process.env.ACTION_CARD_POOL_SIZE || '8', 10));
const SLOT_LOCK_TTL = 600; // 10 min — covers worst-case batch wall-clock
const BUILD_LEAD_MINUTES = 30; // build cards ~30 min before each user's local push time
const DEFAULT_TZ = process.env.ACTION_CARD_DEFAULT_TIMEZONE || 'Asia/Kolkata';

let task = null;
let stats = {
  lastWindowStartedAt: null,
  lastWindowFinishedAt: null,
  lastWindowProcessed: 0,
  lastWindowSkipped: 0,
  lastWindowFailed: 0,
  totalRuns: 0,
};

// -----------------------------------------------------------------------------
// Time-window filter
// -----------------------------------------------------------------------------

/**
 * Convert "HH:mm" + IANA timezone into the next future UTC instant where
 * that local clock-time occurs. Used to decide whether a user is in the
 * current 60-min build window.
 *
 * For India (IST has no DST) this is a stable computation; for any IANA TZ
 * Intl.DateTimeFormat handles DST correctly.
 */
function nextLocalOccurrence(hhmm, timezone, now = new Date()) {
  if (!/^\d{2}:\d{2}$/.test(hhmm)) hhmm = '07:00';
  const [hh, mm] = hhmm.split(':').map((n) => parseInt(n, 10));

  // Approach: compute "what's the local time *right now* in this timezone",
  // figure out today's HH:mm UTC instant, and bump to tomorrow if already past.
  let nowLocalParts;
  try {
    const fmt = new Intl.DateTimeFormat('en-CA', {
      timeZone: timezone || DEFAULT_TZ,
      year: 'numeric', month: '2-digit', day: '2-digit',
      hour: '2-digit', minute: '2-digit', hour12: false,
    });
    const parts = Object.fromEntries(fmt.formatToParts(now).map((p) => [p.type, p.value]));
    nowLocalParts = {
      year: parseInt(parts.year, 10),
      month: parseInt(parts.month, 10),
      day: parseInt(parts.day, 10),
      hour: parseInt(parts.hour, 10),
      minute: parseInt(parts.minute, 10),
    };
  } catch (err) {
    return null;
  }

  // Build candidate "today HH:mm" in user's local TZ as a Date in UTC by
  // back-computing the offset from the same `now`.
  const localNowMinutes = nowLocalParts.hour * 60 + nowLocalParts.minute;
  const targetMinutes = hh * 60 + mm;
  const diffMinutes = targetMinutes - localNowMinutes;
  let candidate = new Date(now.getTime() + diffMinutes * 60 * 1000);
  if (diffMinutes < 0) {
    candidate = new Date(candidate.getTime() + 24 * 60 * 60 * 1000);
  }
  return candidate;
}

function withinNextWindow(hhmm, timezone, leadMinutes = BUILD_LEAD_MINUTES, now = new Date()) {
  const fire = nextLocalOccurrence(hhmm, timezone || DEFAULT_TZ, now);
  if (!fire) return false;
  const dt = (fire.getTime() - now.getTime()) / 60_000;
  return dt >= 0 && dt <= leadMinutes;
}

// -----------------------------------------------------------------------------
// Lock helpers (best-effort, single-flight per slot)
// -----------------------------------------------------------------------------

function slotKey(now = new Date()) {
  // 30-min slot key: 2026-04-25T03:00 or :30
  const s = now.toISOString().slice(0, 16);
  const min = parseInt(s.slice(14, 16), 10);
  const bucket = min < 30 ? '00' : '30';
  return `${s.slice(0, 14)}${bucket}`;
}

async function acquireSlotLock(slot) {
  if (!redis) return true;
  try {
    const client = redis.client || redis;
    if (typeof client.set !== 'function') return true;
    const result = await client.set(
      `action-card-cron-lock:${slot}`,
      String(process.pid || 'unknown'),
      'NX',
      'EX',
      SLOT_LOCK_TTL
    );
    return result === 'OK';
  } catch (err) {
    return true; // fail-open if Redis is being flaky
  }
}

async function releaseSlotLock(slot) {
  if (!redis) return;
  try {
    await redis.del(`action-card-cron-lock:${slot}`);
  } catch (err) {
    // best-effort
  }
}

async function setProgress(slot, done, total) {
  if (!redis) return;
  try {
    await redis.setex(`action-card-progress:${slot}`, 3600, `${done}/${total}`);
  } catch (err) {
    // best-effort
  }
}

// -----------------------------------------------------------------------------
// Tiny fixed-size worker pool — avoids a new dep.
// -----------------------------------------------------------------------------

async function runPool(items, workerFn, concurrency = POOL_SIZE) {
  const results = new Array(items.length);
  let next = 0;
  let done = 0;
  await Promise.all(
    Array.from({ length: Math.min(concurrency, items.length) }, async () => {
      while (true) {
        const i = next++;
        if (i >= items.length) return;
        try {
          results[i] = await workerFn(items[i], i);
        } catch (err) {
          results[i] = { error: err };
        } finally {
          done += 1;
        }
      }
    })
  );
  return { results, processed: done };
}

// -----------------------------------------------------------------------------
// Public: a single cron tick / window
// -----------------------------------------------------------------------------

/**
 * Process one 30-min window. Idempotent — safe to run repeatedly within the
 * same slot if the lock fires twice somehow. Re-runs in the next slot will
 * pick up users still missing today's card.
 */
async function runWindow({ now = new Date(), force = false } = {}) {
  const slot = slotKey(now);
  const acquired = force ? true : await acquireSlotLock(slot);
  if (!acquired) {
    logger.info?.('action-card.cron.skipped_locked', { slot, hostname: process.env.HOSTNAME });
    return { skipped: 'locked', slot };
  }

  const startedAt = Date.now();
  stats.lastWindowStartedAt = new Date(startedAt).toISOString();
  stats.totalRuns += 1;
  logger.info?.('action-card.cron.started', { slot, poolSize: POOL_SIZE });

  try {
    // Find users:
    //   - onboardingStatus completed
    //   - notifyPrefs.morningCardEnabled !== false
    //   - have at least 1 active crop (cheap server-side filter via $exists)
    // Then filter in-memory by per-user time window. Avoids a big aggregation
    // pipeline while still keeping the candidate set small enough to handle.
    const candidates = await FarmProfile.find({
      onboardingStatus: 'completed',
      'notifyPrefs.morningCardEnabled': { $ne: false },
      'crops.0': { $exists: true },
    })
      .select('userId timezone notifyPrefs preferredLanguage profileVersion')
      .lean();

    const inWindow = candidates.filter((p) => {
      const time = p.notifyPrefs?.morningCardLocalTime || '07:00';
      const tz = p.timezone || DEFAULT_TZ;
      return withinNextWindow(time, tz, BUILD_LEAD_MINUTES, now);
    });

    if (!inWindow.length) {
      logger.info?.('action-card.cron.empty_window', {
        slot,
        candidateCount: candidates.length,
      });
      stats.lastWindowProcessed = 0;
      stats.lastWindowSkipped = 0;
      stats.lastWindowFailed = 0;
      stats.lastWindowFinishedAt = new Date().toISOString();
      return { processed: 0, skipped: 0, failed: 0, slot };
    }

    // Bulk-skip users who already have today's card, before the worker pool
    // does any expensive work. The Mongo lookup is cheap (1 query, indexed).
    const todayKey = CardBuilder.todayLocalDate(DEFAULT_TZ, now);
    const existing = await DailyActionCard.find({
      userId: { $in: inWindow.map((p) => p.userId) },
      localDate: todayKey,
    })
      .select('userId')
      .lean();
    const haveCard = new Set(existing.map((c) => String(c.userId)));
    const todo = inWindow.filter((p) => !haveCard.has(String(p.userId)));

    let processed = 0;
    let failed = 0;
    let processedSinceUpdate = 0;
    setProgress(slot, 0, todo.length);

    const { results } = await runPool(
      todo,
      async (profile) => {
        try {
          const r = await CardBuilder.buildCardForUser(profile.userId, {
            generator: 'cron',
          });
          if (r?.error) failed += 1;
          else processed += 1;
          processedSinceUpdate += 1;
          if (processedSinceUpdate >= 50) {
            processedSinceUpdate = 0;
            await setProgress(slot, processed + failed, todo.length);
          }
          return r;
        } catch (err) {
          failed += 1;
          return { error: err.message };
        }
      },
      POOL_SIZE
    );

    await setProgress(slot, processed + failed, todo.length);
    const wallMs = Date.now() - startedAt;

    stats.lastWindowProcessed = processed;
    stats.lastWindowSkipped = inWindow.length - todo.length;
    stats.lastWindowFailed = failed;
    stats.lastWindowFinishedAt = new Date().toISOString();

    logger.info?.('action-card.cron.finished', {
      slot,
      candidateCount: candidates.length,
      windowSize: inWindow.length,
      alreadyHadCard: haveCard.size,
      processed,
      failed,
      wallMs,
    });

    return { processed, failed, slot, wallMs };
  } finally {
    await releaseSlotLock(slot);
  }
}

// -----------------------------------------------------------------------------
// Boot / shutdown
// -----------------------------------------------------------------------------

function start({ schedule = SCHEDULE } = {}) {
  if (task) return task;
  if (!cron) {
    logger.warn?.('action-card.cron.unavailable', {
      reason: 'node-cron not installed',
    });
    return null;
  }
  if (!cron.validate(schedule)) {
    logger.error?.('action-card.cron.invalid_schedule', { schedule });
    return null;
  }
  task = cron.schedule(
    schedule,
    () => {
      runWindow().catch((err) => {
        logger.error?.('action-card.cron.window_failed', { error: err.message });
      });
    },
    { scheduled: true, timezone: 'UTC' }
  );
  logger.info?.('action-card.cron.started', { schedule });
  return task;
}

function stop() {
  if (task) {
    task.stop();
    task = null;
  }
}

function getStats() {
  return { ...stats };
}

module.exports = {
  start,
  stop,
  runWindow,
  getStats,
  // exported for tests:
  _internal: {
    nextLocalOccurrence,
    withinNextWindow,
    slotKey,
    runPool,
    BUILD_LEAD_MINUTES,
    POOL_SIZE,
  },
};
