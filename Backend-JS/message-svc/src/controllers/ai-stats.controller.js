const asyncHandler = require('../utils/asyncHandler');
const AIChat = require('../models/ai-chat.model');
const TokenUsage = require('../services/token-usage.service');
const { active: activeProvider } = require('../ai-providers/factory');
const logger = require('../utils/logger');

/**
 * Aggregated usage + cost stats for the admin panel. Pulls from AIChat
 * documents (the authoritative cost source) and also exposes the current
 * global-minute-cost gauge for ops dashboards.
 */
exports.summary = asyncHandler(async (req, res) => {
  const since = req.query.since
    ? new Date(req.query.since)
    : new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);

  let totalChats;
  let totalTurns;
  let breakdown;
  try {
    totalChats = await AIChat.countDocuments({ updatedAt: { $gte: since } });
    const agg = await AIChat.aggregate([
      { $match: { updatedAt: { $gte: since } } },
      {
        $group: {
          _id: null,
          totalPromptTokens: { $sum: '$usage.totalPromptTokens' },
          totalCachedTokens: { $sum: '$usage.totalCachedTokens' },
          totalCompletionTokens: { $sum: '$usage.totalCompletionTokens' },
          estimatedUsdCost: { $sum: '$usage.estimatedUsdCost' },
          totalMessages: { $sum: { $size: { $ifNull: ['$messages', []] } } },
        },
      },
    ]);
    breakdown = agg[0] || {
      totalPromptTokens: 0,
      totalCachedTokens: 0,
      totalCompletionTokens: 0,
      estimatedUsdCost: 0,
      totalMessages: 0,
    };
    totalTurns = Math.floor((breakdown.totalMessages || 0) / 2);
  } catch (err) {
    logger.warn('ai-stats aggregation failed', { error: err.message });
    breakdown = {
      totalPromptTokens: 0,
      totalCachedTokens: 0,
      totalCompletionTokens: 0,
      estimatedUsdCost: 0,
    };
    totalChats = 0;
    totalTurns = 0;
  }

  let activeProviderName = null;
  let activeModel = null;
  try {
    const inst = await activeProvider();
    activeProviderName = inst.provider;
  } catch (err) {
    activeProviderName = null;
  }

  const cacheHitRate = breakdown.totalPromptTokens > 0
    ? (breakdown.totalCachedTokens || 0) / breakdown.totalPromptTokens
    : 0;

  const globalMinuteCostUsd = await TokenUsage.globalMinuteCostUsd();

  return res.status(200).json({
    success: true,
    since: since.toISOString(),
    activeProvider: activeProviderName,
    activeModel,
    chats: totalChats,
    turns: totalTurns,
    tokens: {
      prompt: breakdown.totalPromptTokens,
      cached: breakdown.totalCachedTokens,
      completion: breakdown.totalCompletionTokens,
    },
    cacheHitRate: Number(cacheHitRate.toFixed(4)),
    estimatedUsdCost: Number((breakdown.estimatedUsdCost || 0).toFixed(4)),
    globalMinuteCostUsd: Number(globalMinuteCostUsd.toFixed(4)),
  });
});

exports.modelBreakdown = asyncHandler(async (req, res) => {
  const since = req.query.since
    ? new Date(req.query.since)
    : new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);

  try {
    const result = await AIChat.aggregate([
      { $match: { updatedAt: { $gte: since } } },
      { $unwind: '$messages' },
      { $match: { 'messages.role': 'assistant', 'messages.model': { $exists: true } } },
      {
        $group: {
          _id: { model: '$messages.model', provider: '$messages.provider' },
          turns: { $sum: 1 },
          promptTokens: { $sum: '$messages.tokenUsage.prompt' },
          cachedTokens: { $sum: '$messages.tokenUsage.cached' },
          completionTokens: { $sum: '$messages.tokenUsage.completion' },
          costUsd: { $sum: '$messages.tokenUsage.costUsd' },
        },
      },
      { $sort: { turns: -1 } },
    ]);
    return res.status(200).json({
      success: true,
      since: since.toISOString(),
      breakdown: result.map((r) => ({
        model: r._id.model,
        provider: r._id.provider || 'unknown',
        turns: r.turns,
        promptTokens: r.promptTokens || 0,
        cachedTokens: r.cachedTokens || 0,
        completionTokens: r.completionTokens || 0,
        costUsd: Number((r.costUsd || 0).toFixed(4)),
      })),
    });
  } catch (err) {
    logger.warn('model breakdown failed', { error: err.message });
    return res.status(200).json({ success: true, breakdown: [] });
  }
});
