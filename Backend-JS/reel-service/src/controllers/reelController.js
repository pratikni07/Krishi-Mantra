// controllers/reelController.js
const ReelService = require("../services/reelService");
const TagService = require("../services/tagService");
const RecommendationService = require("../services/recommendationService");
const catchAsync = require("../utils/catchAsync");
const engagementEmitter = require("../utils/engagementEmitter");

// interactionType (from /reels/interaction) -> engagement event name.
// Only types in this map produce a parallel engagement event; unknown
// types are kept out of the analytics stream so no garbage names hit the
// Mongoose enum.
const REEL_INTERACTION_EVENT_MAP = {
  view: { name: "reel_view", category: "content" },
  like: { name: "reel_like", category: "engagement" },
  unlike: { name: "reel_unlike", category: "engagement" },
  comment: { name: "reel_comment", category: "social" },
  share: { name: "reel_share", category: "social" },
  swipe: { name: "reel_swipe", category: "navigation" },
  complete: { name: "reel_watch_complete", category: "engagement" },
  watch_complete: { name: "reel_watch_complete", category: "engagement" },
  skip: { name: "reel_skip", category: "navigation" },
};

class ReelController {
  static createReel = async (req, res) => {
    const { userId, userName, profilePhoto, description, mediaUrl, location } =
      req.body;
    // const { userId, userName, profilePhoto } = req.user;

    const reel = await ReelService.createReel({
      userId,
      userName,
      profilePhoto,
      description,
      mediaUrl,
      location,
    });

    res.status(201).json({
      status: "success",
      data: reel,
    });
  };

  static getReels = catchAsync(async (req, res) => {
    const { page = 1, limit = 10 } = req.query;
    const userId = req.body.userId || req.query.userId || null;  // Get userId from request if available

    const reels = await ReelService.getReels(
      parseInt(page), 
      parseInt(limit), 
      {}, 
      userId
    );

    res.json({
      status: "success",
      data: reels,
    });
  });

  static getReel = catchAsync(async (req, res) => {
    const { id } = req.params;
    const { page = 1, limit = 10 } = req.query;

    const reel = await ReelService.getReelWithComments(
      id,
      parseInt(page),
      parseInt(limit)
    );

    if (!reel) {
      return res.status(404).json({
        status: "error",
        message: "Reel not found",
      });
    }

    res.json({
      status: "success",
      data: reel,
    });
  });

  static getTrendingReels = catchAsync(async (req, res) => {
    const { page = 1, limit = 10 } = req.query;
    const userId = req.body.userId || req.query.userId || null;  // Get userId from request if available
    
    const reels = await ReelService.getTrendingReels(
      parseInt(page),
      parseInt(limit),
      userId
    );

    res.json({
      status: "success",
      data: reels,
    });
  });

  static likeReel = catchAsync(async (req, res) => {
    const { id } = req.params;
    const { userId, userName, profilePhoto } = req.body;
    // const { userId, userName, profilePhoto } = req.user;

    try {
      const like = await ReelService.likeReel(id, {
        userId,
        userName,
        profilePhoto,
      });

      res.status(201).json({
        status: "success",
        data: like,
      });
    } catch (error) {
      if (error.message === "Reel already liked") {
        return res.status(400).json({
          status: "error",
          message: error.message,
        });
      }
      if (error.message === "Reel not found") {
        return res.status(404).json({
          status: "error",
          message: error.message,
        });
      }
      throw error;
    }
  });

  static unlikeReel = catchAsync(async (req, res) => {
    const { id } = req.params;
    const { userId } = req.body;
    // const { userId } = req.user;

    try {
      const result = await ReelService.unlikeReel(id, userId);

      res.json({
        status: "success",
        message: "Reel unliked successfully",
      });
    } catch (error) {
      if (error.message === "Like not found") {
        return res.status(404).json({
          status: "error",
          message: error.message,
        });
      }
      if (error.message === "Reel not found") {
        return res.status(404).json({
          status: "error",
          message: error.message,
        });
      }
      throw error;
    }
  });

  static addComment = catchAsync(async (req, res) => {
    const { id } = req.params;
    const { userId, userName, profilePhoto, content, parentComment } = req.body;

    const comment = await ReelService.addComment(id, {
      userId,
      userName,
      profilePhoto,
      content,
      parentComment,
    });

    res.status(201).json({
      status: "success",
      data: comment,
    });
  });

  static getCommentByReelId = catchAsync(async (req, res) => {
    const { reelId } = req.params;
    const { page = 1, limit = 10, parentComment = null } = req.query;

    const comments = await ReelService.getCommentByReelId(reelId, {
      page: parseInt(page),
      limit: parseInt(limit),
      parentComment,
    });

    res.json({
      status: "success",
      data: comments.data,
      pagination: {
        currentPage: comments.currentPage,
        totalPages: comments.totalPages,
        totalComments: comments.total,
        hasNextPage: comments.hasNextPage,
        hasPrevPage: comments.hasPrevPage,
      },
    });
  });

