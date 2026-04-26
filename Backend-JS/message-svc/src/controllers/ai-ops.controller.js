const asyncHandler = require('../utils/asyncHandler');
const redis = require('../config/redis');
const factory = require('../ai-providers/factory');
const AiConfig = require('../services/ai-config.service');
const AIShadowLog = require('../models/ai-shadow-log.model');
const logger = require('../utils/logger');

let SttFactory = null;
let TtsFactory = null;
try { SttFactory = require('../voice/stt.factory'); } catch (_) {}
try { TtsFactory = require('../voice/tts.factory'); } catch (_) {}

const KILLSWITCH_KEYS = {
  global: 'ai:killswitch:global',
  openai: 'ai:killswitch:openai',
  vertex: 'ai:killswitch:vertex',
  voice: 'ai:killswitch:voice',         // disables voice end-to-end
  voice_stt: 'voice:killswitch:stt',    // disables STT — voice button hides
  voice_tts: 'voice:killswitch:tts',    // disables TTS — voice degrades to text-only
};

function targetKey(target) {
  return KILLSWITCH_KEYS[target] || null;
}

exports.killswitchStatus = asyncHandler(async (req, res) => {
  const out = {};
  for (const [name, key] of Object.entries(KILLSWITCH_KEYS)) {
    out[name] = (await redis.get(key)) === '1';
  }
  return res.status(200).json({ success: true, killswitches: out });
});

exports.setKillswitch = asyncHandler(async (req, res) => {
  const { target } = req.params;
  const { engaged, reason } = req.body || {};
  const key = targetKey(target);
  if (!key) {
    return res
      .status(400)
      .json({ success: false, message: `unknown target: ${target}` });
  }
  if (engaged) {
    await redis.set(key, '1');
    logger.warn('killswitch engaged', { target, actor: req.user?._id, reason });
  } else {
    await redis.del(key);
    logger.info('killswitch released', { target, actor: req.user?._id, reason });
  }
  factory.resetCache();
  await AiConfig.invalidate();
  // Voice factories also cache provider instances — reset when those switches flip.
  if (target === 'voice' || target === 'voice_stt') SttFactory?.resetCache?.();
  if (target === 'voice' || target === 'voice_tts') TtsFactory?.resetCache?.();
  return res.status(200).json({
    success: true,
    target,
    engaged: !!engaged,
  });
});

exports.shadowLogs = asyncHandler(async (req, res) => {
  const limit = Math.min(parseInt(req.query.limit, 10) || 50, 200);
  const since = req.query.since
    ? new Date(req.query.since)
    : new Date(Date.now() - 24 * 60 * 60 * 1000);
  const entries = await AIShadowLog.find({ createdAt: { $gte: since } })
    .sort({ createdAt: -1 })
    .limit(limit)
    .lean();
  return res.status(200).json({ success: true, entries });
});

exports.shadowSummary = asyncHandler(async (req, res) => {
  const since = req.query.since
    ? new Date(req.query.since)
    : new Date(Date.now() - 24 * 60 * 60 * 1000);
  try {
    const summary = await AIShadowLog.aggregate([
      { $match: { createdAt: { $gte: since } } },
      {
        $group: {
          _id: { primary: '$primary.provider', shadow: '$shadow.provider' },
          turns: { $sum: 1 },
          avgSimilarity: { $avg: '$diff.sampleSimilarity' },
          avgLatencyDeltaMs: { $avg: '$diff.latencyDeltaMs' },
          totalCostDeltaUsd: { $sum: '$diff.costDeltaUsd' },
          primaryErrors: {
            $sum: { $cond: [{ $ne: ['$primary.error', null] }, 1, 0] },
          },
          shadowErrors: {
            $sum: { $cond: [{ $ne: ['$shadow.error', null] }, 1, 0] },
          },
        },
      },
    ]);
    return res.status(200).json({
      success: true,
      since: since.toISOString(),
      summary: summary.map((row) => ({
        primary: row._id.primary,
        shadow: row._id.shadow,
        turns: row.turns,
        avgSimilarity: row.avgSimilarity,
        avgLatencyDeltaMs: row.avgLatencyDeltaMs,
        totalCostDeltaUsd: row.totalCostDeltaUsd,
        primaryErrorRate: row.turns > 0 ? row.primaryErrors / row.turns : 0,
        shadowErrorRate: row.turns > 0 ? row.shadowErrors / row.turns : 0,
      })),
    });
  } catch (err) {
    logger.warn('shadow summary failed', { error: err.message });
    return res.status(200).json({ success: true, summary: [] });
  }
});
