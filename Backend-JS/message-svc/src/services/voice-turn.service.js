/**
 * Voice turn orchestrator.
 *
 * One async generator that yields normalized SSE events for the voice
 * controller to forward to the client:
 *
 *   { type: "transcript", text, lang, confidence }
 *   { type: "delta",      text }
 *   { type: "audio",      seq, mime, lang, data: <base64>, voiceName }
 *   { type: "done",       chatId, title, usage, voice: {...} }
 *   { type: "error",      code, message }
 *
 * Glue:
 *   STT  ──► AI orchestrator (context tree + provider stream)
 *   AI   ──► sentence buffer ──► TTS per sentence ──► audio events
 *
 * Quota is checked & consumed here. Cost is recorded both per-call and on the
 * AIChat ledger (chat.voice.{stt,tts}CostUsd, message.voice.{...}).
 */

const AIChat = require('../models/ai-chat.model');
const Orchestrator = require('./ai-orchestrator.service');
const VoiceQuota = require('./voice-quota.service');
const VoiceCache = require('./voice-cache.service');
const RateLimiter = require('./voice-rate-limiter.service');
const SttFactory = require('../voice/stt.factory');
const TtsFactory = require('../voice/tts.factory');
const audioUtils = require('../voice/audio-utils');
const Metrics = require('./metrics.service');

let logger;
try {
  logger = require('../utils/logger');
} catch (err) {
  logger = { info: () => {}, warn: () => {}, error: () => {}, debug: () => {} };
}

const DEFAULT_TEMPERATURE = 0.4;

