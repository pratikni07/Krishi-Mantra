// routes/userRoutes.js (adding to existing file)
const express = require("express");
const router = express.Router();
const {
  getUserByPage,
  getUserById,
  updateUserProfile,
  updateUserDetails,
  updateSubscription,
  getConsultant,
  getUserGrowthStats,
  getDashboardStats,
  getUserByUsername,
  searchUsersByPartialUsername,
} = require("../controller/UserController");

router.get("/users", getUserByPage);
router.get("/users/:id", getUserById);

router.put("/profile", updateUserProfile);
router.put("/details", updateUserDetails);
router.put("/subscription", updateSubscription);

router.get("/consultant", getConsultant);

router.get("/users/username/:username", getUserByUsername);

router.get("/username/search", searchUsersByPartialUsername);

module.exports = router;
