const express = require('express');
const {
  today,
  history,
  markStatus,
  farmerInput,
  regenerate,
} = require('../controller/ActionCardController');
const { auth } = require('../middlewares/auth');

const router = express.Router();

router.use(auth);

router.get('/today', today);
router.get('/history', history);
router.post('/regenerate', regenerate);
router.post('/:cardId/items/:itemId/done', (req, res, next) => {
  req.body = { ...(req.body || {}), status: 'done' };
  return markStatus(req, res, next);
});
router.post('/:cardId/items/:itemId/skip', (req, res, next) => {
  req.body = { ...(req.body || {}), status: 'skipped' };
  return markStatus(req, res, next);
});
router.post('/:cardId/items/:itemId/snooze', (req, res, next) => {
  req.body = { ...(req.body || {}), status: 'snoozed' };
  return markStatus(req, res, next);
});

router.post('/:cardId/farmer-input', farmerInput);

module.exports = router;
