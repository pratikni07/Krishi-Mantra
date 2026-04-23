// Strip MongoDB operator-injection keys from untrusted input.
//
// `?q[$ne]=null` or `{"email": {"$ne": null}}` parse into an Express
// object whose *keys* are `$ne` / `$gt` / etc. Mongoose happily treats
// these as operators and turns authentication checks into tautologies.
//
// We walk body/query/params recursively and delete any key starting
// with `$` or containing `.`. Deletion (vs. escape) is the safer default:
// we never legitimately accept operator keys from clients, so dropping
// them is always correct.
//
// Mounted at the gateway (defense-in-depth before proxy) and reused
// inside each downstream service so direct-to-pod access is also covered.

const FORBIDDEN_KEY_PATTERN = /^\$|\./;

function sanitize(value, depth = 0) {
  if (depth > 16) return value;
  if (value === null || typeof value !== 'object') return value;
  if (Array.isArray(value)) {
    for (let i = 0; i < value.length; i++) value[i] = sanitize(value[i], depth + 1);
    return value;
  }
  for (const key of Object.keys(value)) {
    if (FORBIDDEN_KEY_PATTERN.test(key)) {
      delete value[key];
      continue;
    }
    value[key] = sanitize(value[key], depth + 1);
  }
  return value;
}

module.exports = function mongoSanitize(req, _res, next) {
  if (req.body && typeof req.body === 'object') sanitize(req.body);
  if (req.params && typeof req.params === 'object') sanitize(req.params);
  // req.query in Express 4 is a plain object — safe to mutate in place.
  if (req.query && typeof req.query === 'object') sanitize(req.query);
  next();
};
