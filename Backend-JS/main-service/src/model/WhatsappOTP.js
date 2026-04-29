const mongoose = require("mongoose");

/**
 * OTP lifecycle:
 *   issued        → row created, otp not yet sent
 *   sent          → isSent=true (Twilio responded OK)
 *   verified      → isVerified=true, verifiedAt set (verifyOTP succeeded)
 *   consumed      → consumedAt set (login/signup completed via this OTP)
 *
 * `purpose` is a soft hint about user intent at issue time only — it must
 * never gate downstream consumption. A verified OTP can be consumed by
 * either login (existing user) or signup (new user) for the same phone, as
 * long as it isn't already consumed and isn't past the verification window.
 */
const whatsappOTPSchema = new mongoose.Schema(
  {
    phoneNo: {
      type: String,
      required: true,
      index: true,
    },
    otp: {
      type: String,
      required: true,
    },
    whatsappUrl: {
      type: String,
      required: true,
    },
    isSent: {
      type: Boolean,
      default: false,
    },
    isVerified: {
      type: Boolean,
      default: false,
    },
    verifiedAt: {
      type: Date,
    },
    consumedAt: {
      type: Date,
    },
    purpose: {
      type: String,
      enum: ["login", "signup"],
      required: true,
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model("WhatsAppOTP", whatsappOTPSchema);
