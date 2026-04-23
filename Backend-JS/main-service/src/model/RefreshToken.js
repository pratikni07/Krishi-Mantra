const mongoose = require('mongoose');
const crypto = require('crypto');

/**
 * RefreshToken stores a hash of each refresh JWT so the server can
 * revoke/rotate them. We never store the raw token.
 *
 *   - revokedAt: non-null once the token has been used or invalidated.
 *   - replacedBy: tokenId of the successor issued on rotation, letting
 *     us detect reuse (an old token being presented AFTER it was already
 *     rotated = theft signal → revoke the whole family).
 */
const refreshTokenSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    tokenHash: { type: String, required: true, unique: true, index: true },
    expiresAt: { type: Date, required: true, index: true },
    revokedAt: { type: Date, default: null },
    replacedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'RefreshToken',
      default: null,
    },
    userAgent: { type: String },
    ip: { type: String },
  },
  { timestamps: true }
);

// Let MongoDB clean up expired tokens automatically.
refreshTokenSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });

refreshTokenSchema.statics.hashToken = function (raw) {
  return crypto.createHash('sha256').update(raw).digest('hex');
};

module.exports = mongoose.model('RefreshToken', refreshTokenSchema);
