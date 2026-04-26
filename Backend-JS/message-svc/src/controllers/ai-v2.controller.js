const AIChat = require('../models/ai-chat.model');
const MessageLimitService = require('../services/message-limit.service');
const IntentRouter = require('../services/intent-router.service');
const ContextTree = require('../services/context-tree.service');
const TokenBudget = require('../services/token-budget.service');
const TokenUsage = require('../services/token-usage.service');
const FarmProfileClient = require('../services/farm-profile.client');
const ChatSummarizer = require('../services/chat-summarizer.service');
const ShadowService = require('../services/shadow.service');
const Metrics = require('../services/metrics.service');

const SHADOW_MODE = (process.env.AI_PROVIDER_MODE || 'legacy').toLowerCase() === 'shadow';
const { active: activeProvider } = require('../ai-providers/factory');
const { ProviderUnavailable } = require('../ai-providers/provider.interface');
const { costFor } = require('../utils/cost-table');
const SSE = require('../utils/sse');
const asyncHandler = require('../utils/asyncHandler');
const logger = require('../utils/logger');

const MAX_CONTENT_PREVIEW = 60;

function userIdOf(req) {
  return (
    req.user?._id || req.user?.id || req.user?.userId || req.body?.userId
  );
}

function wantsSSE(req) {
  return String(req.headers.accept || '').includes('text/event-stream');
}

async function loadOrCreateChat({ chatId, userId, userName, userProfilePhoto, preferredLanguage }) {
  if (chatId) {
    const chat = await AIChat.findById(chatId);
    if (!chat) throw Object.assign(new Error('Chat not found'), { status: 404 });
    if (chat.userId !== String(userId)) {
      throw Object.assign(new Error('Not authorized to access this chat'), { status: 403 });
    }
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    if (chat.dailyMessageCount?.lastResetDate < today) {
      chat.dailyMessageCount = { count: 1, lastResetDate: new Date() };
    } else {
      chat.dailyMessageCount.count = (chat.dailyMessageCount.count || 0) + 1;
    }
    return chat;
  }
  return new AIChat({
    userId: String(userId),
    userName: userName || 'Farmer',
    userProfilePhoto: userProfilePhoto || undefined,
    metadata: { preferredLanguage: preferredLanguage || 'en' },
    context: { currentTopic: '', lastContext: '', identifiedIssues: [], suggestedSolutions: [] },
    dailyMessageCount: { count: 1, lastResetDate: new Date() },
  });
}

function deriveTitle(chat, message) {
  if (chat.title && chat.title !== 'New Conversation') return chat.title;
  if (!message) return chat.title;
  return message.length > 50 ? `${message.slice(0, 50)}...` : message;
}

function safeLog(msg, maxLen = MAX_CONTENT_PREVIEW) {
  if (!msg) return '';
  const s = String(msg);
  return s.length > maxLen ? `${s.slice(0, maxLen)}…` : s;
}

async function consumeStream(stream, onDelta) {
  let full = '';
  let usage = null;
  for await (const ev of stream) {
    if (ev.type === 'delta') {
      full += ev.text;
      if (onDelta) onDelta(ev.text);
    } else if (ev.type === 'done') {
      usage = ev.usage || null;
    } else if (ev.type === 'error') {
      throw Object.assign(new Error(ev.message || 'stream error'), { code: ev.code });
    }
  }
  return { full, usage };
}

function recordAssistantTurn(chat, { userMessage, assistantText, model, provider, usage, costUsd, layers, imageUrls }) {
  chat.messages.push({
    role: 'user',
    content: userMessage,
    timestamp: new Date(),
    ...(imageUrls?.length ? { imageUrl: imageUrls[0] } : {}),
  });
  chat.messages.push({
    role: 'assistant',
    content: assistantText,
    model,
    provider,
    tokenUsage: {
      prompt: usage?.prompt_tokens || 0,
      cached: usage?.prompt_tokens_details?.cached_tokens || 0,
      completion: usage?.completion_tokens || 0,
      costUsd: costUsd || 0,
    },
    timestamp: new Date(),
  });
  TokenUsage.incrementChatUsage(chat, { model, usage, costUsd });
  if (layers && layers.length) {
    chat.contextFingerprint = layers.map((l) => `${l.name}:${l.fp.slice(0, 8)}`).join(',');
  }
}