  static deleteComment = catchAsync(async (req, res) => {
    const { commentId } = req.params;
    const { userId } = req.body;
    // const { userId } = req.user;

    await ReelService.deleteComment(commentId, userId);

    res.json({
      status: "success",
      message: "Comment deleted successfully",
    });
  });

  static getUserReels = catchAsync(async (req, res) => {
    const { userId } = req.params;
    const { page = 1, limit = 10 } = req.query;
    const viewerId = req.body.userId || req.query.userId || null;  // Current user viewing the reels

    const reels = await ReelService.getUserReels(
      userId,
      parseInt(page),
      parseInt(limit),
      viewerId
    );

    res.json({
      status: "success",
      data: reels,
    });
  });

  static deleteReel = catchAsync(async (req, res) => {
    const { id } = req.params;
    const { userId } = req.body;
    // const { userId } = req.user;

    await ReelService.deleteReel(id, userId);

    res.json({
      status: "success",
      message: "Reel deleted successfully",
    });
  });

  static searchReels = catchAsync(async (req, res) => {
    const { q, page = 1, limit = 10 } = req.query;

    if (!q) {
      return res.status(400).json({
        status: "error",
        message: "Search query is required",
      });
    }

    const reels = await ReelService.searchReels(
      q,
      parseInt(page),
      parseInt(limit)
    );

    res.json({
      status: "success",
      data: reels,
    });
  });

  static getTrendingTags = catchAsync(async (req, res) => {
    const { limit = 10 } = req.query;
    const tags = await TagService.getTrendingTags(parseInt(limit));

    res.json({
      status: "success",
      data: tags,
    });
  });

  static getReelsByTag = catchAsync(async (req, res) => {
    const { tag } = req.params;
    const { page = 1, limit = 10 } = req.query;

    const reels = await TagService.getReelsByTag(
      tag,
      parseInt(page),
      parseInt(limit)
    );

    res.json({
      status: "success",
      data: reels,
    });
  });

  /**
   * Get recommended reels based on user interests
   * GET /reels/recommended/:userId
   */
  static getRecommendedReels = catchAsync(async (req, res) => {
    const { userId } = req.params;
    const { page = 1, limit = 10, latitude, longitude } = req.query;

    const location = latitude && longitude
      ? { latitude: parseFloat(latitude), longitude: parseFloat(longitude) }
      : null;

    const result = await RecommendationService.getRecommendedReels(userId, {
      page: parseInt(page),
      limit: parseInt(limit),
      location,
    });

    res.json({
      status: "success",
      data: result.data,
      pagination: result.pagination,
    });
  });

  /**
   * Record user interaction with a reel
   * POST /reels/interaction
   */
  static recordInteraction = catchAsync(async (req, res) => {
    const { userId, reelId, interactionType } = req.body;

    if (!userId || !reelId || !interactionType) {
      return res.status(400).json({
        status: "error",
        message: "userId, reelId, and interactionType are required",
      });
    }

    const result = await RecommendationService.recordInteraction(
      userId,
      reelId,
      interactionType
    );

    // Bridge to engagement-service. Tagged with source='interaction-log'
    // so analytics can de-duplicate against FE-emitted reel events.
    const mapped = REEL_INTERACTION_EVENT_MAP[interactionType];
    if (mapped) {
      engagementEmitter.emit({
        userId: String(userId),
        eventName: mapped.name,
        eventCategory: mapped.category,
        properties: {
          contentId: String(reelId),
          contentType: "reel",
          interactionType,
          source: "interaction-log",
        },
      });
    }

    res.json({
      status: "success",
      data: result,
    });
  });

  /**
   * Get user's interest profile
   * GET /reels/interests/:userId
   */
  static getUserInterests = catchAsync(async (req, res) => {
    const { userId } = req.params;

    const interests = await RecommendationService.getUserInterests(userId);

    res.json({
      status: "success",
      data: interests,
    });
  });

  /**
   * Initialize user interests from their activity history
   * POST /reels/interests/:userId/initialize
   */
  static initializeUserInterests = catchAsync(async (req, res) => {
    const { userId } = req.params;

    const userInterest = await RecommendationService.initializeUserInterests(userId);

    res.json({
      status: "success",
      data: {
        interests: userInterest.interests.slice(0, 20),
        engagementLevel: userInterest.engagementLevel,
      },
    });
  });

  /**
   * Sync tags for reels (utility endpoint for data migration)
   * POST /reels/sync-tags
   */
  static syncReelTags = catchAsync(async (req, res) => {
    const { reelId } = req.body;

    const result = await RecommendationService.syncReelTags(reelId);

    res.json({
      status: "success",
      data: result,
    });
  });
}

module.exports = ReelController;
