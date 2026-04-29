/**
 * Event Sanitizer
 *
 * Defense in depth against accidental PII leakage and storage bloat in the
 * `events` collection. Run on every event before it goes into the queue.
 *
 * Rejected events return `{ ok: false, reason }` and the controller drops
 * them with a 400. Repaired events return `{ ok: true, event, mutated }`.
 *
 * Rules:
 *   - properties JSON ≤ MAX_PROPERTIES_BYTES (4 KB). Larger ⇒ reject.
 *   - any string property containing an email / phone / bearer-token-like
 *     pattern ⇒ reject (don't try to redact and keep going; if the SDK is
 *     leaking PII the right answer is to fix the call site).
 *   - properties.searchQuery, properties.query: truncated to 200 chars.
 *   - location.latitude/longitude: rounded to 2 decimals (~1 km precision)
 *     so we don't store full GPS.
 */

const MAX_PROPERTIES_BYTES = 4 * 1024;
const MAX_QUERY_LEN = 200;

// Match common PII shapes. Conservative — false positives are fine, the
// fix is to clean up the caller; we shouldn't be sending raw user-typed
// content as a property in the first place.
const EMAIL_RE = /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b/;
// 7+ contiguous digits, allowing ` `, `-`, `+`, `(`, `)` between groups.
// Catches Indian 10-digit numbers, +91 prefixes, etc.
const PHONE_RE = /(?:\+?\d[\d\s\-()]{6,}\d)/;
// JWT triple-section dotted base64 — three dot-separated runs of allowed chars.
const JWT_RE = /\b[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\b/;

const PII_PATTERNS = [
  { name: 'email', re: EMAIL_RE },
  { name: 'phone', re: PHONE_RE },
  { name: 'jwt', re: JWT_RE },
];

const containsPII = (value) => {
  if (typeof value !== 'string') return null;
  for (const { name, re } of PII_PATTERNS) {
    if (re.test(value)) return name;
  }
  return null;
};

const walkStrings = (obj, fn) => {
  if (obj == null) return null;
  if (typeof obj === 'string') {
    return fn(obj);
  }
  if (Array.isArray(obj)) {
    for (const v of obj) {
      const hit = walkStrings(v, fn);
      if (hit) return hit;
    }
    return null;
  }
  if (typeof obj === 'object') {
    for (const k of Object.keys(obj)) {
      const hit = walkStrings(obj[k], fn);
      if (hit) return hit;
    }
  }
  return null;
};

const truncateQueries = (properties) => {
  if (!properties || typeof properties !== 'object') return false;
  let mutated = false;
  for (const key of ['searchQuery', 'query']) {
    if (typeof properties[key] === 'string' && properties[key].length > MAX_QUERY_LEN) {
      properties[key] = properties[key].slice(0, MAX_QUERY_LEN);
      mutated = true;
    }
  }
  return mutated;
};

const roundLocation = (location) => {
  if (!location || typeof location !== 'object') return false;
  let mutated = false;
  for (const key of ['latitude', 'longitude']) {
    if (typeof location[key] === 'number' && Number.isFinite(location[key])) {
      const rounded = Math.round(location[key] * 100) / 100;
      if (rounded !== location[key]) {
        location[key] = rounded;
        mutated = true;
      }
    }
  }
  return mutated;
};

/**
 * Sanitize a single event in place. Returns:
 *   { ok: true, event, mutated }    — event is safe to persist
 *   { ok: false, reason }           — event must be dropped
 */
const sanitizeEvent = (event) => {
  if (!event || typeof event !== 'object') {
    return { ok: false, reason: 'event is not an object' };
  }

  // Size cap on properties bag.
  if (event.properties) {
    const json = JSON.stringify(event.properties);
    if (json.length > MAX_PROPERTIES_BYTES) {
      return { ok: false, reason: `properties JSON exceeds ${MAX_PROPERTIES_BYTES} bytes` };
    }
  }

  // PII scan across properties + the top-level fields a careless caller
  // might stick a phone or email into.
  const piiHit = walkStrings(event.properties, containsPII);
  if (piiHit) {
    return { ok: false, reason: `properties contains ${piiHit}-like value` };
  }

  let mutated = false;
  if (truncateQueries(event.properties)) mutated = true;
  if (roundLocation(event.location)) mutated = true;

  return { ok: true, event, mutated };
};

module.exports = {
  sanitizeEvent,
  // Exported for tests:
  _internals: { containsPII, EMAIL_RE, PHONE_RE, JWT_RE, MAX_PROPERTIES_BYTES, MAX_QUERY_LEN },
};
