const express = require('express');
const router = express.Router();
const auth = require('../middlewares/auth.middleware');
const createRateLimiter = require('../middleware/rate-limit.middleware');
const VoiceController = require('../controllers/voice.controller');

const voiceLimiter = createRateLimiter({
  windowMs: 60 * 1000,
  max: 30,
  message: {
    error: 'voice_rate_limited',
    retryAfter: 60,
  },
});

const replayLimiter = createRateLimiter({
  windowMs: 60 * 1000,
  max: 60,
});

router.post(
  '/chat',
  auth,
  voiceLimiter,
  VoiceController.uploadMiddleware,
  VoiceController.chat
);

router.get(
  '/replay/:messageId',
  auth,
  replayLimiter,
  VoiceController.replay
);

module.exports = router;
