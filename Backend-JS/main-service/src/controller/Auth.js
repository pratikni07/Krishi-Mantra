const axios = require('axios');
const bcrypt = require('bcrypt');
const crypto = require('crypto');
const jwt = require('jsonwebtoken');
const otpGenerator = require('otp-generator');

const User = require('../model/User');
const UserDetail = require('../model/UserDetail');
const WhatsAppOTP = require('../model/WhatsappOTP');
const RefreshToken = require('../model/RefreshToken');
const mailSender = require('../utils/mailSender');
const { sendOTP: sendSMSOTP } = require('../utils/smsSender');
const { passwordUpdated } = require('../mail/templates/passwordUpdate');
const { asyncHandler } = require('../utils');
const { HTTP_STATUS, JWT_CONFIG, OTP_CONFIG } = require('../utils/constants');
const logger = require('../utils/logger');
const otpRateLimit = require('../utils/otpRateLimit');

/**
 * Parse a duration string like "30d" into milliseconds.
 */
const durationToMs = (d) => {
  const m = /^(\d+)([smhd])$/.exec(d);
  if (!m) throw new Error(`Invalid duration: ${d}`);
  const n = parseInt(m[1], 10);
  const unit = { s: 1000, m: 60000, h: 3600000, d: 86400000 }[m[2]];
  return n * unit;
};

/**
 * Generate short-lived access token.
 */
const generateToken = (payload) => {
  return jwt.sign(payload, process.env.JWT_SECRET, {
    expiresIn: JWT_CONFIG.ACCESS_TOKEN_EXPIRY,
  });
};

/**
 * Issue a new access+refresh token pair for a user and persist the
 * refresh token's hash. Returns { token, refreshToken, refreshTokenId }.
 *
 * The refresh token itself is a signed JWT with a random jti so two
 * tokens can never collide on the `tokenHash` unique index.
 */
