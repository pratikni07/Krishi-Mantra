const express = require('express');
const { list } = require('../controller/FeatureFlagsController');
const { optionalAuth } = require('../middlewares/auth');

const router = express.Router();

// auth-optional: if a token is present we hash for cohort splits later;
// otherwise return defaults so the splash screen can pre-fetch.
router.get('/', optionalAuth, list);

module.exports = router;
