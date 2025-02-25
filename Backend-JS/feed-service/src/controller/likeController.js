const Like = require("../model/LikeModel");
const Feed = require("../model/FeedModel");
const { redisCache } = require("../config/redis");

class LikeController {
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

      // Pagination options
      const options = {
        page: parseInt(page),
        limit: parseInt(limit),
        sort: { createdAt: -1 },
        populate: [
          {
            path: "userId",
            select: "userName profilePhoto",
          },
        ],
      };

      // Find likes for specific feed
      const likes = await Like.paginate({ feed: feedId }, options);

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

      // Pagination options
      const options = {
        page: parseInt(page),
        limit: parseInt(limit),
        sort: { createdAt: -1 },
        populate: [
          {
            path: "feed",
            select: "description content userName",
          },
        ],
      };

      // Find liked feeds for user
      const likedFeeds = await Like.paginate({ userId }, options);

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
