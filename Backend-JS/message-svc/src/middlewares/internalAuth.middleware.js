const crypto = require('crypto');

/**
 * HMAC-SHA256 internal auth for service-to-service calls.
 *
 * The caller signs `${timestamp}.${rawBody}` with the shared secret and sends
 * `X-Internal-Auth: <hex>` and `X-Internal-Timestamp: <unix-seconds>` headers.
 *
 * We verify in constant-time and reject requests older than 5 minutes to
 * cap replay-window risk.
 */

const SKEW_SECONDS = 5 * 60;

function readSecret() {
  return (
    process.env.AI_INTERNAL_SHARED_SECRET ||
    process.env.ACTION_CARD_INTERNAL_SHARED_SECRET ||
    null
  );
}

function safeEqualHex(a, b) {
  if (typeof a !== 'string' || typeof b !== 'string') return false;
  if (a.length !== b.length) return false;
  try {
    return crypto.timingSafeEqual(Buffer.from(a, 'hex'), Buffer.from(b, 'hex'));
  } catch (err) {
    return false;
  }
}

module.exports = function internalAuth(req, res, next) {
  const secret = readSecret();
  if (!secret) {
    return res.status(503).json({ error: 'internal_auth_not_configured' });
  }

  const sig = req.header('X-Internal-Auth');
  const ts = req.header('X-Internal-Timestamp');
  if (!sig || !ts) {
    return res.status(401).json({ error: 'missing_internal_auth_headers' });
  }

  const tsNum = Number(ts);
  if (!Number.isFinite(tsNum)) {
    return res.status(401).json({ error: 'bad_timestamp' });
  }
  const drift = Math.abs(Math.floor(Date.now() / 1000) - tsNum);
  if (drift > SKEW_SECONDS) {
    return res.status(401).json({ error: 'stale_request' });
  }

  // Body must be the JSON serialization the caller signed. We re-stringify
  // req.body deterministically; callers MUST also stringify deterministically.
  // Standard Express JSON parser preserves key order, so as long as the
  // caller serialized once and didn't reorder, this works.
  const rawBody =
    req.rawBody != null ? req.rawBody : JSON.stringify(req.body || {});
  const expected = crypto
    .createHmac('sha256', secret)
    .update(`${ts}.${rawBody}`)
    .digest('hex');

  if (!safeEqualHex(sig, expected)) {
    return res.status(401).json({ error: 'bad_signature' });
  }

  // Tag the actor for downstream observability + cost ledgering.
  req.internal = { caller: req.header('X-Internal-Caller') || 'unknown' };
  next();
};

module.exports.signRequest = function signRequest(secret, body) {
  const ts = Math.floor(Date.now() / 1000).toString();
  const raw = typeof body === 'string' ? body : JSON.stringify(body || {});
  const sig = crypto.createHmac('sha256', secret).update(`${ts}.${raw}`).digest('hex');
  return { 'X-Internal-Auth': sig, 'X-Internal-Timestamp': ts };
};
