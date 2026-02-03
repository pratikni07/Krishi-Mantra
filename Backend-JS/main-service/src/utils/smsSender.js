const twilio = require('twilio');
const logger = require('./logger');

// Initialize Twilio client
const getTwilioClient = () => {
  const accountSid = process.env.TWILIO_ACCOUNT_SID;
  const authToken = process.env.TWILIO_AUTH_TOKEN;

  if (!accountSid || !authToken) {
    throw new Error('Twilio credentials are not configured');
  }

  return twilio(accountSid, authToken);
};

/**
 * Send SMS using Twilio
 * @param {string} phoneNo - Phone number (10 digits without country code)
 * @param {string} message - SMS message content
 * @returns {Promise<Object>} - Twilio message response
 */
const sendSMS = async (phoneNo, message) => {
  try {
    const client = getTwilioClient();
    const twilioPhoneNumber = process.env.TWILIO_PHONE_NUMBER;

    if (!twilioPhoneNumber) {
      throw new Error('Twilio phone number is not configured');
    }

    // Format phone number with India country code (+91)
    const formattedPhoneNo = phoneNo.startsWith('+') ? phoneNo : `+91${phoneNo}`;

    const response = await client.messages.create({
      body: message,
      from: twilioPhoneNumber,
      to: formattedPhoneNo,
    });

    logger.info(`SMS sent successfully to ${formattedPhoneNo}. SID: ${response.sid}`);

    return {
      success: true,
      sid: response.sid,
      status: response.status,
    };
  } catch (error) {
    logger.error(`Failed to send SMS to ${phoneNo}:`, error.message);
    throw error;
  }
};

/**
 * Send OTP via SMS
 * @param {string} phoneNo - Phone number (10 digits without country code)
 * @param {string} otp - OTP to send
 * @returns {Promise<Object>} - Twilio message response
 */
const sendOTP = async (phoneNo, otp) => {
  const message = `Your Krishi Mantra verification code is: ${otp}. This code expires in 10 minutes. Do not share this code with anyone.`;
  return sendSMS(phoneNo, message);
};

module.exports = {
  sendSMS,
  sendOTP,
};
