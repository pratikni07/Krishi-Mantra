const { asyncHandler } = require('../utils');

/**
 * Read-only feature-flag endpoint. Backed by env vars today; can swap in a
 * Mongo-backed config later without changing the mobile contract.
 *
 * Boolean envs: TRUE / 1 / "yes" → true, anything else → default.
 * Cohort envs (future): "<percent>" → bucket by user-id hash.
 */

function bool(env, def = false) {
  const v = process.env[env];
  if (v == null) return def;
  return /^(1|true|yes|on)$/i.test(String(v).trim());
}

exports.list = asyncHandler(async (req, res) => {
  const userId = req.user?.id || req.user?._id || null;
  res.set('Cache-Control', 'private, max-age=60');
  return res.json({
    success: true,
    flags: {
      NEW_AI_ENABLED: bool('FF_NEW_AI_ENABLED', false),
      ONBOARDING_V2_ENABLED: bool('FF_ONBOARDING_V2_ENABLED', true),
      AI_STREAMING_ENABLED: bool('FF_AI_STREAMING_ENABLED', true),
      EDIT_FARM_ENABLED: bool('FF_EDIT_FARM_ENABLED', true),
      WEATHER_VIA_BACKEND: bool('FF_WEATHER_VIA_BACKEND', true),
      VOICE_CHAT_ENABLED: bool('FF_VOICE_CHAT_ENABLED', false),
    },
    refreshedAt: new Date().toISOString(),
    userId,
  });
});
