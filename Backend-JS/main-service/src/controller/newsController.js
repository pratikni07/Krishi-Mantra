const News = require('../model/News');
const redis = require('../config/redis');
const { asyncHandler } = require('../utils');
const { HTTP_STATUS, CACHE_TTL, PAGINATION } = require('../utils/constants');

/**
 * Create news article
 */
const createNews = asyncHandler(async (req, res) => {
  const { content, tags, imageUrl } = req.body;
  const uploadedBy = req.user.id || req.user._id;

  const news = new News({
    content,
    tags,
    uploadedBy,
    image: imageUrl,
  });

  await news.save();

  // Invalidate cache
  await redis.del('news:all');

  return res.status(HTTP_STATUS.CREATED).json({
    success: true,
    data: news,
  });
});

/**
 * Get all news with pagination and caching
 */
const getAllNews = asyncHandler(async (req, res) => {
  const page = parseInt(req.query.page, 10) || PAGINATION.DEFAULT_PAGE;
  const limit = Math.min(
    parseInt(req.query.limit, 10) || PAGINATION.DEFAULT_LIMIT,
    PAGINATION.MAX_LIMIT
  );
  const skip = (page - 1) * limit;

  const cacheKey = `news:all:page:${page}:limit:${limit}`;

  // Try cache first
  const cachedNews = await redis.get(cacheKey);
  if (cachedNews) {
    return res.status(HTTP_STATUS.OK).json(JSON.parse(cachedNews));
  }

  const [news, total] = await Promise.all([
    News.find({ isPublished: true })
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit)
      .populate('uploadedBy', 'name')
      .lean(),
    News.countDocuments({ isPublished: true }),
  ]);

  const response = {
    success: true,
    count: news.length,
    total,
    page,
    totalPages: Math.ceil(total / limit),
    data: news,
  };

  // Cache the result
  await redis.setex(cacheKey, CACHE_TTL.LONG, JSON.stringify(response));

  return res.status(HTTP_STATUS.OK).json(response);
});

/**
 * Like a news article
 */
const likeNews = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user.id || req.user._id;

  // Lean — only used for existence and the already-liked check; the actual
  // mutation uses an atomic findByIdAndUpdate below.
  const news = await News.findById(id).lean();
  if (!news) {
    return res.status(HTTP_STATUS.NOT_FOUND).json({
      success: false,
      message: 'News not found',
    });
  }

  // Check if user already liked
  if (news.likedBy && news.likedBy.includes(userId)) {
    return res.status(HTTP_STATUS.BAD_REQUEST).json({
      success: false,
      message: 'You have already liked this news',
    });
  }

  // Atomic update to prevent race conditions
  const updatedNews = await News.findByIdAndUpdate(
    id,
    {
      $inc: { likes: 1 },
      $addToSet: { likedBy: userId },
    },
    { new: true }
  );

  // Invalidate cache
  await redis.del(`news:${id}`);
  await redis.del('news:all');

  return res.status(HTTP_STATUS.OK).json({
    success: true,
    data: updatedNews,
  });
});

/**
 * Search news
 */
const searchNews = asyncHandler(async (req, res) => {
  const { query, tags } = req.query;
  const page = parseInt(req.query.page, 10) || PAGINATION.DEFAULT_PAGE;
  const limit = Math.min(
    parseInt(req.query.limit, 10) || PAGINATION.DEFAULT_LIMIT,
    PAGINATION.MAX_LIMIT
  );
  const skip = (page - 1) * limit;

  const searchCriteria = { isPublished: true };

  if (query) {
    searchCriteria.$text = { $search: query };
  }

  if (tags) {
    searchCriteria.tags = { $in: tags.split(',').map((t) => t.trim()) };
  }

  const [news, total] = await Promise.all([
    News.find(searchCriteria)
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit)
      .populate('uploadedBy', 'name')
      .lean(),
    News.countDocuments(searchCriteria),
  ]);

  return res.status(HTTP_STATUS.OK).json({
    success: true,
    count: news.length,
    total,
    page,
    totalPages: Math.ceil(total / limit),
    data: news,
  });
});

module.exports = {
  createNews,
  getAllNews,
  likeNews,
  searchNews,
};
