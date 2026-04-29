const User = require('../model/User');
const UserDetail = require('../model/UserDetail');
const { asyncHandler } = require('../utils');
const { HTTP_STATUS, PAGINATION } = require('../utils/constants');

const getDefaultDeviceAccess = () => ({
  pump: {
    purchased: false,
    enabled: false,
  },
  krishiDoctor: {
    purchased: false,
    enabled: false,
  },
});


/**
 * Update user profile
 */
exports.updateUserProfile = asyncHandler(async (req, res) => {
  const userId = req.user.id || req.user._id;
  const { name, firstName, lastName, phoneNo, image } = req.body;

  if (!userId) {
    return res.status(HTTP_STATUS.BAD_REQUEST).json({
      success: false,
      message: 'User ID is required',
    });
  }

  const updatedUser = await User.findByIdAndUpdate(
    userId,
    { name, firstName, lastName, phoneNo, image },
    { new: true, runValidators: true }
  ).select('-password');

  if (!updatedUser) {
    return res.status(HTTP_STATUS.NOT_FOUND).json({
      success: false,
      message: 'User not found',
    });
  }

  return res.status(HTTP_STATUS.OK).json({
    success: true,
    message: 'User profile updated successfully',
    user: updatedUser,
  });
});

/**
 * Update user additional details
 */
exports.updateUserDetails = asyncHandler(async (req, res) => {
  const userId = req.user.id || req.user._id;
  const { address, location, interests, profilePic } = req.body;

  let userDetails = await UserDetail.findOne({ userId });

  if (!userDetails) {
    userDetails = new UserDetail({
      userId,
      address,
      location,
      interests,
      profilePic,
    });
  } else {
    if (address !== undefined) userDetails.address = address;
    if (location !== undefined) userDetails.location = location;
    if (interests !== undefined) userDetails.interests = interests;
    if (profilePic !== undefined) userDetails.profilePic = profilePic;
  }

  await userDetails.save();

  // Update user's additional details reference
  await User.findByIdAndUpdate(userId, {
    additionalDetails: userDetails._id,
  });

  return res.status(HTTP_STATUS.OK).json({
    success: true,
    message: 'User details updated successfully',
    userDetails,
  });
});

/**
 * Update user subscription
 */
exports.updateSubscription = asyncHandler(async (req, res) => {
  const userId = req.user.id || req.user._id;
  const { subscriptionType, transactionDetails, endDate } = req.body;

  const userDetails = await UserDetail.findOne({ userId });

  if (!userDetails) {
    return res.status(HTTP_STATUS.NOT_FOUND).json({
      success: false,
      message: 'User details not found',
    });
  }

  userDetails.subscription = {
    type: subscriptionType || userDetails.subscription?.type || 'FREE',
    transactionDetails: transactionDetails || userDetails.subscription?.transactionDetails,
    endDate: endDate || userDetails.subscription?.endDate,
    purchasedDate: new Date(),
  };

  await userDetails.save();

  return res.status(HTTP_STATUS.OK).json({
    success: true,
    message: 'Subscription updated successfully',
    subscription: userDetails.subscription,
  });
});

/**
 * Get users with pagination
 */
exports.getUserByPage = asyncHandler(async (req, res) => {
  const page = parseInt(req.query.page, 10) || PAGINATION.DEFAULT_PAGE;
  const limit = Math.min(
    parseInt(req.query.limit, 10) || PAGINATION.DEFAULT_LIMIT,
    PAGINATION.MAX_LIMIT
  );
  const skip = (page - 1) * limit;

  const [users, totalUsers] = await Promise.all([
    User.find()
      .populate('additionalDetails')
      .skip(skip)
      .limit(limit)
      .select('-password')
      .lean(),
    User.countDocuments(),
  ]);

  const formattedUsers = users.map((user) => ({
    _id: user._id,
    name: user.name,
    firstName: user.firstName,
    lastName: user.lastName,
    phoneNo: user.phoneNo,
    accountType: user.accountType,
    image: user.image,
    additionalDetails: {
      subscription: user.additionalDetails?.subscription,
      deviceAccess: user.additionalDetails?.deviceAccess || getDefaultDeviceAccess(),
      location: user.additionalDetails?.location,
      address: user.additionalDetails?.address,
    },
    createdAt: user.createdAt,
    updatedAt: user.updatedAt,
  }));

  return res.status(HTTP_STATUS.OK).json({
    success: true,
    users: formattedUsers,
    pagination: {
      currentPage: page,
      totalPages: Math.ceil(totalUsers / limit),
      totalUsers,
      hasNextPage: page * limit < totalUsers,
      hasPreviousPage: page > 1,
    },
  });
});

/**
 * Internal: lightweight account-type lookup. Returns just `{ accountType }`
 * for service-to-service calls (e.g. message-svc detecting whether a chat
 * participant is a consultant). Cheap, no populate, no PII.
 */
exports.getAccountTypeInternal = asyncHandler(async (req, res) => {
  const { id } = req.params;
  if (!id) {
    return res.status(HTTP_STATUS.BAD_REQUEST).json({
      success: false,
      message: 'User id required',
    });
  }
  const user = await User.findById(id).select('accountType').lean();
  if (!user) {
    return res.status(HTTP_STATUS.NOT_FOUND).json({
      success: false,
      message: 'User not found',
    });
  }
  return res.status(HTTP_STATUS.OK).json({
    success: true,
    accountType: user.accountType,
  });
});

