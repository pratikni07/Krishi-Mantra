// services/reelService.js
const mongoose = require("mongoose");
const Reel = require("../models/Reel");
const Comment = require("../models/CommentModal");
const Like = require("../models/LikeModel");
const TagService = require("./tagService");
const redis = require("../config/redis");
const PaginationUtils = require("../utils/pagination");

const CACHE_TTL = 3600; // 1 hour

class ReelService {
  static async createReel(reelData) {
    try {
      // Create reel without transaction
      const reel = new Reel(reelData);
      await reel.save();

      if (reelData.description) {
        await TagService.processTags(reelData.description, reel._id);
      }

      // Clear relevant cache - wrapped in try/catch to handle Redis errors
      try {
        await redis.del(`reels:trending`);
        await redis.del(`reels:user:${reelData.userId}`);
      } catch (redisError) {
        console.warn("Redis cache clearing error:", redisError.message);
        // Continue execution despite Redis error
      }

      return reel;
    } catch (error) {
      console.error("Error creating reel:", error);
      throw error;
    }
  }

  static async getReels(page = 1, limit = 10, filters = {}, userId = null) {
    const cacheKey = `reels:page:${page}:limit:${limit}:${JSON.stringify(
      filters
    )}:user:${userId || "guest"}`;

    // Try to get cached data, but handle Redis errors gracefully
    try {
      const cachedData = await redis.get(cacheKey);
      if (cachedData) {
        return JSON.parse(cachedData);
      }
    } catch (redisError) {
      console.warn("Redis cache retrieval error:", redisError.message);
      // Continue execution without cache data
    }

    const skip = (page - 1) * limit;

    const [reels, total] = await Promise.all([
      Reel.find(filters).sort({ createdAt: -1 }).skip(skip).limit(limit).lean(),
      Reel.countDocuments(filters),
    ]);

    // Enhance reels with like status if userId is provided
    if (userId) {
      await Promise.all(
        reels.map(async (reel) => {
          const like = await Like.findOne({ reel: reel._id, userId });
          reel.like = {
            ...reel.like,
            isLiked: !!like,
          };
        })
      );
    }

    const result = PaginationUtils.formatPaginationResponse(
      reels,
      page,
      limit,
      total
    );

    // Try to cache the result, but handle Redis errors gracefully
    try {
      await redis.setex(cacheKey, CACHE_TTL, JSON.stringify(result));
    } catch (redisError) {
      console.warn("Redis cache storage error:", redisError.message);
      // Continue execution despite Redis error
    }

    return result;
  }

  static async getReelWithComments(reelId, page = 1, limit = 10) {
    const cacheKey = `reel:${reelId}:comments:${page}:${limit}`;
    const cachedData = await redis.get(cacheKey);

    if (cachedData) {
      return JSON.parse(cachedData);
    }

    const skip = (page - 1) * limit;

    const [reel, comments, totalComments] = await Promise.all([
      Reel.findById(reelId).lean(),
      Comment.find({
        reel: reelId,
        parentComment: null,
      })
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit)
        .populate({
          path: "replies",
          options: {
            sort: { createdAt: -1 },
            limit: 5,
          },
        })
        .lean(),
      Comment.countDocuments({
        reel: reelId,
        parentComment: null,
      }),
    ]);

    if (!reel) {
      return null;
    }

    const result = {
      ...reel,
      comments: PaginationUtils.formatPaginationResponse(
        comments,
        page,
        limit,
        totalComments
      ),
    };

