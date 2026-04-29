const ConsultantRating = require('../model/ConsultantRating');
const User = require('../model/User');
const engagementEmitter = require('../utils/engagementEmitter');
const { HTTP_STATUS } = require('../utils/constants');
const logger = require('../utils/logger');

/**
 * Submit (or revise) a rating for a consultant after a chat. One rating per
 * (user, chat) pair — repeat submissions update the existing document.
 *
 * POST /api/main/consultants/:id/rating
 * Body: { chatId: string, rating: 1..5, reviewText?: string }
 * Auth: regular user JWT (handled by gateway).
 */
exports.submitRating = async (req, res) => {
  try {
    const consultantId = req.params.id;
    const userId = req.user?._id || req.user?.id;
    const { chatId, rating, reviewText } = req.body;

    if (!consultantId || !chatId || rating == null) {
      return res.status(HTTP_STATUS.BAD_REQUEST).json({
        success: false,
        message: 'consultantId, chatId, and rating are required',
      });
    }
    const numericRating = Number(rating);
    if (!Number.isFinite(numericRating) || numericRating < 1 || numericRating > 5) {
      return res.status(HTTP_STATUS.BAD_REQUEST).json({
        success: false,
        message: 'rating must be between 1 and 5',
      });
    }

    // Confirm the target is actually a consultant before creating a rating
    // row. Prevents pollution from typos / spoofed IDs.
    const consultant = await User.findById(consultantId).select('accountType').lean();
    if (!consultant) {
      return res.status(HTTP_STATUS.NOT_FOUND).json({
        success: false,
        message: 'Consultant not found',
      });
    }
    if (consultant.accountType !== 'consultant') {
      return res.status(HTTP_STATUS.BAD_REQUEST).json({
        success: false,
        message: 'Target user is not a consultant',
      });
    }

    const doc = await ConsultantRating.findOneAndUpdate(
      { userId, chatId },
      {
        $set: {
          consultantId,
          userId,
          chatId,
          rating: numericRating,
          reviewText: typeof reviewText === 'string' ? reviewText.slice(0, 1000) : '',
        },
      },
      { upsert: true, new: true, setDefaultsOnInsert: true }
    );

    engagementEmitter.emit({
      userId: String(userId),
      eventName: 'consultant_rating_submitted',
      eventCategory: 'communication',
      properties: {
        contentId: String(consultantId),
        contentType: 'consultant',
        chatId: String(chatId),
        rating: numericRating,
        source: 'server',
      },
    });

    return res.status(HTTP_STATUS.OK).json({
      success: true,
      message: 'Rating saved',
      data: doc,
    });
  } catch (error) {
    logger.error('submitRating error:', error);
    return res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({
      success: false,
      message: 'Failed to save rating',
      error: error.message,
    });
  }
};

/**
 * List ratings for a consultant — paginated, newest first.
 * GET /api/main/consultants/:id/ratings?page=1&limit=20
 */
exports.listRatings = async (req, res) => {
  try {
    const consultantId = req.params.id;
    const page = Math.max(1, parseInt(req.query.page, 10) || 1);
    const limit = Math.min(100, Math.max(1, parseInt(req.query.limit, 10) || 20));
    const skip = (page - 1) * limit;

    const [items, total, stats] = await Promise.all([
      ConsultantRating.find({ consultantId })
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit)
        .populate('userId', 'firstName lastName name')
        .lean(),
      ConsultantRating.countDocuments({ consultantId }),
      ConsultantRating.aggregate([
        { $match: { consultantId: require('mongoose').Types.ObjectId.createFromHexString(consultantId) } },
        {
          $group: {
            _id: null,
            avg: { $avg: '$rating' },
            count: { $sum: 1 },
          },
        },
      ]),
    ]);

    const summary = stats[0] || { avg: 0, count: 0 };

    return res.status(HTTP_STATUS.OK).json({
      success: true,
      data: items,
      pagination: { page, limit, total, pages: Math.ceil(total / limit) },
      summary: {
        averageRating: Number(summary.avg?.toFixed(2)) || 0,
        ratingCount: summary.count,
      },
    });
  } catch (error) {
    logger.error('listRatings error:', error);
    return res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({
      success: false,
      message: 'Failed to list ratings',
      error: error.message,
    });
  }
};
