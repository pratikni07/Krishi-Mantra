/**
 * In-memory token-bucket rate limiter — keeps our outbound calls to Google
 * STT/TTS under their RPM ceiling, fail-fast when bursting beyond the
 * configured rate. Per-process; if you scale to N pods, set the limits to
 * (provider_quota / N) per the deployment story.
 *
 * Calling code:
 *   await sttBucket.acquire();   // returns when a token is free, or throws
 *
 * Defaults sized for India-region Google Speech V2 (~900 RPM) and TTS
 * (~1000 RPM); we cap ourselves below those to leave headroom.
 */

class TokenBucket {
  constructor({ capacity, refillPerSec, label }) {
    this.capacity = capacity;
    this.tokens = capacity;
    this.refillPerSec = refillPerSec;
    this.lastRefill = Date.now();
    this.label = label || 'bucket';
  }

  _refill() {
    const now = Date.now();
    const elapsed = (now - this.lastRefill) / 1000;
    if (elapsed <= 0) return;
    this.tokens = Math.min(
      this.capacity,
      this.tokens + elapsed * this.refillPerSec
    );
    this.lastRefill = now;
  }

  /**
   * Try once for a token. Returns true on success, false if the bucket is
   * dry. The caller decides whether to wait and retry, or fail fast.
   */
  tryAcquire() {
    this._refill();
    if (this.tokens >= 1) {
      this.tokens -= 1;
      return true;
    }
    return false;
  }

  /**
   * Wait up to maxWaitMs for a token. Throws PROVIDER_THROTTLED if the bucket
   * stays dry — calling code should propagate the error to the user.
   */
  async acquire({ maxWaitMs = 200 } = {}) {
    if (this.tryAcquire()) return true;
    const deadline = Date.now() + maxWaitMs;
    while (Date.now() < deadline) {
      await new Promise((r) => setTimeout(r, 25));
      if (this.tryAcquire()) return true;
    }
    const err = new Error(`provider_throttled: ${this.label}`);
    err.code = 'PROVIDER_THROTTLED';
    err.label = this.label;
    throw err;
  }
}

const sttBucket = new TokenBucket({
  capacity: parseInt(process.env.VOICE_STT_RPM_BUCKET || '600', 10),
  refillPerSec: parseFloat(process.env.VOICE_STT_REFILL_PER_SEC || '10'),
  label: 'stt',
});

const ttsBucket = new TokenBucket({
  capacity: parseInt(process.env.VOICE_TTS_RPM_BUCKET || '800', 10),
  refillPerSec: parseFloat(process.env.VOICE_TTS_REFILL_PER_SEC || '13'),
  label: 'tts',
});

module.exports = { TokenBucket, sttBucket, ttsBucket };