async function* run({
  userId,
  chatId,
  userName,
  userProfilePhoto,
  audioBuffer,
  mimeType,
  preferredLanguage,
  voiceName,
}) {
  if (!userId) {
    yield { type: 'error', code: 'UNAUTHENTICATED', message: 'auth_required' };
    return;
  }
  if (!Buffer.isBuffer(audioBuffer) || audioBuffer.length === 0) {
    yield { type: 'error', code: 'NO_AUDIO', message: 'audio_required' };
    return;
  }

  const startedAt = Date.now();
  let sttCostUsd = 0;
  let ttsCostUsd = 0;
  let totalAudioSec = 0;

  // 1. Quota
  const hard = await VoiceQuota.exceededHard(userId);
  if (hard.exceeded) {
    yield { type: 'error', code: 'VOICE_QUOTA', message: hard.reason };
    Metrics.recordVoiceQuotaExhausted?.(hard.reason);
    Metrics.recordVoiceTurn?.({ result: 'quota', totalMs: Date.now() - startedAt });
    return;
  }

  // 2. STT
  let stt;
  try {
    stt = await SttFactory.active();
  } catch (err) {
    yield { type: 'error', code: 'STT_UNAVAILABLE', message: err.message };
    return;
  }
  let sttResult;
  const sttStartedAt = Date.now();
  let sttMs = 0;
  try {
    await RateLimiter.sttBucket.acquire({ maxWaitMs: 200 });
    sttResult = await stt.transcribe({
      audioBuffer,
      mimeType,
      hintedLanguage: preferredLanguage,
    });
    sttCostUsd = stt.priceFor(sttResult.durationSec || 0);
    sttMs = Date.now() - sttStartedAt;
  } catch (err) {
    Metrics.recordVoiceProviderError?.(stt?.provider, 'stt');
    Metrics.recordVoiceTurn?.({ result: 'ai_error', totalMs: Date.now() - startedAt });
    yield { type: 'error', code: err?.code || 'STT_FAILED', message: err.message };
    return;
  }

  if (!sttResult.text || (sttResult.confidence > 0 && sttResult.confidence < 0.25)) {
    // Refund the quota — user shouldn't be punished for STT misreads.
    await VoiceQuota.refundLastCall(userId, 'stt_empty');
    Metrics.recordVoiceTurn?.({ result: 'stt_empty', totalMs: Date.now() - startedAt, sttMs });
    yield {
      type: 'error',
      code: 'STT_EMPTY',
      message: 'couldnt_catch_that',
      transcript: sttResult.text || '',
      confidence: sttResult.confidence,
    };
    return;
  }

  yield {
    type: 'transcript',
    text: sttResult.text,
    lang: sttResult.languageCode,
    confidence: sttResult.confidence,
  };

  // 3. Load/create chat
  let chat;
  try {
    if (chatId) {
      chat = await AIChat.findById(chatId);
      if (!chat || String(chat.userId) !== String(userId)) {
        yield { type: 'error', code: 'CHAT_NOT_FOUND' };
        return;
      }
    } else {
      chat = new AIChat({
        userId: String(userId),
        userName: userName || 'Farmer',
        userProfilePhoto: userProfilePhoto || undefined,
        metadata: { preferredLanguage: sttResult.languageCode || preferredLanguage || 'en' },
        context: { currentTopic: '', lastContext: '', identifiedIssues: [], suggestedSolutions: [] },
      });
    }
  } catch (err) {
    yield { type: 'error', code: 'CHAT_LOAD_FAILED', message: err.message };
    return;
  }

  // 4. Prepare AI turn
  let prep;
  try {
    prep = await Orchestrator.prepareTurn({
      chat,
      userText: sttResult.text,
      preferredLanguage: sttResult.languageCode || preferredLanguage,
      userId,
    });
  } catch (err) {
    yield { type: 'error', code: 'AI_INIT_FAILED', message: err.message };
    return;
  }

  // 5. Resolve TTS provider (lazy — only if voice replies are enabled in
  //    the active config). Failure here downgrades to text-only mode for the
  //    rest of this turn.
  let tts = null;
  try {
    tts = await TtsFactory.active();
  } catch (err) {
    logger.warn('voice-turn.tts_unavailable', { error: err.message });
  }

  // 6. Stream the AI reply, sentence-pluck → TTS → emit audio events.
  const ttsLang = sttResult.languageCode || prep.lang || 'hi';
  const useVoiceName = voiceName || audioUtils.pickVoice(ttsLang);
  const audioBuffersForCache = [];
  let firstAudioMime = 'audio/mp3';
  let textBuffer = '';
  let sentenceBuf = '';
  let seq = 0;
  let aiUsage = null;

  let aiStream;
  try {
    aiStream = await Orchestrator.streamFromProvider({
      provider: prep.provider,
      fitted: prep.fitted,
      prefixCtx: prep.prefixCtx,
      model: prep.model,
      userId,
      temperature: DEFAULT_TEMPERATURE,
    });
  } catch (err) {
    yield { type: 'error', code: 'AI_FAILED', message: err.message };
    return;
  }

  async function* streamSentence(sentence) {
    if (!tts || !sentence) return;
    try {
      await RateLimiter.ttsBucket.acquire({ maxWaitMs: 200 });
    } catch (err) {
      logger.warn('voice-turn.tts_throttled', { error: err.message });
      return;
    }
    try {
      for await (const chunk of tts.synthesizeStream({
        text: sentence,
        languageCode: ttsLang,
        voiceName: useVoiceName,
      })) {
        ttsCostUsd += tts.priceFor(sentence.length);
        totalAudioSec += chunk.durationSec || 0;
        firstAudioMime = chunk.mime || firstAudioMime;
        audioBuffersForCache.push(chunk.audio);
        yield {
          type: 'audio',
          seq: seq++,
          mime: chunk.mime || 'audio/mp3',
          lang: ttsLang,
          data: chunk.audio.toString('base64'),
          voiceName: useVoiceName,
        };
      }
    } catch (err) {
      logger.warn('voice-turn.tts_chunk_failed', { error: err.message });
    }
  }

  try {
    for await (const ev of aiStream) {
      if (ev.type === 'delta') {
        textBuffer += ev.text;
        sentenceBuf += ev.text;
        yield { type: 'delta', text: ev.text };
        // Drain any complete sentences sitting in the buffer
        while (true) {
          const s = audioUtils.pluckSentence(sentenceBuf);
          if (!s) break;
          sentenceBuf = s.rest;
          yield* streamSentence(s.text);
        }
      } else if (ev.type === 'done') {
        aiUsage = ev.usage || null;
      } else if (ev.type === 'error') {
        yield ev;
        return;
      }
    }
    // Tail flush
    if (sentenceBuf.trim()) {
      yield* streamSentence(sentenceBuf.trim());
    }
  } catch (err) {
    yield { type: 'error', code: 'AI_STREAM_FAILED', message: err.message };
    return;
  }

  // 7. Persist + cost ledger
  const aiCostUsd = require('../utils/cost-table').costFor(prep.model, aiUsage || {});
  const totalCost = aiCostUsd + sttCostUsd + ttsCostUsd;

  // Title for new chats
  if (!chatId && (!chat.title || chat.title === 'New Conversation')) {
    chat.title = sttResult.text.length > 50
      ? `${sttResult.text.slice(0, 50)}...`
      : sttResult.text;
  }

  Orchestrator.recordAssistantTurn(chat, {
    userMessage: sttResult.text,
    assistantText: textBuffer,
    model: prep.model,
    provider: prep.provider.provider,
    usage: aiUsage,
    costUsd: aiCostUsd,
    layers: prep.assembled?.layers,
    voiceUser: {
      kind: 'user_voice',
      transcript: sttResult.text,
      language: sttResult.languageCode,
      confidence: sttResult.confidence,
      durationSec: sttResult.durationSec,
      sttCostUsd,
    },
    voiceAssistant: tts
      ? {
          kind: 'assistant_voice',
          voiceName: useVoiceName,
          durationSec: totalAudioSec,
          audioMime: firstAudioMime,
          ttsCostUsd,
        }
      : undefined,
  });

  await Orchestrator.persistChat(chat);

  // Cache the concatenated audio for /replay/:messageId. The assistant
  // message is the LAST one in the array after recordAssistantTurn.
  if (audioBuffersForCache.length > 0) {
    const assistantMessage = chat.messages[chat.messages.length - 1];
    if (assistantMessage) {
      const messageId = String(assistantMessage._id || `${chat._id}-${chat.messages.length - 1}`);
      const concatenated = Buffer.concat(audioBuffersForCache);
      await VoiceCache.set(messageId, useVoiceName, firstAudioMime, concatenated);
      assistantMessage.voice = assistantMessage.voice || {};
      assistantMessage.voice.audioCacheKey = `voice-tts:${messageId}:${useVoiceName}`;
      // Re-save with the cache key. Keep this best-effort.
      try { await chat.save(); } catch (_) {}
    }
  }

  await VoiceQuota.consume(userId);
  await VoiceQuota.recordCost(userId, totalCost);
  Orchestrator.maybeFireSummarizer(chat);

  Metrics.recordTurn?.({
    provider: prep.provider.provider,
    model: prep.model,
    intent: prep.routing?.intent,
    durationMs: Date.now() - startedAt,
    usage: aiUsage,
    costUsd: aiCostUsd,
  });
  Metrics.recordVoiceTurn?.({
    result: 'success',
    totalMs: Date.now() - startedAt,
    sttMs,
    sttProvider: stt.provider,
    ttsProvider: tts?.provider,
    sttCostUsd,
    ttsCostUsd,
    audioOutSec: totalAudioSec,
  });

  logger.info?.('voice.turn', {
    event: 'voice.turn',
    userId: String(userId).slice(-8),
    chatId: String(chat._id),
    stt: {
      provider: stt.provider,
      lang: sttResult.languageCode,
      confidence: sttResult.confidence,
      durationSec: sttResult.durationSec,
      costUsd: Number(sttCostUsd.toFixed(6)),
    },
    ai: {
      model: prep.model,
      provider: prep.provider.provider,
      tokens: {
        prompt: aiUsage?.prompt_tokens || 0,
        cached: aiUsage?.prompt_tokens_details?.cached_tokens || 0,
        completion: aiUsage?.completion_tokens || 0,
      },
      costUsd: Number(aiCostUsd.toFixed(6)),
    },
    tts: tts
      ? {
          provider: tts.provider,
          voice: useVoiceName,
          outSec: totalAudioSec,
          costUsd: Number(ttsCostUsd.toFixed(6)),
        }
      : null,
    totalLatencyMs: Date.now() - startedAt,
  });

  yield {
    type: 'done',
    chatId: chat._id,
    title: chat.title,
    usage: aiUsage,
    voice: {
      sttCostUsd: Number(sttCostUsd.toFixed(6)),
      ttsCostUsd: Number(ttsCostUsd.toFixed(6)),
      totalAudioSec,
      voiceName: useVoiceName,
      languageCode: ttsLang,
    },
  };
}

module.exports = { run };
