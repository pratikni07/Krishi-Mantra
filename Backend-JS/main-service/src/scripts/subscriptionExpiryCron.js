const cron = require('node-cron');
const redis = require('../config/redis');
const { UserSubscription } = require('../model/Subscription');
const { notify } = require('../utils/notificationClient');
const logger = require('../utils/logger');

/**
 * Daily background job that nudges users when their subscription is about
 * to expire. Without this, a user's plan silently lapses and they only
 * notice once a paywall blocks them — by which point the auto-renew window
 * has closed and conversion to renewal craters.
 *
 * Two windows: 7 days out (gentle reminder) and 1 day out (last call).
 * Per-(userId, planEndDate, window) dedupe via Redis means re-running the
 * job (manually or after a deploy) does not re-spam users.
 */

const REMINDER_WINDOWS = [
  { days: 7, kind: 'week', subject: 'Your plan expires in a week' },
  { days: 1, kind: 'day', subject: 'Your plan expires tomorrow' },
];

const DEDUPE_TTL_SECONDS = 60 * 60 * 24 * 14; // 14 days, longer than the longest window

const LOCK_KEY = 'main:subscription-expiry:cron:lock';
// Cron runs daily; lock is shorter than 24h so a missed unlock recovers next day.
const LOCK_TTL_SECONDS = 60 * 30;

/**
 * Returns the start (00:00 UTC) and end (23:59:59.999 UTC) of the day
 * exactly `daysFromNow` from `now`. Boundary alignment is what lets the
 * dedupe key be stable across runs within the same calendar day.
 */
function dayWindow(daysFromNow, now = new Date()) {
  const start = new Date(Date.UTC(
    now.getUTCFullYear(),
    now.getUTCMonth(),
    now.getUTCDate() + daysFromNow,
    0, 0, 0, 0,
  ));
  const end = new Date(start.getTime() + 24 * 60 * 60 * 1000 - 1);
  return { start, end };
}

async function alreadyNotified(userId, endDateIso, kind) {
  const key = `subscription:expiry:notified:${userId}:${endDateIso}:${kind}`;
  try {
    const acquired = await redis.setIfAbsent(key, '1', DEDUPE_TTL_SECONDS);
    // setIfAbsent returns true iff we won the slot. If something else
    // already wrote the key, we've already notified — skip.
    return !acquired;
  } catch (e) {
    logger.warn(`expiry cron dedupe check failed: ${e.message}`);
    // On Redis outage, prefer "send" — duplicate notification is less bad
    // than a silent expiry.
    return false;
  }
}

async function processWindow(window) {
  const { start, end } = dayWindow(window.days);
  const subs = await UserSubscription.find({
    status: 'active',
    autoRenew: { $ne: true },
    endDate: { $gte: start, $lte: end },
  }).lean();

  for (const sub of subs) {
    const endDateIso = new Date(sub.endDate).toISOString().slice(0, 10);
    if (await alreadyNotified(sub.userId, endDateIso, window.kind)) continue;

    notify({
      userId: sub.userId.toString(),
      title: window.subject,
      message: window.days === 1
        ? `Your ${sub.planName} plan ends tomorrow. Renew now to avoid losing access.`
        : `Your ${sub.planName} plan ends in ${window.days} days. Renew anytime to keep your benefits.`,
      type: `subscription.expiring.${window.kind}`,
      data: {
        planName: sub.planName,
        endDate: sub.endDate,
        billingCycle: sub.billingCycle,
        daysRemaining: window.days,
      },
    });
  }
  return subs.length;
}

async function runOnce() {
  // Cluster-wide lock — same pattern as auto-post / auto-reel. Prevents
  // every PM2 / k8s replica from emitting the same N notifications.
  let acquired = false;
  try {
    acquired = await redis.setIfAbsent(LOCK_KEY, String(process.pid), LOCK_TTL_SECONDS);
  } catch (e) {
    logger.warn(`expiry cron lock acquire failed, running unlocked: ${e.message}`);
    acquired = true; // best-effort
  }
  if (!acquired) {
    logger.debug('expiry cron: another replica holds the lock, skipping');
    return;
  }

  for (const window of REMINDER_WINDOWS) {
    try {
      const count = await processWindow(window);
      logger.info(`expiry cron: ${window.kind} window scanned ${count} subs`);
    } catch (e) {
      logger.error(`expiry cron: ${window.kind} window failed: ${e.message}`);
    }
  }
}

function init() {
  // 09:00 UTC daily — late morning IST without being pre-dawn elsewhere.
  cron.schedule('0 9 * * *', () => {
    runOnce().catch((err) =>
      logger.error('subscription expiry cron tick failed:', err)
    );
  });
  logger.info('Subscription expiry reminder cron scheduled (daily 09:00 UTC)');
}

module.exports = { init, runOnce, dayWindow };
