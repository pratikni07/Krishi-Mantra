const mongoose = require('mongoose');

/**
 * Append-only audit trail for authentication-relevant events.
 *
 * Goal: forensics + abuse detection. When a phone is brute-forced, an OTP
 * is reused after consumption, or a user's tokens are rotating in suspicious
 * patterns, the trail here is what an oncall engineer reads first.
 *
 * Indexed on (phoneNo, createdAt) for "show me everything that happened to
 * this number recently" queries, and on (userId, createdAt) for the
 * authenticated-user equivalent.
 *
 * Retention is intentionally controlled by ops (TTL configured via env)
 * rather than baked in here, so privacy / compliance windows can shift
 * without a code change.
 */
const authAuditLogSchema = new mongoose.Schema(
  {
    event: {
      type: String,
      required: true,
      enum: [
        'auth.otp.requested',
        'auth.otp.rate_limited',
        'auth.otp.verify.success',
        'auth.otp.verify.failed',
        'auth.signup.success',
        'auth.signup.failed',
        'auth.login.success',
        'auth.login.failed',
        'auth.logout',
        'auth.token.refresh',
        'auth.token.refresh.failed',
        'auth.password.changed',
      ],
      index: true,
    },
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      index: true,
    },
    phoneNo: { type: String, index: true },
    success: { type: Boolean, default: true, index: true },
    reason: { type: String },
    ipAddress: { type: String },
    userAgent: { type: String },
    metadata: { type: mongoose.Schema.Types.Mixed },
  },
  { timestamps: true }
);

authAuditLogSchema.index({ phoneNo: 1, createdAt: -1 });
authAuditLogSchema.index({ userId: 1, createdAt: -1 });

const AuthAuditLog = mongoose.model('AuthAuditLog', authAuditLogSchema);

/**
 * Best-effort fire-and-forget logger. Never throws — auth flows must not
 * fail because the audit collection is misbehaving. The returned Promise
 * is caught here so callers can `void recordAuthEvent(...)` and move on.
 */
function recordAuthEvent(event, fields = {}) {
  const { req, ...rest } = fields;
  const payload = { event, ...rest };
  if (req) {
    payload.ipAddress = payload.ipAddress || req.ip;
    payload.userAgent = payload.userAgent || req.get('user-agent');
  }
  AuthAuditLog.create(payload).catch((err) => {
    // Silent — log to stderr only. The auth flow itself is the source of truth.
    // eslint-disable-next-line no-console
    console.error('[AuthAuditLog] failed to record', event, err.message);
  });
}

module.exports = { AuthAuditLog, recordAuthEvent };
