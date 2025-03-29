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
} = require("../controller/Auth");

// const {
//   resetPasswordToken,
//   resetPassword,
// } = require("../controllers/ResetPassword")

const { auth } = require("../middlewares/auth");

// Routes for Login, Signup, and Authentication

// New mobile authentication routes
router.post("/initiate-auth", initiateAuth);
router.post("/verify-otp", verifyOTP);
router.post("/signup-with-phone", signupWithPhone);

// Add admin login route
router.post("/admin/login", adminLogin);

// Admin routes for OTP management
router.get("/admin/pending-otps", getPendingOTPs);
router.put("/admin/mark-otp-sent/:otpId", markOTPSent);

module.exports = router;