/**
 * Get user by ID
 */
exports.getUserById = asyncHandler(async (req, res) => {
  const { userId } = req.body;

  if (!userId) {
    return res.status(HTTP_STATUS.BAD_REQUEST).json({
      success: false,
      message: 'User ID is required',
    });
  }

  const user = await User.findById(userId)
    .populate('additionalDetails')
    .select('-password')
    .lean();

  if (!user) {
    return res.status(HTTP_STATUS.NOT_FOUND).json({
      success: false,
      message: 'User not found',
    });
  }

  return res.status(HTTP_STATUS.OK).json({
    success: true,
    user,
    message: 'User found',
  });
});

/**
 * Get all consultants
 */
exports.getConsultant = asyncHandler(async (req, res) => {
  const consultants = await User.find({ accountType: 'consultant' })
    .populate('additionalDetails')
    .select('-password')
    .lean();

  const formattedConsultants = consultants
    .filter(Boolean)
    .map((consultant) => ({
      _id: consultant._id,
      userName: consultant.name || null,
      firstName: consultant.firstName || null,
      lastName: consultant.lastName || null,
      profilePhotoId: consultant.image || null,
      phoneNo: consultant.phoneNo || null,
      experience: consultant.additionalDetails?.experience || null,
      rating: consultant.additionalDetails?.rating || null,
      company: consultant.additionalDetails?.company
        ? {
            name: consultant.additionalDetails.company.name,
            logo: consultant.additionalDetails.company.logo,
          }
        : null,
    }));

  return res.status(HTTP_STATUS.OK).json({
    success: true,
    consultants: formattedConsultants,
    message: 'Consultants found',
  });
});

/**
 * Get user by username
 */
exports.getUserByUsername = asyncHandler(async (req, res) => {
  const { username } = req.params;

  if (!username) {
    return res.status(HTTP_STATUS.BAD_REQUEST).json({
      success: false,
      message: 'Username is required',
    });
  }

  const user = await User.findOne({ name: username })
    .populate('additionalDetails')
    .select('-password')
    .lean();

  if (!user) {
    return res.status(HTTP_STATUS.NOT_FOUND).json({
      success: false,
      message: 'User not found with the provided username',
    });
  }

  return res.status(HTTP_STATUS.OK).json({
    success: true,
    data: user,
  });
});

/**
 * Search users by partial username
 */
exports.searchUsersByPartialUsername = asyncHandler(async (req, res) => {
  const { prefix } = req.query;

  if (!prefix || prefix.length < 2) {
    return res.status(HTTP_STATUS.BAD_REQUEST).json({
      success: false,
      message: 'Please provide at least 2 characters for search',
    });
  }

  // Escape special regex characters to prevent injection
  const escapedPrefix = prefix.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const searchRegex = new RegExp(`^${escapedPrefix}`, 'i');

  const users = await User.find({ name: searchRegex })
    .select('name image accountType')
    .limit(10)
    .lean();

  return res.status(HTTP_STATUS.OK).json({
    success: true,
    data: users,
  });
});


/**
 * Admin: update user IoT device purchase/enable state
 */
exports.updateUserDeviceAccess = asyncHandler(async (req, res) => {
  const { userId } = req.params;
  const { deviceAccess } = req.body;

  if (!userId) {
    return res.status(HTTP_STATUS.BAD_REQUEST).json({
      success: false,
      message: 'User ID is required',
    });
  }

  if (!deviceAccess) {
    return res.status(HTTP_STATUS.BAD_REQUEST).json({
      success: false,
      message: 'deviceAccess payload is required',
    });
  }

  let userDetails = await UserDetail.findOne({ userId });

  if (!userDetails) {
    userDetails = new UserDetail({ userId });
  }

  const currentAccess = userDetails.deviceAccess || getDefaultDeviceAccess();

  userDetails.deviceAccess = {
    pump: {
      purchased: deviceAccess.pump?.purchased !== undefined
        ? Boolean(deviceAccess.pump.purchased)
        : Boolean(currentAccess.pump?.purchased),
      enabled: deviceAccess.pump?.enabled !== undefined
        ? Boolean(deviceAccess.pump.enabled)
        : Boolean(currentAccess.pump?.enabled),
    },
    krishiDoctor: {
      purchased: deviceAccess.krishiDoctor?.purchased !== undefined
        ? Boolean(deviceAccess.krishiDoctor.purchased)
        : Boolean(currentAccess.krishiDoctor?.purchased),
      enabled: deviceAccess.krishiDoctor?.enabled !== undefined
        ? Boolean(deviceAccess.krishiDoctor.enabled)
        : Boolean(currentAccess.krishiDoctor?.enabled),
    },
  };

  await userDetails.save();

  await User.findByIdAndUpdate(userId, {
    additionalDetails: userDetails._id,
  });

  return res.status(HTTP_STATUS.OK).json({
    success: true,
    message: 'User device access updated successfully',
    deviceAccess: userDetails.deviceAccess,
  });
});
