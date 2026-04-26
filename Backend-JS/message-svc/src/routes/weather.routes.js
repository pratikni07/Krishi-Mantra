const express = require('express');
const router = express.Router();
const authMiddleware = require('../middlewares/auth.middleware');
const createRateLimiter = require('../middleware/rate-limit.middleware');
const WeatherController = require('../controllers/weather.controller');

const weatherLimiter = createRateLimiter({
  windowMs: 60 * 1000,
  max: 120,
  message: {
    error: 'Weather rate limit exceeded. Please wait a moment.',
    retryAfter: 60,
  },
});

router.get('/7day', authMiddleware, weatherLimiter, WeatherController.get7Day);

module.exports = router;
