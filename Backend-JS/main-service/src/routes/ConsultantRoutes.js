const express = require('express');
const router = express.Router();
const consultantController = require('../controller/ConsultantController');
const { auth } = require('../middlewares/auth');

// Submit / revise a rating for a consultant. One rating per (user, chat).
router.post('/:id/rating', auth, consultantController.submitRating);

// Public listing of ratings for a consultant — used by the consultant
// profile screen and the admin panel.
router.get('/:id/ratings', consultantController.listRatings);

module.exports = router;
