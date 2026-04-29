const cron = require('node-cron');
const redis = require('../config/redis');
const { UsageTracking } = require('../model/Subscription');
const logger = require('../utils/logger');

/**
 * Daily prune of stale `UsageTracking` rows.
 *
 * The schema is keyed on (userId, date) where `date` is a YYYY-MM-DD
 * string. Daily counters reset implicitly because every new day creates
 * a new row. We only need this job to keep the collection from growing
 * unbounded — last 90 days is plenty for analytics + replay; anything
 * older is dead weight.
 *
 * Note on monthly counters (videoConsultationsUsed): the per-day doc
 * structure means a true "month-to-date" total has to be computed by
 * summing the current month's docs at read time. This cron does not
 * touch monthly counters; it only removes expired rows.
 */

const RETENTION_DAYS = parseInt(
  process.env.USAGE_TRACKING_RETENTION_DAYS || '90',
  10
);

const LOCK_KEY = 'main:usage-reset:cron:lock';
const LOCK_TTL_SECONDS = 60 * 30;

function thresholdDateString(daysAgo) {
  const d = new Date();
  d.setUTCDate(d.getUTCDate() - daysAgo);
  return d.toISOString().slice(0, 10);
}

async function runOnce() {
  let acquired = false;
  try {
    acquired = await redis.setIfAbsent(LOCK_KEY, String(process.pid), LOCK_TTL_SECONDS);
  } catch (e) {
    logger.warn(`usage reset cron lock acquire failed, running unlocked: ${e.message}`);
    acquired = true;
  }
  if (!acquired) {
    logger.debug('usage reset cron: another replica holds the lock, skipping');
    return;
  }

  const cutoff = thresholdDateString(RETENTION_DAYS);
  try {
    const result = await UsageTracking.deleteMany({ date: { $lt: cutoff } });
    logger.info(
      `usage reset cron: pruned ${result.deletedCount} rows older than ${cutoff}`
    );
  } catch (e) {
    logger.error('usage reset cron failed:', e.message);
  }
}

function init() {
  // 02:30 UTC daily — picks a quiet window to avoid contending with
  // user-facing read load.
  cron.schedule('30 2 * * *', () => {
    runOnce().catch((err) =>
      logger.error('usage reset cron tick failed:', err)
    );
  });
  logger.info(
    `Usage tracking prune cron scheduled (daily 02:30 UTC, retain ${RETENTION_DAYS} days)`
  );
}

module.exports = { init, runOnce };
