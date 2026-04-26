const express = require('express');
const {
  getMyProfile,
  upsertProfile,
  patchProfile,
  addCrop,
  updateCrop,
  removeCrop,
  searchCrops,
} = require('../controller/FarmProfileController');
const { auth } = require('../middlewares/auth');
const { validate, validateQuery, farmProfileSchemas, cropSearchSchemas } = require('../utils');

const router = express.Router();

router.get('/me', auth, getMyProfile);
router.put('/me', auth, validate(farmProfileSchemas.upsert), upsertProfile);
router.patch('/me', auth, validate(farmProfileSchemas.upsert), patchProfile);

router.post('/me/crops', auth, validate(farmProfileSchemas.addCrop), addCrop);
router.patch('/me/crops/:cropEntryId', auth, validate(farmProfileSchemas.updateCrop), updateCrop);
router.delete('/me/crops/:cropEntryId', auth, removeCrop);

router.get('/crops/search', auth, validateQuery(cropSearchSchemas.query), searchCrops);

module.exports = router;
