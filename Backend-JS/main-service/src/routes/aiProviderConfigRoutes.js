const express = require('express');
const {
  list,
  getOne,
  upsertOpenAI,
  upsertVertex,
  activate,
  deactivateAll,
  remove,
  audit,
} = require('../controller/AiProviderConfigController');
const { auth, isAdmin } = require('../middlewares/auth');

const router = express.Router();

router.use(auth, isAdmin);

router.get('/', list);
router.get('/audit', audit);
router.get('/:id', getOne);

router.post('/openai', upsertOpenAI);
router.put('/openai/:id', (req, res, next) => {
  req.body = { ...(req.body || {}), id: req.params.id };
  return upsertOpenAI(req, res, next);
});

router.post('/vertex', upsertVertex);
router.put('/vertex/:id', (req, res, next) => {
  req.body = { ...(req.body || {}), id: req.params.id };
  return upsertVertex(req, res, next);
});

router.post('/:id/activate', activate);
router.post('/deactivate', deactivateAll);
router.delete('/:id', remove);

module.exports = router;
