// Import the required modules
const express = require("express");
const router = express.Router();

const {
  findUserIp,
  initiateAuth,
  verifyOTP,
  getPendingOTPs,
  markOTPSent,
  signupWithPhone,
  adminLogin,
  refreshToken,
  logout,
  getMe,
} = require("../controller/Auth");
const validate = require("../middlewares/validate");
const authSchemas = require("../schemas/auth");
const { adminAuth, auth } = require("../middlewares/auth");

// New mobile authentication routes
router.post("/initiate-auth", validate({ body: authSchemas.initiateAuth }), initiateAuth);
router.post("/verify-otp", validate({ body: authSchemas.verifyOTP }), verifyOTP);
router.post("/signup-with-phone", validate({ body: authSchemas.signupWithPhone }), signupWithPhone);

// Token lifecycle
router.post("/refresh-token", validate({ body: authSchemas.refreshToken }), refreshToken);
router.post("/logout", validate({ body: authSchemas.logout }), logout);

// Cheap protected endpoint used by the mobile splash to validate the cached
// access token before navigating into the authed UI.
router.get("/me", auth, getMe);

// Add admin login route
router.post("/admin/login", validate({ body: authSchemas.adminLogin }), adminLogin);

// Admin routes for OTP management — adminAuth-gated because pending OTPs
// leak any user's login code to whoever can hit the endpoint.
router.get("/admin/pending-otps", adminAuth, getPendingOTPs);
router.put("/admin/mark-otp-sent/:otpId", adminAuth, markOTPSent);

module.exports = router;
