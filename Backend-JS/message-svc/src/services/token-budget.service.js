const logger = require('../utils/logger');

const DEFAULT_MAX_INPUT_TOKENS = parseInt(process.env.AI_MAX_INPUT_TOKENS || '2500', 10);
const DEFAULT_MAX_OUTPUT_TOKENS = parseInt(process.env.AI_MAX_OUTPUT_TOKENS || '800', 10);

// Layer drop priority (lowest first = first to go). L0 core + L1 profile + L6 turn
// must never be dropped.
const DROP_ORDER = ['knowledge-hints', 'market-context', 'crop-calendar', 'summary', 'crops', 'weather'];

function approxTokens(text) {
  if (!text) return 0;
  return Math.ceil(String(text).length / 4);
}

function estimateMessagesTokens(messages) {
  let total = 0;
  for (const m of messages || []) {
    total += 4;
    if (typeof m.content === 'string') {
      total += approxTokens(m.content);
    } else if (Array.isArray(m.content)) {
      for (const part of m.content) {
        if (part?.type === 'text' && part.text) total += approxTokens(part.text);
        else if (part?.type === 'image_url') total += 85;
      }
    }
  }
  return total + 2;
}

function countTurns(messages) {
  return (messages || []).filter((m) => m.role === 'user' || m.role === 'assistant').length;
}

/**
 * Takes the context-tree output `{ messages, layers, ... }` and a budget,
 * mutates a copy to fit under the budget. Returns the fitted assembly.
 *
 * Pruning order:
 *   1. Drop layers in DROP_ORDER (stopping when under budget).
 *   2. Truncate the oldest window turns (keeping last 4).
 *   3. If still over, flag `budget_escalation` — caller may switch model.
 *   4. Never drops L0 core, L1 profile, or the final user turn.
 */
function fit(assembly, opts = {}) {
  const maxInputTokens = opts.maxInputTokens || DEFAULT_MAX_INPUT_TOKENS;
  const maxOutputTokens = opts.maxOutputTokens || assembly.maxOutputTokens || DEFAULT_MAX_OUTPUT_TOKENS;

  const layers = Array.isArray(assembly.layers) ? [...assembly.layers] : [];
  const droppedLayers = [];
  const messages = Array.isArray(assembly.messages) ? [...assembly.messages] : [];

  const rebuildSystem = () => layers.map((l) => l.text).join('\n\n');
  const assembleMessages = (window, userTurn) => {
    const out = [{ role: 'system', content: rebuildSystem() }];
    for (const w of window) out.push(w);
    if (userTurn) out.push(userTurn);
    return out;
  };

  // Split existing messages
  const systemMsgIndex = messages.findIndex((m) => m.role === 'system');
  const nonSystem = messages.slice(systemMsgIndex + 1);
  // Last message is the user's current turn if it's the final user message.
  let userTurn = null;
  if (nonSystem.length > 0 && nonSystem[nonSystem.length - 1].role === 'user') {
    userTurn = nonSystem.pop();
  }
  let windowMsgs = nonSystem;

  let current = estimateMessagesTokens(assembleMessages(windowMsgs, userTurn));
  const actions = [];

  // Phase 1: drop layers in priority order.
  for (const name of DROP_ORDER) {
    if (current <= maxInputTokens) break;
    const idx = layers.findIndex((l) => l.name === name);
    if (idx === -1) continue;
    const removed = layers.splice(idx, 1)[0];
    droppedLayers.push(removed.name);
    actions.push(`drop:${removed.name}`);
    current = estimateMessagesTokens(assembleMessages(windowMsgs, userTurn));
  }

  // Phase 2: truncate window (keep at least last 4 turns).
  while (current > maxInputTokens && windowMsgs.length > 4) {
    windowMsgs.shift();
    actions.push('truncate:window');
    current = estimateMessagesTokens(assembleMessages(windowMsgs, userTurn));
  }

  const escalation = current > maxInputTokens;
  if (escalation) {
    logger.warn('token-budget escalation', { current, maxInputTokens });
  }

  const finalMessages = assembleMessages(windowMsgs, userTurn);

  return {
    ...assembly,
    messages: finalMessages,
    layers,
    droppedLayers,
    tokenEst: current,
    maxOutputTokens,
    budgetEscalation: escalation,
    budgetActions: actions,
  };
}

module.exports = {
  fit,
  estimateMessagesTokens,
  countTurns,
  DEFAULT_MAX_INPUT_TOKENS,
  DEFAULT_MAX_OUTPUT_TOKENS,
};
