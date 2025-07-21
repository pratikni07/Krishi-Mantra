// Import the required modules
const express = require("express");
const router = express.Router();
const { auth } = require("../middlewares/auth");

const {
  changePassword,
  findUserIp,
  initiateAuth,
  getPendingOTPs,
  markOTPSent,
  verifyOTP,
  signup,
  adminLogin
} = require("../controller/Auth");

// Change Password
router.post("/changepassword", auth, changePassword);

// Find IP location
router.get("/ip-location", findUserIp);

// Authentication routes
router.post("/initiate", initiateAuth);
router.post("/verify-otp", verifyOTP);
router.post("/signup", signup);

// Add admin login route
router.post("/admin/login", adminLogin);

// Add token validation route for inter-service communication
router.get(
  "/validate-token", 
  auth, 
  (req, res) => {
    try {
      // If auth middleware passes, token is valid and user is attached to request
      return res.status(200).json({
        success: true,
        user: {
          id: req.user.id,
          accountType: req.user.accountType,
          // Don't include sensitive data
          // Only include minimal necessary user info
          name: req.user.details?.name,
          email: req.user.details?.email,
          image: req.user.details?.image,
        }
      });
    } catch (error) {
      return res.status(500).json({
        success: false,
        message: "Error validating token"
      });
    }
  }
);

// Admin routes for OTP management
router.get("/admin/pending-otps", auth, getPendingOTPs);
router.post("/admin/mark-otp-sent/:otpId", auth, markOTPSent);

module.exports = router;
