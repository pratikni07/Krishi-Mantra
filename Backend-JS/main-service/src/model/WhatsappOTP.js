const mongoose = require("mongoose");

const whatsappOTPSchema = new mongoose.Schema(
  {
    phoneNo: {
      type: String,
      required: true,
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
    purpose: {
      type: String,
      enum: ["login", "signup"],
      required: true,
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model("WhatsAppOTP", whatsappOTPSchema);
