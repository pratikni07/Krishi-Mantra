// Import the required modules
const express = require("express");
const router = express.Router();

// Import the required controllers and middleware functions
const {
  login,
  signup,
  sendotp,
  changePassword,
  findUserIp,
  initiateAuth,
  verifyOTP,
  getPendingOTPs,
  markOTPSent,
  signupWithPhone,
} = require("../controller/Auth");

// const {
//   resetPasswordToken,
//   resetPassword,
// } = require("../controllers/ResetPassword")

const { auth } = require("../middlewares/auth");

// Routes for Login, Signup, and Authentication

// ********************************************************************************************************
//                                      Authentication routes
// ********************************************************************************************************

// New mobile authentication routes
router.post("/initiate-auth", initiateAuth);
router.post("/verify-otp", verifyOTP);
router.post("/signup-with-phone", signupWithPhone);

// Admin routes for OTP management
router.get("/admin/pending-otps", getPendingOTPs);
router.put("/admin/mark-otp-sent/:otpId", markOTPSent);

// Legacy routes
router.post("/login", login);
router.post("/signup", signup);
router.post("/sendotp", sendotp);
router.get("/location", findUserIp);

// Route for Changing the password
router.post("/changepassword", auth, changePassword);

// ********************************************************************************************************
//                                      Reset Password
// ********************************************************************************************************

// Route for generating a reset password token
// router.post("/reset-password-token", resetPasswordToken)

// // Route for resetting user's password after verification
// router.post("/reset-password", resetPassword)

// Export the router for use in the main application
module.exports = router;
