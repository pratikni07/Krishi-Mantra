const multer = require('multer');
const asyncHandler = require('../utils/asyncHandler');
const SSE = require('../utils/sse');
const VoiceTurn = require('../services/voice-turn.service');
const VoiceCache = require('../services/voice-cache.service');
const VoiceQuota = require('../services/voice-quota.service');
const AIChat = require('../models/ai-chat.model');
const logger = require('../utils/logger');

const KILLSWITCHES = require('../ai-providers/factory'); // for resetCache on flips

let redis;
try {
  redis = require('../config/redis');
} catch (err) {
  redis = null;
}

const HARD_AUDIO_BYTES = 1 * 1024 * 1024;

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: HARD_AUDIO_BYTES },
});

exports.uploadMiddleware = upload.single('audio');

function userIdOf(req) {
  return req.user?._id || req.user?.id || req.user?.userId;
}

async function killswitchActive() {
  if (!redis) return false;
  try {
    const [g, v] = await Promise.all([
      redis.get('ai:killswitch:global'),
      redis.get('ai:killswitch:voice'),
    ]);
    return g === '1' || v === '1';
  } catch (err) {
    return false;
  }
}

exports.chat = asyncHandler(async (req, res) => {
  const userId = userIdOf(req);
  if (!userId) return res.status(401).json({ error: 'auth_required' });
  if (!req.file?.buffer) return res.status(400).json({ error: 'audio_required' });

  if (await killswitchActive()) {
    return res.status(503).json({ error: 'voice_disabled', code: 'VOICE_KILLSWITCH' });
  }

  const maxSec = await VoiceQuota.maxAudioSecForUser(userId);
  // Cheap audio-length sanity from buffer size; defends against the ~1MB
  // hard cap accidentally still being too long for the user's tier.
  const approxSeconds = Math.round(req.file.buffer.length / 4000); // 16kbps AAC ~= 4 KB/s
  if (approxSeconds > maxSec + 5) {
    return res.status(400).json({ error: 'audio_too_long', maxSec });
  }

  const stream = VoiceTurn.run({
    userId,
    chatId: req.body?.chatId,
    userName: req.body?.userName,
    userProfilePhoto: req.body?.userProfilePhoto,
    audioBuffer: req.file.buffer,
    mimeType: req.file.mimetype || 'audio/mp4',
    preferredLanguage: req.body?.preferredLanguage,
    voiceName: req.body?.voiceName,
  });

  SSE.open(res);
  let closed = false;
  const onAbort = () => { closed = true; };
  res.on('close', onAbort);
  try {
    for await (const ev of stream) {
      if (closed) break;
      SSE.data(res, ev);
    }
  } catch (err) {
    if (!closed) {
      SSE.data(res, {
        type: 'error',
        code: 'VOICE_TURN_FAILED',
        message: err.message,
      });
    }
    logger.warn('voice.controller.turn_failed', { error: err.message });
  } finally {
    res.removeListener('close', onAbort);
    SSE.close(res);
  }
});

/**
 * Replay endpoint — serves the cached TTS audio for an assistant message.
 * Auth-checked: only the chat owner gets the audio.
 */
exports.replay = asyncHandler(async (req, res) => {
  const userId = userIdOf(req);
  if (!userId) return res.status(401).json({ error: 'auth_required' });

  const { messageId } = req.params;
  const voice = req.query.voice || 'default';

  // Find the chat that owns this message id. Tiny scan with index on userId
  // keeps this cheap.
  const chat = await AIChat.findOne({
    userId: String(userId),
    'messages._id': messageId,
  }).lean();

  if (!chat) return res.status(404).json({ error: 'no_audio' });

  const cached = await VoiceCache.getReplay(String(messageId), voice);
  if (!cached) return res.status(404).json({ error: 'no_audio' });

  res.setHeader('Content-Type', cached.mime || 'audio/mp3');
  res.setHeader('Cache-Control', 'private, max-age=86400');
  return res.end(cached.buffer);
});

exports.killswitchUtils = { reset: KILLSWITCHES.resetCache };
