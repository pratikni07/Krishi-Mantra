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
  updateUserDeviceAccess,
  getAccountTypeInternal,
} = require("../controller/UserController");
const { adminAuth, requireInternalService } = require('../middlewares/auth');

router.get("/users", getUserByPage);
router.get("/users/:id", getUserById);

router.put("/profile", updateUserProfile);
router.put("/details", updateUserDetails);
router.put("/subscription", updateSubscription);

router.get("/consultant", getConsultant);

router.get("/users/username/:username", getUserByUsername);

router.get("/username/search", searchUsersByPartialUsername);
router.put('/admin/users/:userId/device-access', adminAuth, updateUserDeviceAccess);

// Internal: lightweight account-type lookup for service-to-service calls.
// Used by message-svc to detect "is this a consultant chat" without
// pulling the full User document. Gated by INTERNAL_SERVICE_SECRET.
router.get('/internal/:id/account-type', requireInternalService, getAccountTypeInternal);

module.exports = router;
