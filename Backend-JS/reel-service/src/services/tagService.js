// services/tagService.js
const Tag = require("../models/Tags");
const redis = require("../config/redis");
const extractHashtags = require("../utils/hashtagExtractor");
class TagService {
  static async processTags(content, reelId) {
    const hashtags = extractHashtags(content);
    const tagOperations = hashtags.map(async (tagName) => {
      const tag = await Tag.findOneAndUpdate(
        { name: tagName },
        {
          $addToSet: { reels: reelId },
          $inc: { count: 1 },
          lastUsed: new Date(),
        },
        { upsert: true, new: true }
      );

      await redis.del("trending:tags");
      return tag;
    });

    return Promise.all(tagOperations);
  }

  static async getTrendingTags(limit = 10) {
    const cacheKey = `trending:tags:${limit}`;
    const cachedTags = await redis.get(cacheKey);

    if (cachedTags) {
      return JSON.parse(cachedTags);
    }

    const trendingTags = await Tag.find()
      .sort({ count: -1, lastUsed: -1 })
      .limit(limit)
      .lean();

    await redis.setex(cacheKey, 3600, JSON.stringify(trendingTags));
    return trendingTags;
  }

  static async getReelsByTag(tagName, page = 1, limit = 10) {
    const skip = (page - 1) * limit;
    const tag = await Tag.findOne({ name: tagName.toLowerCase() }).populate({
      path: "reels",
      options: {
        skip,
        limit,
        sort: { createdAt: -1 },
      },
    });

    return tag ? tag.reels : [];
  }

  static async removeTagsFromReel(reelId) {
    await Tag.updateMany(
      { reels: reelId },
      {
        $pull: { reels: reelId },
        $inc: { count: -1 },
      }
    );

    await Tag.deleteMany({ count: { $lte: 0 } });
    await redis.del("trending:tags");
  }
}

module.exports = TagService;