const issueTokenPair = async (user, accessPayload, req = null) => {
  const token = generateToken(accessPayload);

  const jti = crypto.randomBytes(16).toString('hex');
  const refreshToken = jwt.sign(
    { id: user._id, type: 'refresh', jti },
    process.env.JWT_SECRET,
    { expiresIn: JWT_CONFIG.REFRESH_TOKEN_EXPIRY }
  );

  const stored = await RefreshToken.create({
    userId: user._id,
    tokenHash: RefreshToken.hashToken(refreshToken),
    expiresAt: new Date(Date.now() + durationToMs(JWT_CONFIG.REFRESH_TOKEN_EXPIRY)),
    userAgent: req?.get?.('user-agent'),
    ip: req?.ip,
  });

  return { token, refreshToken, refreshTokenId: stored._id };
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
  const { phoneNo, language = 'hi' } = req.body; // Default to Hindi

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

  // Per-phone rate limit. Blocks rotating-IP attackers from burning
  // through SMS quota or guessing OTPs for a single number.
  const gate = await otpRateLimit.checkAndConsume('initiate', phoneNo);
  if (!gate.allowed) {
    res.set('Retry-After', String(gate.retryAfterSec));
    return res.status(HTTP_STATUS.TOO_MANY_REQUESTS || 429).json({
      success: false,
      message: 'Too many OTP requests for this number. Please try again later.',
    });
  }

  // Check if user exists - if exists, use their saved language preference
  const existingUser = await User.findOne({ phoneNo });
  const isRegistered = !!existingUser;

  // Use user's saved language if available, otherwise use the provided language
  const userLanguage = existingUser?.additionalDetails?.language || language;

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
    await sendSMSOTP(phoneNo, otp, userLanguage);
    smsSent = true;
    // Mark OTP as sent
    otpRecord.isSent = true;
    await otpRecord.save();
    logger.info(`OTP sent via SMS to ${phoneNo} in ${userLanguage}`);
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



  if (!phoneNo || !otp) {

    return res.status(HTTP_STATUS.BAD_REQUEST).json({
      success: false,
      message: 'Phone number and OTP are required',
    });
  }

  // Per-phone verify-attempt limit. Defense against brute-forcing the
  // 6-digit OTP across many IPs within the OTP's 10-minute validity.
  const gate = await otpRateLimit.checkAndConsume('verify', phoneNo);
  if (!gate.allowed) {
    res.set('Retry-After', String(gate.retryAfterSec));
    return res.status(HTTP_STATUS.TOO_MANY_REQUESTS || 429).json({
      success: false,
      message: 'Too many verification attempts for this number. Please try again later.',
    });
  }

  // Find the most recent OTP (skip isSent check in development)
  const query = process.env.NODE_ENV === 'development'
    ? { phoneNo }
    : { phoneNo, isSent: true };

  const recentOtp = await WhatsAppOTP.findOne(query)
    .sort({ createdAt: -1 });



  if (!recentOtp) {

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
    const { token, refreshToken } = await issueTokenPair(
      user,
      {
        phoneNo: user.phoneNo,
        id: user._id,
        accountType: user.accountType,
      },
      req
    );

    const userResponse = user.toObject();
    delete userResponse.password;
    userResponse.token = token;

    return res.cookie('token', token, getCookieOptions())
      .status(HTTP_STATUS.OK)
      .json({
        success: true,
        token,
        refreshToken,
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

  // Generate token pair
  const { token, refreshToken } = await issueTokenPair(
    user,
    {
      name: user.name,
      firstName: user.firstName,
      lastName: user.lastName,
      phoneNo: user.phoneNo,
      id: user._id,
      accountType: user.accountType,
      image: user.image,
    },
    req
  );

  const userResponse = user.toObject();
  delete userResponse.password;

  return res.cookie('token', token, getCookieOptions())
    .status(HTTP_STATUS.CREATED)
    .json({
      success: true,
      token,
      refreshToken,
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

  // Generate token pair
  const { token, refreshToken } = await issueTokenPair(
    admin,
    {
      email: admin.email,
      id: admin._id,
      accountType: admin.accountType,
    },
    req
  );

  const adminResponse = admin.toObject();
  delete adminResponse.password;
  adminResponse.token = token;

  return res.cookie('token', token, getCookieOptions())
    .status(HTTP_STATUS.OK)
    .json({
      success: true,
      token,
      refreshToken,
      user: adminResponse,
      admin: adminResponse,
      message: 'Admin logged in successfully',
    });
});

/**
 * Rotate a refresh token. Validates the presented refresh token, issues
 * a new pair, marks the old one revoked, and points `replacedBy` at the
 * new entry. If the presented token was already revoked we treat it as
 * a replay attack and revoke every outstanding refresh token for that
 * user so an attacker can't keep refreshing alongside the real user.
 */
exports.refreshToken = asyncHandler(async (req, res) => {
  const presented = req.body?.refreshToken;
  if (!presented) {
    return res.status(HTTP_STATUS.UNAUTHORIZED).json({
      success: false,
      message: 'Refresh token is required',
    });
  }

  let payload;
  try {
    payload = jwt.verify(presented, process.env.JWT_SECRET);
  } catch (err) {
    return res.status(HTTP_STATUS.UNAUTHORIZED).json({
      success: false,
      message: err.name === 'TokenExpiredError'
        ? 'Refresh token expired'
        : 'Invalid refresh token',
    });
  }

  if (payload.type !== 'refresh') {
    return res.status(HTTP_STATUS.UNAUTHORIZED).json({
      success: false,
      message: 'Not a refresh token',
    });
  }

  const hash = RefreshToken.hashToken(presented);
  const stored = await RefreshToken.findOne({ tokenHash: hash });

  if (!stored) {
    return res.status(HTTP_STATUS.UNAUTHORIZED).json({
      success: false,
      message: 'Refresh token not recognized',
    });
  }

  if (stored.revokedAt) {
    // Replay of a rotated token — treat as theft, nuke the whole family.
    await RefreshToken.updateMany(
      { userId: stored.userId, revokedAt: null },
      { revokedAt: new Date() }
    );
    logger.warn(`Refresh token reuse detected for user ${stored.userId} — all sessions revoked`);
    return res.status(HTTP_STATUS.UNAUTHORIZED).json({
      success: false,
      message: 'Refresh token reuse detected. Please log in again.',
    });
  }

  const user = await User.findById(stored.userId);
  if (!user) {
    return res.status(HTTP_STATUS.UNAUTHORIZED).json({
      success: false,
      message: 'User not found',
    });
  }

  const pair = await issueTokenPair(
    user,
    {
      id: user._id,
      phoneNo: user.phoneNo,
      email: user.email,
      accountType: user.accountType,
    },
    req
  );

  stored.revokedAt = new Date();
  stored.replacedBy = pair.refreshTokenId;
  await stored.save();

  return res.cookie('token', pair.token, getCookieOptions())
    .status(HTTP_STATUS.OK)
    .json({
      success: true,
      token: pair.token,
      refreshToken: pair.refreshToken,
    });
});

/**
 * Revoke the presented refresh token (logout).
 */
exports.logout = asyncHandler(async (req, res) => {
  const presented = req.body?.refreshToken;
  if (presented) {
    const hash = RefreshToken.hashToken(presented);
    await RefreshToken.updateOne(
      { tokenHash: hash, revokedAt: null },
      { revokedAt: new Date() }
    );
  }
  res.clearCookie('token');
  return res.status(HTTP_STATUS.OK).json({ success: true, message: 'Logged out' });
});
