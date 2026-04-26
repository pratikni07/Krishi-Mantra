const express = require('express');
const router = express.Router();
const internalAuth = require('../middlewares/internalAuth.middleware');
const InternalController = require('../controllers/ai-internal.controller');

// Capture rawBody for HMAC verification. JSON bodies only (no multipart
// expected here) so we wrap express.json with a small verify hook.
router.use(
  express.json({
    limit: '256kb',
    verify: (req, _res, buf) => {
      req.rawBody = buf.toString('utf8');
    },
  })
);

router.use(internalAuth);

router.post('/chat', InternalController.chat);
router.post('/vision', InternalController.vision);

module.exports = router;
