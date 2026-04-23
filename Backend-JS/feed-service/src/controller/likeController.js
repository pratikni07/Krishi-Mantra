const Like = require("../model/LikeModel");
const Feed = require("../model/FeedModel");
const { redisCache } = require("../config/redis");

class LikeController {
  static async _paginateLikeQuery(query, page, limit, populate = []) {
    const currentPage = Math.max(parseInt(page, 10) || 1, 1);
    const perPage = Math.max(parseInt(limit, 10) || 10, 1);
    const skip = (currentPage - 1) * perPage;

    const [totalDocs, docs] = await Promise.all([
      Like.countDocuments(query),
      Like.find(query)
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(perPage)
        .populate(populate)
        .lean(),
    ]);

    const totalPages = Math.max(Math.ceil(totalDocs / perPage), 1);

    return {
      docs,
      totalDocs,
      limit: perPage,
      page: currentPage,
      totalPages,
      pagingCounter: skip + 1,
      hasPrevPage: currentPage > 1,
      hasNextPage: currentPage < totalPages,
      prevPage: currentPage > 1 ? currentPage - 1 : null,
      nextPage: currentPage < totalPages ? currentPage + 1 : null,
    };
  }

  // Toggle Like (Like/Unlike)
  static async toggleLike(req, res) {
    try {
      const { userId, feedId } = req.body;

      // Check if feed exists
      const feed = await Feed.findById(feedId);
      if (!feed) {
        return res.status(404).json({ message: "Feed not found" });
      }

      // Check if user has already liked the feed
      const existingLike = await Like.findOne({
        userId,
        feed: feedId,
      });

      if (existingLike) {
        // Unlike: Remove like
        await Like.findByIdAndDelete(existingLike._id);

        // Decrement like count
        await Feed.findByIdAndUpdate(feedId, {
          $inc: { "like.count": -1 },
          $pull: { "like.likes": existingLike._id },
        });

        // Invalidate cache
        await redisCache.invalidatePatterns(`feed:${feedId}:likes`);

        return res.json({
          message: "Unliked successfully",
          liked: false,
        });
      }

      // Create new like
      const newLike = new Like({
        userId,
        feed: feedId,
      });
      await newLike.save();

      // Update feed like count and add like reference
      await Feed.findByIdAndUpdate(feedId, {
        $inc: { "like.count": 1 },
        $push: { "like.likes": newLike._id },
      });

      // Invalidate cache
      await redisCache.invalidatePatterns(`feed:${feedId}:likes`);

      res.status(201).json({
        message: "Liked successfully",
        liked: true,
        likeId: newLike._id,
      });
    } catch (error) {
      res.status(500).json({
        message: "Error processing like",
        error: error.message,
      });
    }
  }

  // Get Likes for a Specific Feed
  static async getFeedLikes(req, res) {
    try {
      const { feedId } = req.params;
      const { page = 1, limit = 10 } = req.query;

      // Create cache key
      const cacheKey = `feed:${feedId}:likes:${page}:${limit}`;

      // Check cache
      const cachedLikes = await redisCache.get(cacheKey);
      if (cachedLikes) {
        return res.json(cachedLikes);
      }

      // Find likes for specific feed
      const likes = await LikeController._paginateLikeQuery(
        { feed: feedId },
        page,
        limit,
        [
          {
            path: "userId",
            select: "userName profilePhoto",
          },
        ]
      );

      // Cache results
      await redisCache.set(cacheKey, likes, 300); // 5 min cache

      res.json(likes);
    } catch (error) {
      res.status(500).json({
        message: "Error fetching likes",
        error: error.message,
      });
    }
  }

  // Get User's Liked Feeds
  static async getUserLikedFeeds(req, res) {
    try {
      const { userId } = req.params;
      const { page = 1, limit = 10 } = req.query;

      // Create cache key
      const cacheKey = `user:${userId}:liked-feeds:${page}:${limit}`;

      // Check cache
      const cachedLikedFeeds = await redisCache.get(cacheKey);
      if (cachedLikedFeeds) {
        return res.json(cachedLikedFeeds);
      }

      // Find liked feeds for user
      const likedFeeds = await LikeController._paginateLikeQuery(
        { userId },
        page,
        limit,
        [
          {
            path: "feed",
            select: "description content userName",
          },
        ]
      );

      // Cache results
      await redisCache.set(cacheKey, likedFeeds, 300); // 5 min cache

      res.json(likedFeeds);
    } catch (error) {
      res.status(500).json({
        message: "Error fetching liked feeds",
        error: error.message,
      });
    }
  }
}

module.exports = LikeController;
