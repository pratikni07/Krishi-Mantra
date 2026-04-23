const redis = require('../config/redis');
const logger = require('./logger');

// Per-phone OTP rate limits. The gateway already caps /auth/* requests
// per IP, but a rotating-IP attacker can still burn through 6-digit OTPs
// targeting one phone number — this closes that hole.
//
// - initiate: 5 sends / hour / phone (matches typical OTP UX)
// - verify:   10 attempts / hour / phone (complements the 3-attempts-per-OTP
//   check on WhatsAppOTP itself)
//
// Fails open on Redis outage: we log and allow the request. The gateway
// IP limiter remains as a floor. Fail-closed here would trade one DoS
// surface (Redis down → every login blocked) for another.

const BUCKETS = {
  initiate: { limit: 5, windowSec: 60 * 60 },
  verify: { limit: 10, windowSec: 60 * 60 },
};

const key = (bucket, phoneNo) => `otp:rl:${bucket}:${phoneNo}`;

async function checkAndConsume(bucket, phoneNo) {
  const cfg = BUCKETS[bucket];
  if (!cfg) throw new Error(`Unknown OTP rate-limit bucket: ${bucket}`);
  if (!phoneNo) return { allowed: true, remaining: cfg.limit };

  if (!redis.isRedisAvailable()) {
    logger.warn(`OTP rate limiter: Redis unavailable, allowing ${bucket} for ${phoneNo}`);
    return { allowed: true, remaining: cfg.limit };
  }

  const k = key(bucket, phoneNo);
  const count = await redis.incr(k);
  if (count === null) {
    return { allowed: true, remaining: cfg.limit };
  }
  if (count === 1) {
    await redis.expire(k, cfg.windowSec);
  }
  if (count > cfg.limit) {
    return { allowed: false, remaining: 0, retryAfterSec: cfg.windowSec };
  }
  return { allowed: true, remaining: cfg.limit - count };
}

module.exports = { checkAndConsume };
