// Strip MongoDB operator-injection keys from untrusted input.
//
// Defense-in-depth copy of the gateway-level filter: services can be
// reached directly inside the cluster (service-to-service traffic,
// port-forward during incident response, misrouted ingress), so every
// Express app that touches user input runs its own copy.
//
// Keys starting with `$` or containing `.` are dropped outright — we
// never accept operator keys from clients.

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
  if (req.query && typeof req.query === 'object') sanitize(req.query);
  next();
};
