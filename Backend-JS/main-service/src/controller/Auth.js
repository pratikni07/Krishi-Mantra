const axios = require('axios');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const otpGenerator = require('otp-generator');

const User = require('../model/User');
const UserDetail = require('../model/UserDetail');
const WhatsAppOTP = require('../model/WhatsappOTP');
const mailSender = require('../utils/mailSender');
const { sendOTP: sendSMSOTP } = require('../utils/smsSender');
const { passwordUpdated } = require('../mail/templates/passwordUpdate');
const { asyncHandler } = require('../utils');
const { HTTP_STATUS, JWT_CONFIG, OTP_CONFIG } = require('../utils/constants');
const logger = require('../utils/logger');

/**
 * Generate JWT token
 * @param {Object} payload - Token payload
 * @returns {string} - JWT token
 */
const generateToken = (payload) => {
  return jwt.sign(payload, process.env.JWT_SECRET, {
    expiresIn: JWT_CONFIG.ACCESS_TOKEN_EXPIRY,
  });
};

/**
 * Get cookie options
 * @returns {Object} - Cookie options
 */
const getCookieOptions = () => ({
  expires: new Date(Date.now() + JWT_CONFIG.COOKIE_EXPIRY_DAYS * 24 * 60 * 60 * 1000),
  httpOnly: true,
  secure: process.env.NODE_ENV === 'production',
  sameSite: 'strict',
});

/**
 * Change user password
 */
exports.changePassword = asyncHandler(async (req, res) => {
  const { oldPassword, newPassword, confirmNewPassword } = req.body;

  // Get user
  const user = await User.findById(req.user.id);
  if (!user) {
    return res.status(HTTP_STATUS.NOT_FOUND).json({
      success: false,
      message: 'User not found',
    });
  }

  // Validate old password
  const isPasswordMatch = await bcrypt.compare(oldPassword, user.password);
  if (!isPasswordMatch) {
    return res.status(HTTP_STATUS.UNAUTHORIZED).json({
      success: false,
      message: 'Current password is incorrect',
    });
  }

  // Check if new password is same as old
  if (oldPassword === newPassword) {
    return res.status(HTTP_STATUS.BAD_REQUEST).json({
      success: false,
      message: 'New password cannot be the same as current password',
    });
  }

  // Validate password match
  if (newPassword !== confirmNewPassword) {
    return res.status(HTTP_STATUS.BAD_REQUEST).json({
      success: false,
      message: 'New password and confirm password do not match',
    });
  }

  // Update password
  const hashedPassword = await bcrypt.hash(newPassword, 10);
  await User.findByIdAndUpdate(req.user.id, { password: hashedPassword });

  // Send notification email (non-blocking)
  if (user.email) {
    mailSender(
      user.email,
      'Password Updated Successfully',
      passwordUpdated(user.email, `Password updated for ${user.name}`)
    ).catch((err) => logger.error('Failed to send password update email:', err));
  }

  return res.status(HTTP_STATUS.OK).json({
    success: true,
    message: 'Password updated successfully',
  });
});

/**
 * Find user IP and update location
 */
exports.findUserIp = asyncHandler(async (req, res) => {
  const ip = req.query.ip || req.ip || req.connection?.remoteAddress;
  const userId = req.query.userId;

  // Fetch location data
  const response = await axios.get(`http://www.geoplugin.net/json.gp?ip=${ip}`);
  const locationData = response.data;

  const latitude = parseFloat(locationData.geoplugin_latitude);
  const longitude = parseFloat(locationData.geoplugin_longitude);
  const city = locationData.geoplugin_city;

  // If user is logged in, update their location
  if (userId) {
    const user = await User.findById(userId);
    if (!user) {
      return res.status(HTTP_STATUS.NOT_FOUND).json({
        success: false,
        message: 'User not found',
      });
    }

    let userDetail = await UserDetail.findOne({ userId });
    if (!userDetail) {
      userDetail = new UserDetail({ userId });
    }

    userDetail.location = {
      type: 'Point',
      coordinates: [longitude, latitude],
    };
    userDetail.address = city;
    await userDetail.save();

    user.location = userDetail.location;
    await user.save();

    return res.status(HTTP_STATUS.OK).json({
      success: true,
      message: 'User location updated successfully',
      location: userDetail.location,
    });
  }

  // Return location for non-logged-in users
  return res.status(HTTP_STATUS.OK).json({
    success: true,
    location: {
      latitude,
      longitude,
      city,
    },
  });
});

/**
 * Initiate phone authentication
 */
