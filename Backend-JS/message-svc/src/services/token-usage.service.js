const redis = require('../config/redis');
const logger = require('../utils/logger');
const { costFor } = require('../utils/cost-table');

const DAILY_COST_CAP_USD = parseFloat(process.env.AI_DAILY_COST_CAP_USD_PER_USER || '0.50');
const GLOBAL_MIN_CAP_USD = parseFloat(process.env.AI_GLOBAL_COST_CAP_USD_PER_MINUTE || '10');

function todayKey(userId) {
  const d = new Date().toISOString().slice(0, 10);
  return `ai:daily-cost:${userId}:${d}`;
}
function globalMinuteKey() {
  const now = new Date();
  const stamp = now.toISOString().slice(0, 16).replace(':', '-');
  return `ai:global-cost:${stamp}`;
}

/**
 * Record a completed turn. Returns the cumulative daily cost for the user.
 * Structure mirrors the plan doc 06 §11 observability event.
 */
async function recordTurn({ userId, chatId, model, provider = 'openai', usage, costUsd }) {
  const totalCost =
    typeof costUsd === 'number' ? costUsd : costFor(model, usage || {});

  logger.info('ai.turn', {
    event: 'ai.turn',
    userId: userId ? String(userId).slice(-8) : null,
    chatId: chatId ? String(chatId) : null,
    model,
    provider,
    tokens: {
      prompt: usage?.prompt_tokens ?? 0,
      cached: usage?.prompt_tokens_details?.cached_tokens ?? 0,
      completion: usage?.completion_tokens ?? 0,
    },
    costUsd: Number(totalCost.toFixed(6)),
  });

  try {
    const cents = Math.round((totalCost || 0) * 10_000);
    if (cents > 0 && userId) {
      const dayKey = todayKey(userId);
      const current = await redis.incrby?.(dayKey, cents);
      if (current == null && typeof redis.incr === 'function') {
        for (let i = 0; i < cents; i++) await redis.incr(dayKey);
      }
      if (typeof redis.expire === 'function') {
        await redis.expire(dayKey, 48 * 60 * 60);
      }
    }
    if (cents > 0) {
      const minKey = globalMinuteKey();
      if (typeof redis.incrby === 'function') await redis.incrby(minKey, cents);
      else if (typeof redis.incr === 'function') {
        for (let i = 0; i < cents; i++) await redis.incr(minKey);
      }
      if (typeof redis.expire === 'function') {
        await redis.expire(minKey, 5 * 60);
      }
    }
  } catch (err) {
    // accounting is best-effort; never block a turn
  }

  return totalCost;
}

async function dailyCostUsd(userId) {
  if (!userId) return 0;
  try {
    const raw = await redis.get(todayKey(userId));
    return (parseInt(raw || '0', 10) || 0) / 10_000;
  } catch (err) {
    return 0;
  }
}

async function overDailyCap(userId) {
  const cost = await dailyCostUsd(userId);
  return cost >= DAILY_COST_CAP_USD;
}

async function globalMinuteCostUsd() {
  try {
    const raw = await redis.get(globalMinuteKey());
    return (parseInt(raw || '0', 10) || 0) / 10_000;
  } catch (err) {
    return 0;
  }
}

async function overGlobalCap() {
  const cost = await globalMinuteCostUsd();
  return cost >= GLOBAL_MIN_CAP_USD;
}

function incrementChatUsage(chat, { model, usage, costUsd }) {
  if (!chat) return;
  chat.usage = chat.usage || {};
  chat.usage.totalPromptTokens = (chat.usage.totalPromptTokens || 0) + (usage?.prompt_tokens || 0);
  chat.usage.totalCachedTokens =
    (chat.usage.totalCachedTokens || 0) + (usage?.prompt_tokens_details?.cached_tokens || 0);
  chat.usage.totalCompletionTokens =
    (chat.usage.totalCompletionTokens || 0) + (usage?.completion_tokens || 0);
  chat.usage.estimatedUsdCost = (chat.usage.estimatedUsdCost || 0) + (costUsd || 0);
  if (model) {
    chat.usage.modelBreakdown = chat.usage.modelBreakdown || {};
    if (typeof chat.usage.modelBreakdown.set === 'function') {
      const cur = chat.usage.modelBreakdown.get(model) || 0;
      chat.usage.modelBreakdown.set(model, cur + (usage?.completion_tokens || 0));
    } else {
      chat.usage.modelBreakdown[model] =
        (chat.usage.modelBreakdown[model] || 0) + (usage?.completion_tokens || 0);
    }
  }
}

module.exports = {
  recordTurn,
  incrementChatUsage,
  dailyCostUsd,
  overDailyCap,
  globalMinuteCostUsd,
  overGlobalCap,
  DAILY_COST_CAP_USD,
  GLOBAL_MIN_CAP_USD,
};
