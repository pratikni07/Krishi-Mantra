const AIChat = require('../models/ai-chat.model');
const redis = require('../config/redis');
const logger = require('../utils/logger');
const { active: activeProvider } = require('../ai-providers/factory');

const TURNS_SINCE_LAST_SUMMARY_TRIGGER = 12;
const KEEP_RAW_TAIL = 6;
const MAX_SUMMARY_TOKENS = 200;
const SUMMARIZER_TEMPERATURE = 0.2;

const SUMMARY_PROMPT =
  'Summarize this farmer-AI conversation for future reference in ≤120 words. Capture:\n' +
  '- crop/location/season context mentioned\n' +
  '- symptoms/issues raised\n' +
  '- recommendations given\n' +
  '- any outstanding questions\n' +
  '(no preamble; write as compact bullet list)';

function approxTokens(text) {
  return text ? Math.ceil(String(text).length / 4) : 0;
}

function messagesSinceSummary(chat) {
  const summarizedUpTo = chat?.summary?.summarizedUpTo || 0;
  const total = Array.isArray(chat?.messages) ? chat.messages.length : 0;
  return Math.max(0, total - summarizedUpTo);
}

function shouldRun(chat) {
  return messagesSinceSummary(chat) >= TURNS_SINCE_LAST_SUMMARY_TRIGGER;
}

async function summarize(chat, { provider } = {}) {
  if (!chat) return null;
  const summarizedUpTo = chat.summary?.summarizedUpTo || 0;
  const end = Math.max(summarizedUpTo, chat.messages.length - KEEP_RAW_TAIL);
  const slice = chat.messages.slice(summarizedUpTo, end);
  if (slice.length === 0) return null;

  const convo = slice
    .map((m) => `${m.role === 'user' ? 'User' : 'AI'}: ${String(m.content || '').trim()}`)
    .join('\n');

  const p = provider || (await activeProvider());

  let summaryText;
  try {
    const { text } = await p.chat({
      messages: [
        { role: 'system', content: SUMMARY_PROMPT },
        { role: 'user', content: convo },
      ],
      maxTokens: MAX_SUMMARY_TOKENS,
      temperature: SUMMARIZER_TEMPERATURE,
    });
    summaryText = String(text || '').trim();
  } catch (err) {
    logger.warn('chat-summarizer provider call failed', { error: err.message, chatId: String(chat._id) });
    return null;
  }

  if (chat.summary?.text) {
    summaryText = `${chat.summary.text.trim()}\n${summaryText}`;
    if (approxTokens(summaryText) > MAX_SUMMARY_TOKENS) {
      try {
        const { text } = await p.chat({
          messages: [
            { role: 'system', content: SUMMARY_PROMPT + '\n(merge two summaries; stay ≤120 words)' },
            { role: 'user', content: summaryText },
          ],
          maxTokens: MAX_SUMMARY_TOKENS,
          temperature: SUMMARIZER_TEMPERATURE,
        });
        summaryText = String(text || '').trim();
      } catch (err) {
        logger.warn('chat-summarizer recondense failed', { error: err.message });
      }
    }
  }

  chat.summary = {
    text: summaryText,
    summarizedUpTo: end,
    summaryTokens: approxTokens(summaryText),
  };
  await chat.save();

  // Invalidate summary-layer cache for this chat
  try {
    await redis.del(`ctx-layer:summary:${chat._id}:${summarizedUpTo}`);
  } catch (err) {
    // best-effort
  }

  return chat.summary;
}

/**
 * Fire-and-forget trigger — called after each turn persisted. Re-reads the
 * chat in case the in-memory copy is stale and runs the summarizer when the
 * threshold is crossed. Never throws.
 */
function maybeTrigger(chatId) {
  if (!chatId) return;
  setImmediate(async () => {
    try {
      const fresh = await AIChat.findById(chatId);
      if (!fresh) return;
      if (!shouldRun(fresh)) return;
      await summarize(fresh);
    } catch (err) {
      logger.warn('chat-summarizer background trigger failed', {
        chatId: String(chatId),
        error: err.message,
      });
    }
  });
}

module.exports = {
  summarize,
  maybeTrigger,
  shouldRun,
  messagesSinceSummary,
  TURNS_SINCE_LAST_SUMMARY_TRIGGER,
  KEEP_RAW_TAIL,
};