exports.initiateAuth = asyncHandler(async (req, res) => {
  const { phoneNo } = req.body;

  if (!phoneNo) {
    return res.status(HTTP_STATUS.BAD_REQUEST).json({
      success: false,
      message: 'Phone number is required',
    });
  }

  // Validate phone number format (10 digits)
  const phoneRegex = /^[6-9]\d{9}$/;
  if (!phoneRegex.test(phoneNo)) {
    return res.status(HTTP_STATUS.BAD_REQUEST).json({
      success: false,
      message: 'Invalid phone number. Please enter a valid 10-digit Indian mobile number.',
    });
  }

  // Check if user exists
  const existingUser = await User.findOne({ phoneNo });
  const isRegistered = !!existingUser;

  // Generate OTP
  const otp = otpGenerator.generate(OTP_CONFIG.LENGTH, {
    upperCaseAlphabets: false,
    lowerCaseAlphabets: false,
    specialChars: false,
  });

  const whatsappText = encodeURIComponent(`Your OTP is ${otp}`);
  const whatsappUrl = `https://wa.me/91${phoneNo}?text=${whatsappText}`;

  // Save OTP to database
  const otpRecord = await WhatsAppOTP.create({
    phoneNo,
    otp,
    whatsappUrl,
    purpose: isRegistered ? 'login' : 'signup',
  });

  // Send OTP via Twilio SMS
  let smsSent = false;
  try {
    await sendSMSOTP(phoneNo, otp);
    smsSent = true;
    // Mark OTP as sent
    otpRecord.isSent = true;
    await otpRecord.save();
    logger.info(`OTP sent via SMS to ${phoneNo}`);
  } catch (smsError) {
    logger.error(`Failed to send OTP via SMS to ${phoneNo}:`, smsError.message);
    // SMS failed but OTP is still saved, admin can manually send if needed
  }

  return res.status(HTTP_STATUS.OK).json({
    success: true,
    message: smsSent ? 'OTP sent to your phone number' : 'Authentication initiated. OTP will be sent shortly.',
    isRegistered,
    phoneNo,
    smsSent,
  });
});

/**
 * Get pending OTPs (Admin)
 */
exports.getPendingOTPs = asyncHandler(async (req, res) => {
  const pendingOTPs = await WhatsAppOTP.find({ isSent: false })
    .sort({ createdAt: -1 })
    .limit(50)
    .lean();

  return res.status(HTTP_STATUS.OK).json({
    success: true,
    data: pendingOTPs,
  });
});

/**
 * Mark OTP as sent (Admin)
 */
exports.markOTPSent = asyncHandler(async (req, res) => {
  const { otpId } = req.params;

  const otpRecord = await WhatsAppOTP.findByIdAndUpdate(
    otpId,
    { isSent: true },
    { new: true }
  );

  if (!otpRecord) {
    return res.status(HTTP_STATUS.NOT_FOUND).json({
      success: false,
      message: 'OTP record not found',
    });
  }

  return res.status(HTTP_STATUS.OK).json({
    success: true,
    message: 'OTP marked as sent',
    data: otpRecord,
  });
});

/**
 * Verify OTP
 */
exports.verifyOTP = asyncHandler(async (req, res) => {
  const { phoneNo, otp } = req.body;

  // Debug logging
  console.log('=== VERIFY OTP DEBUG ===');
  console.log('req.body:', JSON.stringify(req.body));
  console.log('phoneNo:', phoneNo, 'type:', typeof phoneNo);
  console.log('otp:', otp, 'type:', typeof otp);

  if (!phoneNo || !otp) {
    console.log('Missing phoneNo or otp');
    return res.status(HTTP_STATUS.BAD_REQUEST).json({
      success: false,
      message: 'Phone number and OTP are required',
    });
  }

  // Find the most recent OTP (skip isSent check in development)
  const query = process.env.NODE_ENV === 'development'
    ? { phoneNo }
    : { phoneNo, isSent: true };

  const recentOtp = await WhatsAppOTP.findOne(query)
    .sort({ createdAt: -1 });

  console.log('Found OTP in DB:', recentOtp ? { otp: recentOtp.otp, isSent: recentOtp.isSent, isVerified: recentOtp.isVerified } : 'null');

  if (!recentOtp) {
    console.log('No OTP found for phoneNo:', phoneNo);
    return res.status(HTTP_STATUS.BAD_REQUEST).json({
      success: false,
      message: 'No OTP found. Please request a new one.',
    });
  }

  // Check OTP expiry (10 minutes)
  const otpAge = Date.now() - new Date(recentOtp.createdAt).getTime();
  if (otpAge > OTP_CONFIG.EXPIRY_MINUTES * 60 * 1000) {
    return res.status(HTTP_STATUS.BAD_REQUEST).json({
      success: false,
      message: 'OTP has expired. Please request a new one.',
    });
  }

  // Verify OTP
  if (recentOtp.otp !== otp) {
    return res.status(HTTP_STATUS.BAD_REQUEST).json({
      success: false,
      message: 'Invalid OTP. Please try again.',
    });
  }

  // Mark OTP as verified
  recentOtp.isVerified = true;
  await recentOtp.save();

  // Check if user exists
  const user = await User.findOne({ phoneNo }).populate('additionalDetails');

  if (user) {
    // Existing user - login
    const token = generateToken({
      phoneNo: user.phoneNo,
      id: user._id,
      accountType: user.accountType,
    });

    const userResponse = user.toObject();
    delete userResponse.password;
    userResponse.token = token;

    return res.cookie('token', token, getCookieOptions())
      .status(HTTP_STATUS.OK)
      .json({
        success: true,
        token,
        user: userResponse,
        message: 'Login successful',
      });
  }

  // New user - needs registration
  return res.status(HTTP_STATUS.OK).json({
    success: true,
    isRegistered: false,
    message: 'Phone number verified. Please complete registration.',
    phoneNo,
  });
});