async function sendMessage(req, res) {
  const userId = userIdOf(req);
  if (!userId) return res.status(401).json({ error: 'Authentication required' });

  const { chatId, message, preferredLanguage, userName, userProfilePhoto } = req.body || {};
  if (!message || !String(message).trim()) {
    return res.status(400).json({ error: 'message is required' });
  }

  if (await TokenUsage.overDailyCap(userId)) {
    return res
      .status(429)
      .json({ error: 'Daily AI cost cap reached for this user', code: 'DAILY_COST_CAP' });
  }
  if (await TokenUsage.overGlobalCap()) {
    return res
      .status(429)
      .json({ error: 'AI service is temporarily rate-limited', code: 'GLOBAL_COST_CAP' });
  }

  const limitStatus = await MessageLimitService.checkAndUpdateMessageCount(userId);
  if (!limitStatus.canSendMessage) {
    return res.status(429).json({
      error: 'Daily message limit reached',
      code: 'DAILY_LIMIT',
      limitInfo: {
        dailyLimit: MessageLimitService.FREE_DAILY_LIMIT,
        remainingMessages: 0,
        resetsAt: new Date(new Date().setHours(24, 0, 0, 0)),
      },
    });
  }
  res.set({
    'X-RateLimit-Limit': MessageLimitService.FREE_DAILY_LIMIT,
    'X-RateLimit-Remaining':
      limitStatus.remainingMessages != null ? limitStatus.remainingMessages : 'unlimited',
    'X-RateLimit-Reset': new Date(new Date().setHours(24, 0, 0, 0)).getTime(),
  });

  let chat;
  try {
    chat = await loadOrCreateChat({
      chatId,
      userId,
      userName,
      userProfilePhoto,
      preferredLanguage,
    });
  } catch (err) {
    return res.status(err.status || 500).json({ error: err.message });
  }

  let provider;
  try {
    provider = await activeProvider();
  } catch (err) {
    const code = err instanceof ProviderUnavailable ? 'PROVIDER_UNAVAILABLE' : 'AI_INIT_FAILED';
    logger.error('AI provider resolution failed', { code, error: err.message });
    return res.status(503).json({ error: 'AI service unavailable', code, message: err.message });
  }

  const profile = await FarmProfileClient.get(userId).catch(() => null);
  const routing = await IntentRouter.classify(message, {
    profileCrops: profile?.crops || [],
    provider,
  });

  const assembled = await ContextTree.assemble({
    chat,
    profile,
    userId,
    message,
    routing,
    preferredLanguage: preferredLanguage || chat.metadata?.preferredLanguage,
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

  const streaming = wantsSSE(req);
  const model = fitted.budgetEscalation ? 'gpt-4.1' : fitted.model;

  logger.ai.request(chat._id, 'chat');
  const startedAt = Date.now();

  try {
    if (streaming) {
      SSE.open(res);
      const stream = await provider.streamChat({
        messages: fitted.messages,
        model,
        userId: String(userId),
        maxTokens: fitted.maxOutputTokens,
        temperature: 0.4,
        fingerprint: prefixCtx.fingerprint,
        prefixTokens: prefixCtx.prefixTokens,
      });
      const { full, usage } = await consumeStream(stream, (delta) =>
        SSE.data(res, { type: 'delta', text: delta })
      );
      const costUsd = costFor(model, usage || {});
      recordAssistantTurn(chat, {
        userMessage: message,
        assistantText: full,
        model,
        provider: provider.provider,
        usage,
        costUsd,
        layers: assembled.layers,
      });
      chat.title = deriveTitle(chat, message);
      await chat.save();

      TokenUsage.recordTurn({
        userId,
        chatId: chat._id,
        model,
        provider: provider.provider,
        usage,
        costUsd,
      });
      Metrics.recordTurn({
        provider: provider.provider,
        model,
        intent: routing.intent,
        durationMs: Date.now() - startedAt,
        usage,
        costUsd,
      });
      if (fitted.budgetEscalation) Metrics.recordBudgetEscalation(model);
      ChatSummarizer.maybeTrigger(chat._id);

      if (SHADOW_MODE) {
        Metrics.recordShadow({ primary: provider.provider, shadow: 'pending' });
        ShadowService.runShadow({
          chatId: chat._id,
          userId,
          intent: routing.intent,
          primaryResult: {
            provider: provider.provider,
            model,
            latencyMs: Date.now() - startedAt,
            tokens: {
              prompt: usage?.prompt_tokens || 0,
              cached: usage?.prompt_tokens_details?.cached_tokens || 0,
              completion: usage?.completion_tokens || 0,
            },
            costUsd,
            text: full,
            error: null,
          },
          fitted,
          prefixCtx,
        });
      }

      SSE.data(res, {
        type: 'done',
        chatId: chat._id,
        title: chat.title,
        usage,
        intent: routing.intent,
        tokenEst: fitted.tokenEst,
        layers: assembled.layers.map((l) => l.name),
      });
      SSE.close(res);
      logger.ai.response(chat._id, Date.now() - startedAt);
      return;
    }

    const { text, usage } = await provider.chat({
      messages: fitted.messages,
      model,
      userId: String(userId),
      maxTokens: fitted.maxOutputTokens,
      temperature: 0.4,
      fingerprint: prefixCtx.fingerprint,
      prefixTokens: prefixCtx.prefixTokens,
    });
    const costUsd = costFor(model, usage || {});
    recordAssistantTurn(chat, {
      userMessage: message,
      assistantText: text,
      model,
      provider: provider.provider,
      usage,
      costUsd,
      layers: assembled.layers,
    });
    chat.title = deriveTitle(chat, message);
    await chat.save();

    TokenUsage.recordTurn({
      userId,
      chatId: chat._id,
      model,
      provider: provider.provider,
      usage,
      costUsd,
    });
    Metrics.recordTurn({
      provider: provider.provider,
      model,
      intent: routing.intent,
      durationMs: Date.now() - startedAt,
      usage,
      costUsd,
    });
    if (fitted.budgetEscalation) Metrics.recordBudgetEscalation(model);
    ChatSummarizer.maybeTrigger(chat._id);

    if (SHADOW_MODE) {
      Metrics.recordShadow({ primary: provider.provider, shadow: 'pending' });
      ShadowService.runShadow({
        chatId: chat._id,
        userId,
        intent: routing.intent,
        primaryResult: {
          provider: provider.provider,
          model,
          latencyMs: Date.now() - startedAt,
          tokens: {
            prompt: usage?.prompt_tokens || 0,
            cached: usage?.prompt_tokens_details?.cached_tokens || 0,
            completion: usage?.completion_tokens || 0,
          },
          costUsd,
          text,
          error: null,
        },
        fitted,
        prefixCtx,
      });
    }

    logger.ai.response(chat._id, Date.now() - startedAt);

    return res.json({
      chatId: chat._id,
      message: text,
      title: chat.title,
      intent: routing.intent,
      model,
      provider: provider.provider,
      usage,
      costUsd: Number(costUsd.toFixed(6)),
      context: chat.context,
      history: chat.messages.slice(-10),
      limitInfo: {
        dailyLimit: MessageLimitService.FREE_DAILY_LIMIT,
        remainingMessages: limitStatus.remainingMessages,
        resetsAt: new Date(new Date().setHours(24, 0, 0, 0)),
      },
    });
  } catch (err) {
    logger.ai.error(chat?._id, err);
    Metrics.recordTurn({
      provider: provider?.provider,
      model,
      intent: routing?.intent,
      durationMs: Date.now() - startedAt,
      error: err.code || 'AI_ERROR',
    });
    const alreadyOpen = streaming && res.headersSent;
    if (alreadyOpen) {
      SSE.data(res, { type: 'error', code: err.code || 'AI_ERROR', message: err.message });
      SSE.close(res);
      return;
    }
    if (err.status === 429) {
      return res.status(429).json({ error: 'Rate limit exceeded', message: err.message });
    }
    return res.status(500).json({
      error: 'Failed to process message',
      code: err.code || 'AI_ERROR',
      message: err.message,
    });
  }
}

async function analyzeImage(req, res, { multi = false } = {}) {
  const userId = userIdOf(req);
  if (!userId) return res.status(401).json({ error: 'Authentication required' });

  const files = multi ? req.files : req.file ? [req.file] : [];
  if (!files.length) return res.status(400).json({ error: 'No image provided' });
  for (const f of files) {
    if (!f.mimetype?.startsWith('image/')) {
      return res.status(400).json({ error: 'Invalid file type. Only images allowed.' });
    }
    if (!f.buffer?.length) {
      return res.status(400).json({ error: 'Empty image file' });
    }
    if (f.size > 10 * 1024 * 1024) {
      return res.status(400).json({ error: 'Image too large (max 10MB)' });
    }
  }

  const { chatId, preferredLanguage, userName, message } = req.body || {};
  const userMessage = (message && String(message).trim()) || 'Analyze the attached crop image(s).';

  let provider;
  try {
    provider = await activeProvider();
  } catch (err) {
    return res.status(503).json({ error: 'AI service unavailable', message: err.message });
  }

  let chat;
  try {
    chat = await loadOrCreateChat({
      chatId,
      userId,
      userName,
      preferredLanguage,
    });
    chat.context = chat.context || {};
    chat.context.currentTopic = chat.context.currentTopic || 'plant health';
  } catch (err) {
    return res.status(err.status || 500).json({ error: err.message });
  }

  const profile = await FarmProfileClient.get(userId).catch(() => null);
  const routing = {
    intent: 'plant-health',
    cropsOfInterest: [],
    needsWeather: true,
    needsCropBlock: true,
    lowCostOk: false,
  };
  const assembled = await ContextTree.assemble({
    chat,
    profile,
    userId,
    message: userMessage,
    routing,
    preferredLanguage: preferredLanguage || chat.metadata?.preferredLanguage,
  });
  const fitted = TokenBudget.fit(assembled, { maxInputTokens: 3000 });

  const imageDataUrls = files.map(
    (f) => `data:${f.mimetype};base64,${f.buffer.toString('base64')}`
  );

  try {
    const { text, usage, model } = await provider.analyzeImages({
      messages: fitted.messages,
      imageUrls: imageDataUrls,
      userId: String(userId),
    });
    const effectiveModel = model || 'vision';
    const costUsd = costFor(effectiveModel, usage || {});
    recordAssistantTurn(chat, {
      userMessage,
      assistantText: text,
      model: effectiveModel,
      provider: provider.provider,
      usage,
      costUsd,
      layers: assembled.layers,
      imageUrls: ['image_upload'],
    });
    chat.title = deriveTitle(chat, userMessage);
    await chat.save();

    TokenUsage.recordTurn({
      userId,
      chatId: chat._id,
      model: effectiveModel,
      provider: provider.provider,
      usage,
      costUsd,
    });

    return res.status(200).json({
      chatId: chat._id,
      analysis: text,
      model: effectiveModel,
      provider: provider.provider,
      usage,
      costUsd: Number(costUsd.toFixed(6)),
      context: chat.context,
      history: chat.messages.slice(-10),
    });
  } catch (err) {
    logger.ai.error(chat?._id, err);
    return res.status(500).json({
      error: 'Failed to analyze image',
      message: err.message,
    });
  }
}

module.exports = {
  sendMessage: asyncHandler(sendMessage),
  analyzeCropImage: asyncHandler((req, res) => analyzeImage(req, res, { multi: false })),
  analyzeMultipleImages: asyncHandler((req, res) => analyzeImage(req, res, { multi: true })),
};
