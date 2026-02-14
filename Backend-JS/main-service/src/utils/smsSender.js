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

// OTP message templates in different languages (farmer-friendly)
const otpMessages = {
  en: (otp) => `🌾 Krishi Mantra - Your OTP is: ${otp}

This code is valid for 10 minutes.
Do not share with anyone.

Jai Jawan, Jai Kisan! 🇮🇳`,

  hi: (otp) => `🌾 कृषि मंत्र - आपका OTP है: ${otp}

यह कोड 10 मिनट के लिए मान्य है।
किसी के साथ साझा न करें।

जय जवान, जय किसान! 🇮🇳`,

  mr: (otp) => `🌾 कृषी मंत्र - तुमचा OTP आहे: ${otp}

हा कोड 10 मिनिटांसाठी वैध आहे.
कोणाशीही शेअर करू नका.

जय जवान, जय किसान! 🇮🇳`,

  gu: (otp) => `🌾 કૃષિ મંત્ર - તમારો OTP છે: ${otp}

આ કોડ 10 મિનિટ માટે માન્ય છે.
કોઈની સાથે શેર કરશો નહીં.

જય જવાન, જય કિસાન! 🇮🇳`,

  pa: (otp) => `🌾 ਕ੍ਰਿਸ਼ੀ ਮੰਤਰ - ਤੁਹਾਡਾ OTP ਹੈ: ${otp}

ਇਹ ਕੋਡ 10 ਮਿੰਟਾਂ ਲਈ ਵੈਧ ਹੈ।
ਕਿਸੇ ਨਾਲ ਸਾਂਝਾ ਨਾ ਕਰੋ।

ਜੈ ਜਵਾਨ, ਜੈ ਕਿਸਾਨ! 🇮🇳`,

  te: (otp) => `🌾 కృషి మంత్ర - మీ OTP: ${otp}

ఈ కోడ్ 10 నిమిషాలు చెల్లుబాటు అవుతుంది.
ఎవరితోనూ షేర్ చేయకండి.

జై జవాన్, జై కిసాన్! 🇮🇳`,

  ta: (otp) => `🌾 கிருஷி மந்திரா - உங்கள் OTP: ${otp}

இந்த குறியீடு 10 நிமிடங்களுக்கு செல்லுபடியாகும்.
யாருடனும் பகிர்ந்து கொள்ளாதீர்கள்.

ஜெய் ஜவான், ஜெய் கிசான்! 🇮🇳`,

  kn: (otp) => `🌾 ಕೃಷಿ ಮಂತ್ರ - ನಿಮ್ಮ OTP: ${otp}

ಈ ಕೋಡ್ 10 ನಿಮಿಷಗಳವರೆಗೆ ಮಾನ್ಯವಾಗಿದೆ.
ಯಾರೊಂದಿಗೂ ಹಂಚಿಕೊಳ್ಳಬೇಡಿ.

ಜೈ ಜವಾನ್, ಜೈ ಕಿಸಾನ್! 🇮🇳`,

  bn: (otp) => `🌾 কৃষি মন্ত্র - আপনার OTP: ${otp}

এই কোডটি 10 মিনিটের জন্য বৈধ।
কারো সাথে শেয়ার করবেন না।

জয় জওয়ান, জয় কিষাণ! 🇮🇳`,

  or: (otp) => `🌾 କୃଷି ମନ୍ତ୍ର - ଆପଣଙ୍କ OTP: ${otp}

ଏହି କୋଡ୍ 10 ମିନିଟ୍ ପାଇଁ ବୈଧ।
କାହା ସହ ଅଂଶୀଦାର କରନ୍ତୁ ନାହିଁ।

ଜୟ ଜୱାନ, ଜୟ କିଷାଣ! 🇮🇳`,
};

/**
 * Get OTP message in specified language
 * @param {string} otp - OTP code
 * @param {string} language - Language code (en, hi, mr, gu, pa, te, ta, kn, bn, or)
 * @returns {string} - Localized OTP message
 */
const getOTPMessage = (otp, language = 'en') => {
  // Default to Hindi if language not supported (most common for farmers)
  const messageTemplate = otpMessages[language] || otpMessages['hi'];
  return messageTemplate(otp);
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
 * Send OTP via SMS with language support
 * @param {string} phoneNo - Phone number (10 digits without country code)
 * @param {string} otp - OTP to send
 * @param {string} language - Language code (default: 'hi' for Hindi)
 * @returns {Promise<Object>} - Twilio message response
 */
const sendOTP = async (phoneNo, otp, language = 'hi') => {
  const message = getOTPMessage(otp, language);
  return sendSMS(phoneNo, message);
};

module.exports = {
  sendSMS,
  sendOTP,
  getOTPMessage,
};