/**
 * Signup with phone
 */
exports.signupWithPhone = asyncHandler(async (req, res) => {
  const { name, firstName, lastName, phoneNo, image } = req.body;

  // Validate required fields
  if (!name || !phoneNo) {
    return res.status(HTTP_STATUS.BAD_REQUEST).json({
      success: false,
      message: 'Name and Phone Number are required',
    });
  }

  // Verify phone was OTP-verified recently
  const verifiedOtp = await WhatsAppOTP.findOne({
    phoneNo,
    isVerified: true,
    purpose: 'signup',
    createdAt: { $gt: new Date(Date.now() - 30 * 60 * 1000) },
  }).sort({ createdAt: -1 });

  if (!verifiedOtp) {
    return res.status(HTTP_STATUS.BAD_REQUEST).json({
      success: false,
      message: 'Phone verification required before signup.',
    });
  }

  // Check if user already exists
  const existingUser = await User.findOne({ phoneNo });
  if (existingUser) {
    return res.status(HTTP_STATUS.CONFLICT).json({
      success: false,
      message: 'User already exists with this phone number',
    });
  }

  // Create user details
  const profileDetails = await UserDetail.create({});

  // Create user
  const user = await User.create({
    name,
    firstName: firstName || '',
    lastName: lastName || '',
    phoneNo,
    additionalDetails: profileDetails._id,
    image: image || `https://api.dicebear.com/6.x/initials/png?seed=${encodeURIComponent(name)}&backgroundColor=00897b,00acc1,039be5&backgroundType=solid`,
  });

  // Link profile to user
  profileDetails.userId = user._id;
  await profileDetails.save();

  // Generate token
  const token = generateToken({
    name: user.name,
    firstName: user.firstName,
    lastName: user.lastName,
    phoneNo: user.phoneNo,
    id: user._id,
    accountType: user.accountType,
    image: user.image,
  });

  const userResponse = user.toObject();
  delete userResponse.password;

  return res.cookie('token', token, getCookieOptions())
    .status(HTTP_STATUS.CREATED)
    .json({
      success: true,
      token,
      user: userResponse,
      message: 'User registered successfully.',
    });
});

/**
 * Admin login
 */
exports.adminLogin = asyncHandler(async (req, res) => {
  const { email, password } = req.body;

  // Validate input
  if (!email || !password) {
    return res.status(HTTP_STATUS.BAD_REQUEST).json({
      success: false,
      message: 'Email and password are required',
    });
  }

  // Find admin or marketplace user (include password field for verification)
  const admin = await User.findOne({ email, accountType: { $in: ['admin', 'marketplace'] } })
    .select('+password')
    .populate('additionalDetails');

  if (!admin) {
    return res.status(HTTP_STATUS.UNAUTHORIZED).json({
      success: false,
      message: 'Invalid credentials or unauthorized access',
    });
  }

  // Verify password exists
  if (!admin.password) {
    return res.status(HTTP_STATUS.UNAUTHORIZED).json({
      success: false,
      message: 'Please use the password reset flow to set up your password',
    });
  }

  // Verify password
  const isPasswordValid = await bcrypt.compare(password, admin.password);
  if (!isPasswordValid) {
    return res.status(HTTP_STATUS.UNAUTHORIZED).json({
      success: false,
      message: 'Invalid credentials',
    });
  }

  // Generate token
  const token = generateToken({
    email: admin.email,
    id: admin._id,
    accountType: admin.accountType,
  });

  const adminResponse = admin.toObject();
  delete adminResponse.password;
  adminResponse.token = token;

  return res.cookie('token', token, getCookieOptions())
    .status(HTTP_STATUS.OK)
    .json({
      success: true,
      token,
      user: adminResponse,
      admin: adminResponse,
      message: 'Admin logged in successfully',
    });
});
