/**
 * Shared AI orchestration extracted from ai-v2.controller. The text-chat
 * controller and the voice-turn service both go through this module so the
 * context tree + provider routing + journal/usage hooks stay in one place.
 *
 * Public surface:
 *   prepareTurn({ chat, userText, preferredLanguage, userId, provider? })
 *     → { provider, model, routing, assembled, fitted, prefixCtx }
 *
 *   streamFromProvider({ provider, fitted, prefixCtx, model, userId, abortSignal? })
 *     → AsyncIterable<{ type:"delta"|"done"|"error", ... }>
 *
 *   completeFromProvider({ provider, fitted, prefixCtx, model, userId })
 *     → { text, usage, costUsd, model, provider }
 *
 *   recordAssistantTurn(chat, opts)            // pushes both turns + usage
 *   maybeFireSummarizer(chat)                  // background trigger
 *   persistChat(chat)                          // chat.save() + write-through cache hooks
 */

const FarmProfileClient = require('./farm-profile.client');
const IntentRouter = require('./intent-router.service');
const ContextTree = require('./context-tree.service');
const TokenBudget = require('./token-budget.service');
const TokenUsage = require('./token-usage.service');
const ChatSummarizer = require('./chat-summarizer.service');
const { active: activeProvider } = require('../ai-providers/factory');
const { costFor } = require('../utils/cost-table');

let logger;
try {
  logger = require('../utils/logger');
} catch (err) {
  logger = { info: () => {}, warn: () => {}, error: () => {}, debug: () => {} };
}

async function prepareTurn({
  chat,
  userText,
  preferredLanguage,
  userId,
  provider: existingProvider,
} = {}) {
  if (!chat) throw new Error('orchestrator.prepareTurn: chat required');
  if (!userText) throw new Error('orchestrator.prepareTurn: userText required');

  const provider = existingProvider || (await activeProvider());
  const profile = await FarmProfileClient.get(userId).catch(() => null);
  const lang =
    preferredLanguage ||
    profile?.preferredLanguage ||
    chat.metadata?.preferredLanguage ||
    'en';

  const routing = await IntentRouter.classify(userText, {
    profileCrops: profile?.crops || [],
    provider,
  });

  const assembled = await ContextTree.assemble({
    chat,
    profile,
    userId,
    message: userText,
    routing,
    preferredLanguage: lang,
  });
  const fitted = TokenBudget.fit(assembled);
  const prefixCtx = {
    fingerprint: assembled.prefixFingerprint,
    prefixTokens: assembled.totalSystemTokens,
  };

  if (profile?._id && !chat.farmProfileRef?.profileId) {
    chat.farmProfileRef = {
      profileId: profile._id,
      profileVersionAtCreation: profile.profileVersion || 1,
    };
  }

  return {
    provider,
    profile,
    lang,
    routing,
    assembled,
    fitted,
    prefixCtx,
    model: fitted.budgetEscalation ? 'gpt-4.1' : fitted.model,
  };
}

function streamFromProvider({ provider, fitted, prefixCtx, model, userId, abortSignal, temperature = 0.4 }) {
  return provider.streamChat({
    messages: fitted.messages,
    model,
    userId: String(userId),
    maxTokens: fitted.maxOutputTokens,
    temperature,
    fingerprint: prefixCtx?.fingerprint,
    prefixTokens: prefixCtx?.prefixTokens,
    abortSignal,
  });
}

async function completeFromProvider({ provider, fitted, prefixCtx, model, userId, temperature = 0.4 }) {
  const result = await provider.chat({
    messages: fitted.messages,
    model,
    userId: String(userId),
    maxTokens: fitted.maxOutputTokens,
    temperature,
    fingerprint: prefixCtx?.fingerprint,
    prefixTokens: prefixCtx?.prefixTokens,
  });
  const cost = costFor(model, result.usage || {});
  return {
    text: result.text || '',
    usage: result.usage || {},
    costUsd: cost,
    model,
    provider: provider.provider,
  };
}

/**
 * Append both turns to the chat doc with usage + voice metadata. Does not
 * persist — caller decides when to chat.save() so it can collapse mutations.
 *
 * `voiceUser` and `voiceAssistant` are optional `voice {...}` blocks for the
 * user/assistant message respectively (transcript on user; cache key on
 * assistant). When passed, the per-message subdoc gets the voice block and
 * the chat-level voice ledger is incremented.
 */
function recordAssistantTurn(chat, {
  userMessage,
  assistantText,
  model,
  provider,
  usage,
  costUsd,
  layers,
  imageUrls,
  voiceUser,
  voiceAssistant,
} = {}) {
  if (!chat) return;
  chat.messages.push({
    role: 'user',
    content: userMessage,
    timestamp: new Date(),
    ...(imageUrls?.length ? { imageUrl: imageUrls[0] } : {}),
    ...(voiceUser ? { voice: voiceUser } : {}),
  });
  chat.messages.push({
    role: 'assistant',
    content: assistantText,
    model,
    provider: provider || 'openai',
    tokenUsage: {
      prompt: usage?.prompt_tokens || 0,
      cached: usage?.prompt_tokens_details?.cached_tokens || 0,
      completion: usage?.completion_tokens || 0,
      costUsd: costUsd || 0,
    },
    timestamp: new Date(),
    ...(voiceAssistant ? { voice: voiceAssistant } : {}),
  });
  TokenUsage.incrementChatUsage(chat, { model, usage, costUsd });

  if (voiceUser || voiceAssistant) {
    chat.voice = chat.voice || { turns: 0, sttCostUsd: 0, ttsCostUsd: 0, totalAudioSec: 0 };
    chat.voice.turns += 1;
    if (voiceUser?.sttCostUsd) chat.voice.sttCostUsd += voiceUser.sttCostUsd;
    if (voiceAssistant?.ttsCostUsd) chat.voice.ttsCostUsd += voiceAssistant.ttsCostUsd;
    if (voiceAssistant?.durationSec) chat.voice.totalAudioSec += voiceAssistant.durationSec;
  }
  if (layers && layers.length) {
    chat.contextFingerprint = layers.map((l) => `${l.name}:${(l.fp || '').slice(0, 8)}`).join(',');
  }
}

function maybeFireSummarizer(chat) {
  if (!chat?._id) return;
  try {
    ChatSummarizer.maybeTrigger(chat._id);
  } catch (err) {
    logger.warn?.('orchestrator.summarizer_trigger_failed', { error: err.message });
  }
}

async function persistChat(chat) {
  if (!chat?.save) return;
  await chat.save();
}

module.exports = {
  prepareTurn,
  streamFromProvider,
  completeFromProvider,
  recordAssistantTurn,
  maybeFireSummarizer,
  persistChat,
};
