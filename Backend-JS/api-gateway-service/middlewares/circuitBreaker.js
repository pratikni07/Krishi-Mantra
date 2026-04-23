// Per-service circuit breaker for the gateway. Tracks consecutive proxy
// failures; once a threshold is crossed, short-circuits to 503 for a cooldown
// instead of hammering a downstream that's already failing. After the cooldown
// we let a single probe through ("half-open") — if it succeeds we close the
// breaker, if it fails we extend the cooldown.
//
// Intentionally a tiny in-process state machine, not a library. Good enough
// for a single-replica gateway; if the gateway is scaled out each replica
// will independently learn that a downstream is unhealthy.

const STATE = { CLOSED: 'closed', OPEN: 'open', HALF_OPEN: 'half_open' };

const DEFAULT_OPTS = {
  failureThreshold: 5,   // consecutive failures to open the breaker
  cooldownMs: 15000,     // how long to stay open before trying a probe
  halfOpenMax: 1,        // concurrent probes allowed when half-open
};

function createBreaker(serviceName, opts = {}) {
  const o = { ...DEFAULT_OPTS, ...opts };
  const state = {
    status: STATE.CLOSED,
    failures: 0,
    openedAt: 0,
    halfOpenInFlight: 0,
  };

  const maybeHalfOpen = () => {
    if (state.status === STATE.OPEN && Date.now() - state.openedAt >= o.cooldownMs) {
      state.status = STATE.HALF_OPEN;
      state.halfOpenInFlight = 0;
    }
  };

  return {
    name: serviceName,

    // Express middleware: reject fast if the breaker is open.
    middleware: (req, res, next) => {
      maybeHalfOpen();
      if (state.status === STATE.OPEN) {
        return res.status(503).json({
          status: 'error',
          message: `${serviceName} temporarily unavailable (circuit open)`,
          retryAfterMs: o.cooldownMs - (Date.now() - state.openedAt),
        });
      }
      if (state.status === STATE.HALF_OPEN) {
        if (state.halfOpenInFlight >= o.halfOpenMax) {
          return res.status(503).json({
            status: 'error',
            message: `${serviceName} health probe in progress`,
          });
        }
        state.halfOpenInFlight++;
      }
      next();
    },

    recordSuccess: () => {
      if (state.status === STATE.HALF_OPEN) {
        state.halfOpenInFlight = Math.max(0, state.halfOpenInFlight - 1);
      }
      state.failures = 0;
      state.status = STATE.CLOSED;
    },

    recordFailure: () => {
      if (state.status === STATE.HALF_OPEN) {
        state.halfOpenInFlight = Math.max(0, state.halfOpenInFlight - 1);
        state.status = STATE.OPEN;
        state.openedAt = Date.now();
        return;
      }
      state.failures++;
      if (state.failures >= o.failureThreshold) {
        state.status = STATE.OPEN;
        state.openedAt = Date.now();
      }
    },

    getState: () => ({ ...state }),
  };
}

module.exports = { createBreaker, STATE };