    await redis.setex(cacheKey, CACHE_TTL, JSON.stringify(result));
    return result;
  }

  static async getTrendingReels(page = 1, limit = 10, userId = null) {
    const cacheKey = `reels:trending:${page}:${limit}:user:${
      userId || "guest"
    }`;
    const cachedData = await redis.get(cacheKey);

    if (cachedData) {
      return JSON.parse(cachedData);
    }

    const skip = (page - 1) * limit;

    const [reels, total] = await Promise.all([
      Reel.aggregate([
        {
          $lookup: {
            from: "comments",
            localField: "_id",
            foreignField: "reel",
            as: "comments",
          },
        },
        {
          $addFields: {
            commentCount: { $size: "$comments" },
            engagement: {
              $add: [{ $ifNull: ["$like.count", 0] }, { $size: "$comments" }],
            },
          },
        },
        {
          $sort: {
            engagement: -1,
            createdAt: -1,
          },
        },
        { $skip: skip },
        { $limit: limit },
      ]),
      Reel.countDocuments(),
    ]);

    // Enhance reels with like status if userId is provided
    if (userId) {
      await Promise.all(
        reels.map(async (reel) => {
          const like = await Like.findOne({ reel: reel._id, userId });
          reel.like = {
            ...(reel.like || {}),
            isLiked: !!like,
          };
        })
      );
    }

    const result = PaginationUtils.formatPaginationResponse(
      reels,
      page,
      limit,
      total
    );

    await redis.setex(cacheKey, CACHE_TTL, JSON.stringify(result));
    return result;
  }

  static async likeReel(reelId, userData) {
    try {
      // Check if reel exists
      const reel = await Reel.findById(reelId);
      if (!reel) {
        throw new Error("Reel not found");
      }

      // Check for existing like
      const existingLike = await Like.findOne({
        reel: reelId,
        userId: userData.userId,
      });

      if (existingLike) {
        throw new Error("Reel already liked");
      }

      // Create new like
      const like = new Like({
        reel: reelId,
        ...userData,
      });

      await like.save();

      // Update reel like count
      await Reel.findByIdAndUpdate(reelId, {
        $inc: { "like.count": 1 },
        $addToSet: { "like.users": userData.userId },
      });

      // Clear ALL relevant cache keys
      await redis.del(`reel:${reelId}`);
      await redis.del(`reels:trending:*`);
      await redis.del(`reels:user:${userData.userId}:*`);
      await redis.del(`reels:page:*`);

      return {
        ...like.toObject(),
        isLiked: true,
      };
    } catch (error) {
      throw error;
    }
  }

  static async unlikeReel(reelId, userId) {
    try {
      // Check if reel exists
      const reel = await Reel.findById(reelId);
      if (!reel) {
        throw new Error("Reel not found");
      }

      // Find and delete like
      const deletedLike = await Like.findOneAndDelete({
        reel: reelId,
        userId,
      });

      if (!deletedLike) {
        throw new Error("Like not found");
      }

      // Update reel like count
      await Reel.findByIdAndUpdate(reelId, {
        $inc: { "like.count": -1 },
        $pull: { "like.users": userId },
      });

      // Clear ALL relevant cache keys
      await redis.del(`reel:${reelId}`);
      await redis.del(`reels:trending:*`);
      await redis.del(`reels:user:${userId}:*`);
      await redis.del(`reels:page:*`);

      return {
        ...deletedLike.toObject(),
        isLiked: false,
      };
    } catch (error) {
      throw error;
    }
  }

  static async getCommentByReelId(reelId, { page, limit, parentComment }) {
    const COMMENTS_CACHE_TTL = 30;

    const cacheKey = `comment:${reelId}:${page}:${limit}:${parentComment}`;
    const cachedComment = await redis.get(cacheKey);

    if (cachedComment) {
      return JSON.parse(cachedComment);
    }

    const skip = (page - 1) * limit;

    const query = {
      reel: reelId,
      isDeleted: false,
      parentComment: parentComment || null,
    };

    const [comments, total] = await Promise.all([
      Comment.find(query)
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit)
        .populate({
          path: "replies",
          select: "-__v",
          match: { isDeleted: false },
          options: { sort: { createdAt: -1 } },
          populate: {
            path: "replies",
            match: { isDeleted: false },
            options: { sort: { createdAt: -1 } },
          },
        })
        .lean(),
      Comment.countDocuments(query),
    ]);

    const totalPages = Math.ceil(total / limit);

    const result = {
      data: comments,
      currentPage: page,
      totalPages,
      total,
      hasNextPage: page < totalPages,
      hasPrevPage: page > 1,
    };

    // Set a shorter cache TTL for comments
    await redis.set(cacheKey, JSON.stringify(result), "EX", COMMENTS_CACHE_TTL);

    return result;
  }

  static async addComment(reelId, commentData) {
    const comment = new Comment({
      reel: reelId,
      ...commentData,
    });

    if (commentData.parentComment) {
      const parentComment = await Comment.findById(commentData.parentComment);
      if (!parentComment) {
        throw new Error("Parent comment not found");
      }

      // Verify parent comment belongs to the same reel
      if (parentComment.reel.toString() !== reelId) {
        throw new Error("Parent comment does not belong to this reel");
      }

      if (parentComment.depth >= 5) {
        throw new Error("Maximum comment depth reached");
      }

      comment.depth = parentComment.depth + 1;

      await comment.save();

      await Comment.findByIdAndUpdate(parentComment._id, {
        $push: { replies: comment._id },
      });
    } else {
      await comment.save();
    }

    if (!commentData.parentComment) {
      await Reel.findByIdAndUpdate(reelId, {
        $inc: { "comment.count": 1 },
      });
    }

    // Clear ALL related cache patterns
    const cachePatterns = [
      `reel:${reelId}*`,
      `comment:${reelId}*`,
      `reel:${reelId}:comments*`,
      "reels:trending*", // Clear trending cache as engagement changes
    ];

    await Promise.all(cachePatterns.map((pattern) => redis.del(pattern)));

    return Comment.findById(comment._id)
      .populate({
        path: "replies",
        select: "-__v",
        match: { isDeleted: false },
        options: { sort: { createdAt: -1 } },
      })
      .lean();
  }

  static async deleteComment(commentId, userId) {
    const comment = await Comment.findOne({
      _id: commentId,
      userId,
    });

    if (!comment) {
      throw new Error("Comment not found or unauthorized");
    }

    // Soft delete the comment
    comment.isDeleted = true;
    comment.content = "[deleted]";
    await comment.save();

    // Update reel comment count
    await Reel.findByIdAndUpdate(comment.reel, {
      $inc: { "comment.count": -1 },
    });

    await redis.del(`reel:${comment.reel}`);
    await redis.del(`reel:${comment.reel}:comments:*`);

    return comment;
  }

  static async getUserReels(userId, page = 1, limit = 10, viewerId = null) {
    const cacheKey = `reels:user:${userId}:${page}:${limit}:viewer:${
      viewerId || "guest"
    }`;
    const cachedData = await redis.get(cacheKey);

    if (cachedData) {
      return JSON.parse(cachedData);
    }

    const skip = (page - 1) * limit;

    const [reels, total] = await Promise.all([
      Reel.find({ userId })
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit)
        .lean(),
      Reel.countDocuments({ userId }),
    ]);

    // Enhance reels with like status if viewerId is provided
    if (viewerId) {
      await Promise.all(
        reels.map(async (reel) => {
          const like = await Like.findOne({ reel: reel._id, userId: viewerId });
          reel.like = {
            ...reel.like,
            isLiked: !!like,
          };
        })
      );
    }

    const result = PaginationUtils.formatPaginationResponse(
      reels,
      page,
      limit,
      total
    );

    await redis.setex(cacheKey, CACHE_TTL, JSON.stringify(result));
    return result;
  }

  static async deleteReel(reelId, userId) {
    try {
      const reel = await Reel.findOne({ _id: reelId, userId });

      if (!reel) {
        throw new Error("Reel not found or unauthorized");
      }

      // Execute deletions sequentially to maintain consistency
      await Reel.findByIdAndDelete(reelId);
      await Comment.deleteMany({ reel: reelId });
      await Like.deleteMany({ reel: reelId });
      await TagService.removeTagsFromReel(reelId);

      // Clear related cache
      const cacheKeys = [
        `reel:${reelId}`,
        `reel:${reelId}:comments:*`,
        `reels:user:${userId}:*`,
        "reels:trending:*",
      ];

      await Promise.all(cacheKeys.map((key) => redis.del(key)));

      return true;
    } catch (error) {
      throw error;
    }
  }

  static async searchReels(query, page = 1, limit = 10) {
    const cacheKey = `reels:search:${query}:${page}:${limit}`;
    const cachedData = await redis.get(cacheKey);

    if (cachedData) {
      return JSON.parse(cachedData);
    }

    const skip = (page - 1) * limit;

    const searchRegex = new RegExp(query, "i");
    const [reels, total] = await Promise.all([
      Reel.find({
        $or: [{ description: searchRegex }, { userName: searchRegex }],
      })
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit)
        .lean(),
      Reel.countDocuments({
        $or: [{ description: searchRegex }, { userName: searchRegex }],
      }),
    ]);

    const result = PaginationUtils.formatPaginationResponse(
      reels,
      page,
      limit,
      total
    );

    await redis.setex(cacheKey, CACHE_TTL, JSON.stringify(result));
    return result;
  }
}

module.exports = ReelService;
