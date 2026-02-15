const DeviceRegistration = require('../model/DeviceRegistration');
const { asyncHandler } = require('../utils');
const { HTTP_STATUS } = require('../utils/constants');
const axios = require('axios');

/**
 * Create a new device registration
 * POST /api/device-registration
 */
exports.createRegistration = asyncHandler(async (req, res) => {
  const { name, phone, email, address, deviceType } = req.body;

  // Validate required fields
  if (!name || !phone || !address || !deviceType) {
    return res.status(HTTP_STATUS.BAD_REQUEST).json({
      success: false,
      message: 'Name, phone, address, and device type are required',
    });
  }

  // Create registration
  const registration = new DeviceRegistration({
    name,
    phone,
    email,
    address,
    deviceType,
  });

  await registration.save();

  return res.status(HTTP_STATUS.CREATED).json({
    success: true,
    message: 'Registration submitted successfully',
    data: registration,
  });
});

/**
 * Get all device registrations (Admin only)
 * GET /api/device-registration/admin
 */
exports.getAllRegistrations = asyncHandler(async (req, res) => {
  const { deviceType, status, page = 1, limit = 20 } = req.query;

  const query = {};
  if (deviceType) query.deviceType = deviceType;
  if (status) query.status = status;

  const skip = (page - 1) * limit;

  const [registrations, total] = await Promise.all([
    DeviceRegistration.find(query)
      .populate('adminReply.repliedBy', 'name email')
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(parseInt(limit))
      .lean(),
    DeviceRegistration.countDocuments(query),
  ]);

  return res.status(HTTP_STATUS.OK).json({
    success: true,
    data: registrations,
    pagination: {
      total,
      page: parseInt(page),
      limit: parseInt(limit),
      pages: Math.ceil(total / limit),
    },
  });
});

/**
 * Get a single device registration by ID (Admin only)
 * GET /api/device-registration/admin/:id
 */
exports.getRegistrationById = asyncHandler(async (req, res) => {
  const { id } = req.params;

  const registration = await DeviceRegistration.findById(id)
    .populate('adminReply.repliedBy', 'name email')
    .lean();

  if (!registration) {
    return res.status(HTTP_STATUS.NOT_FOUND).json({
      success: false,
      message: 'Registration not found',
    });
  }

  return res.status(HTTP_STATUS.OK).json({
    success: true,
    data: registration,
  });
});

/**
 * Update registration status and add admin reply (Admin only)
 * PUT /api/device-registration/admin/:id/reply
 */
exports.replyToRegistration = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { message, status } = req.body;
  const adminId = req.user?._id; // Assuming auth middleware sets req.user

  if (!message) {
    return res.status(HTTP_STATUS.BAD_REQUEST).json({
      success: false,
      message: 'Reply message is required',
    });
  }

  const registration = await DeviceRegistration.findById(id);

  if (!registration) {
    return res.status(HTTP_STATUS.NOT_FOUND).json({
      success: false,
      message: 'Registration not found',
    });
  }

  // Update registration
  registration.adminReply = {
    message,
    repliedAt: new Date(),
    repliedBy: adminId,
  };

  if (status) {
    registration.status = status;
  }

  await registration.save();

  // Send notification to user
  try {
    const notificationServiceUrl = process.env.NOTIFICATION_SERVICE_URL || 'http://localhost:3005';
    
    await axios.post(`${notificationServiceUrl}/api/notifications`, {
      userId: null, // No user ID, using phone number
      title: 'IoT Device Registration Update',
      message: `Your registration for ${registration.deviceType === 'auto_pump' ? 'Auto Pump' : 'Krishi Doctor'} has been reviewed. Reply: ${message}`,
      type: 'device_registration',
      data: {
        registrationId: registration._id,
        deviceType: registration.deviceType,
        phone: registration.phone,
      },
      channels: ['push'],
    });

    registration.notificationSent = true;
    await registration.save();
  } catch (error) {
    console.error('Failed to send notification:', error.message);
    // Continue even if notification fails
  }

  const updatedRegistration = await DeviceRegistration.findById(id)
    .populate('adminReply.repliedBy', 'name email')
    .lean();

  return res.status(HTTP_STATUS.OK).json({
    success: true,
    message: 'Reply sent successfully',
    data: updatedRegistration,
  });
});

/**
 * Update registration status (Admin only)
 * PATCH /api/device-registration/admin/:id/status
 */
exports.updateStatus = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { status, notes } = req.body;

  const validStatuses = ['pending', 'contacted', 'completed', 'cancelled'];
  
  if (!status || !validStatuses.includes(status)) {
    return res.status(HTTP_STATUS.BAD_REQUEST).json({
      success: false,
      message: 'Valid status is required (pending, contacted, completed, cancelled)',
    });
  }

  const registration = await DeviceRegistration.findByIdAndUpdate(
    id,
    { 
      status,
      ...(notes && { notes }),
    },
    { new: true, runValidators: true }
  ).populate('adminReply.repliedBy', 'name email');

  if (!registration) {
    return res.status(HTTP_STATUS.NOT_FOUND).json({
      success: false,
      message: 'Registration not found',
    });
  }

  return res.status(HTTP_STATUS.OK).json({
    success: true,
    message: 'Status updated successfully',
    data: registration,
  });
});

/**
 * Delete a registration (Admin only)
 * DELETE /api/device-registration/admin/:id
 */
exports.deleteRegistration = asyncHandler(async (req, res) => {
  const { id } = req.params;

  const registration = await DeviceRegistration.findByIdAndDelete(id);

  if (!registration) {
    return res.status(HTTP_STATUS.NOT_FOUND).json({
      success: false,
      message: 'Registration not found',
    });
  }

  return res.status(HTTP_STATUS.OK).json({
    success: true,
    message: 'Registration deleted successfully',
  });
});

/**
 * Get registration statistics (Admin only)
 * GET /api/device-registration/admin/stats
 */
exports.getStats = asyncHandler(async (req, res) => {
  const stats = await DeviceRegistration.aggregate([
    {
      $group: {
        _id: '$deviceType',
        total: { $sum: 1 },
        pending: {
          $sum: { $cond: [{ $eq: ['$status', 'pending'] }, 1, 0] },
        },
        contacted: {
          $sum: { $cond: [{ $eq: ['$status', 'contacted'] }, 1, 0] },
        },
        completed: {
          $sum: { $cond: [{ $eq: ['$status', 'completed'] }, 1, 0] },
        },
        cancelled: {
          $sum: { $cond: [{ $eq: ['$status', 'cancelled'] }, 1, 0] },
        },
      },
    },
  ]);

  const totalStats = await DeviceRegistration.aggregate([
    {
      $group: {
        _id: null,
        totalRegistrations: { $sum: 1 },
        pending: {
          $sum: { $cond: [{ $eq: ['$status', 'pending'] }, 1, 0] },
        },
        contacted: {
          $sum: { $cond: [{ $eq: ['$status', 'contacted'] }, 1, 0] },
        },
        completed: {
          $sum: { $cond: [{ $eq: ['$status', 'completed'] }, 1, 0] },
        },
        cancelled: {
          $sum: { $cond: [{ $eq: ['$status', 'cancelled'] }, 1, 0] },
        },
      },
    },
  ]);

  return res.status(HTTP_STATUS.OK).json({
    success: true,
    data: {
      byDevice: stats,
      overall: totalStats[0] || {
        totalRegistrations: 0,
        pending: 0,
        contacted: 0,
        completed: 0,
        cancelled: 0,
      },
    },
  });
});
