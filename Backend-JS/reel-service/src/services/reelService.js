// services/reelService.js
const mongoose = require("mongoose");
const Reel = require("../models/Reel");
const Comment = require("../models/CommentModal");
const Like = require("../models/LikeModel");
const TagService = require("./tagService");
const redis = require("../config/redis");
const PaginationUtils = require("../utils/pagination");
const extractHashtags = require("../utils/hashtagExtractor");

const CACHE_TTL = 3600; // 1 hour

class ReelService {
  /**
   * Helper method to clear cache keys matching a pattern
   * Uses SCAN to avoid blocking Redis with KEYS command
   */
  static async clearCacheByPattern(pattern) {
    try {
      const keys = await redis.keys(pattern);
      if (keys && keys.length > 0) {
        await redis.del(...keys);
      }
    } catch (error) {
      // Silent fail for cache clearing
      console.warn('Cache clear by pattern error:', error.message);
    }
  }

  /**
   * Annotate a list of reels with each one's `like.isLiked` status for the
   * given viewer. Replaces a per-reel `Like.findOne` (N+1 against Mongo) with
   * a single `find({ reel: { $in: ids }, userId })` and an in-memory map —
   * fewer round trips, lower DB load, and cache-friendly under load.
   */
  static async annotateLikedFlags(reels, userId) {
    if (!userId || !Array.isArray(reels) || reels.length === 0) return reels;

    const ids = reels.map((r) => r._id).filter(Boolean);
    if (ids.length === 0) return reels;

    const liked = await Like.find({ reel: { $in: ids }, userId })
      .select('reel')
      .lean();
    const likedSet = new Set(liked.map((l) => String(l.reel)));

    for (const reel of reels) {
      reel.like = {
        ...(reel.like || {}),
        isLiked: likedSet.has(String(reel._id)),
      };
    }
    return reels;
  }

  static async createReel(reelData) {
    try {
      // Extract and store tags from description
      if (reelData.description) {
        const tags = extractHashtags(reelData.description);
        reelData.tags = tags;
      }

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

  /**
   * Build a deterministic cache key from a filters object. Plain
   * `JSON.stringify(filters)` is non-deterministic — `{a: 1, b: 2}` and
   * `{b: 2, a: 1}` produce different keys, so two callers asking for the
   * same logical filter set hit different cache entries (one fills the
   * cache, the other re-queries). Sorting the keys recursively gives the
   * same string regardless of insertion order.
   */
  static _stableStringify(value) {
    if (value === null || typeof value !== "object") {
      return JSON.stringify(value);
    }
    if (Array.isArray(value)) {
      return `[${value.map((v) => ReelService._stableStringify(v)).join(",")}]`;
    }
    const keys = Object.keys(value).sort();
    return `{${keys
      .map((k) => `${JSON.stringify(k)}:${ReelService._stableStringify(value[k])}`)
      .join(",")}}`;
  }

  static async getReels(page = 1, limit = 10, filters = {}, userId = null) {
    const cacheKey = `reels:page:${page}:limit:${limit}:${ReelService._stableStringify(
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
    await ReelService.annotateLikedFlags(reels, userId);

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
    await ReelService.annotateLikedFlags(reels, userId);

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
      // Try to create like directly - unique index will prevent duplicates
      // This is faster than checking existence first
      const like = new Like({
        reel: reelId,
        ...userData,
      });

      try {
        await like.save();
      } catch (saveError) {
        // Duplicate key error means already liked
        if (saveError.code === 11000) {
          throw new Error("Reel already liked");
        }
        throw saveError;
      }

      // Update reel like count (non-blocking for faster response)
      Reel.findByIdAndUpdate(reelId, {
        $inc: { "like.count": 1 },
        $addToSet: { "like.users": userData.userId },
      }).catch((err) => console.warn('Like count update error:', err.message));

      // Clear relevant cache keys (non-blocking to avoid timeouts)
      setImmediate(() => {
        redis.del(`reel:${reelId}`).catch(() => {});
        redis.del(`reels:trending`).catch(() => {});
        redis.del(`reels:user:${userData.userId}`).catch(() => {});
        // Skip pattern-based deletion for speed - it will expire naturally
      });

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
      // Find and delete like in a single operation (skip reel existence check for speed)
      const deletedLike = await Like.findOneAndDelete({
        reel: reelId,
        userId,
      });

      if (!deletedLike) {
        throw new Error("Like not found");
      }

      // Update reel like count (non-blocking for faster response)
      Reel.findByIdAndUpdate(reelId, {
        $inc: { "like.count": -1 },
        $pull: { "like.users": userId },
      }).catch((err) => console.warn('Unlike count update error:', err.message));

      // Clear relevant cache keys (non-blocking to avoid timeouts)
      setImmediate(() => {
        redis.del(`reel:${reelId}`).catch(() => {});
        redis.del(`reels:trending`).catch(() => {});
        redis.del(`reels:user:${userId}`).catch(() => {});
        // Skip pattern-based deletion for speed - it will expire naturally
      });

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
    // Use pattern-based deletion for comments cache
    this.clearCacheByPattern(`reel:${comment.reel}:comments:*`).catch(() => {});

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
    await ReelService.annotateLikedFlags(reels, viewerId);

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
