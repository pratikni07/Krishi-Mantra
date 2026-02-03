const mongoose = require('mongoose');
const Reel = require('../models/Reel');
const ReelUserInterest = require('../models/ReelUserInterest');
const { REEL_INTEREST_CONSTANTS } = require('../models/ReelUserInterest');
const Tag = require('../models/Tags');
const Like = require('../models/LikeModel');
const redis = require('../config/redis');
const extractHashtags = require('../utils/hashtagExtractor');

const CACHE_TTL = {
  RECOMMENDATIONS: 300, // 5 minutes
  USER_INTERESTS: 600,  // 10 minutes
};

class RecommendationService {
  /**
   * Get recommended reels for a user based on their interests
   */
  static async getRecommendedReels(userId, { page = 1, limit = 10, location = null } = {}) {
    const cacheKey = `reels:recommended:${userId}:${page}:${limit}`;

    try {
      // Try to get cached recommendations
      const cachedData = await redis.get(cacheKey);
      if (cachedData) {
        const parsed = JSON.parse(cachedData);
        // Add isLiked status for cached results
        return await this.enhanceWithLikeStatus(parsed, userId);
      }
    } catch (redisError) {
      console.warn('Redis cache error:', redisError.message);
    }

    // Get or create user interest profile
    let userInterest = await ReelUserInterest.findOne({ userId });

    // If no user interest profile, return trending reels
    if (!userInterest || !userInterest.interests || userInterest.interests.length === 0) {
      return await this.getTrendingReelsForNewUser(userId, page, limit);
    }

    // Update location if provided
    if (location && location.latitude && location.longitude) {
      userInterest.location = {
        ...location,
        lastUpdated: new Date(),
      };
      await userInterest.save();
    }

    // Get user's top interests sorted by score
    const topInterests = userInterest.interests
      .sort((a, b) => b.score - a.score)
      .slice(0, 20);

    const topTags = topInterests.map(i => i.tag);

    // Get total active reels count
    const totalActiveReels = await Reel.countDocuments({ isActive: true });

    // Get recently viewed reel IDs
    const allViewedReelIds = userInterest.getViewedReelIds(500);

    // Smart exclusion: only exclude viewed reels if there are enough unseen reels
    // If user has seen most content, don't exclude (allow re-showing with different ranking)
    const unseenReelsCount = totalActiveReels - allViewedReelIds.length;
    const shouldExcludeViewed = unseenReelsCount >= limit * 2;

    // Only exclude recent views (last 50) to allow older content to resurface
    const viewedReelIds = shouldExcludeViewed
      ? allViewedReelIds.slice(0, Math.min(50, allViewedReelIds.length))
      : [];

    const skip = (page - 1) * limit;

    // Build recommendation query
    let recommendations = await this.buildRecommendationQuery(
      topTags,
      topInterests,
      viewedReelIds,
      skip,
      limit * 3 // Fetch more to allow for scoring and filtering
    );

    // If not enough recommendations with tag matching, get all reels sorted by interest
    if (recommendations.length < limit) {
      const additionalReels = await this.getReelsWithInterestScoring(
        topTags,
        [...viewedReelIds, ...recommendations.map(r => r._id)],
        limit * 2
      );
      recommendations = [...recommendations, ...additionalReels];
    }

    // If still not enough, supplement with trending (including viewed)
    if (recommendations.length < limit) {
      const excludeIds = recommendations.map(r => r._id);
      const trendingReels = await this.getTrendingReelsExcluding(
        excludeIds,
        limit - recommendations.length
      );
      recommendations = [...recommendations, ...trendingReels];
    }

    // Score and sort recommendations
    const scoredReels = this.scoreRecommendations(recommendations, topInterests);

    // Remove duplicates by _id
    const uniqueReels = [];
    const seenIds = new Set();
    for (const reel of scoredReels) {
      const reelId = reel._id.toString();
      if (!seenIds.has(reelId)) {
        seenIds.add(reelId);
        uniqueReels.push(reel);
      }
    }

    // Take only the requested limit
    const paginatedReels = uniqueReels.slice(0, limit);

    // Calculate proper pagination based on total active reels
    const result = {
      data: paginatedReels,
      pagination: {
        currentPage: page,
        totalPages: Math.ceil(totalActiveReels / limit),
        totalItems: totalActiveReels,
        hasNextPage: page * limit < totalActiveReels && paginatedReels.length === limit,
        hasPrevPage: page > 1,
      },
    };

    // Cache the result (without isLiked status) - shorter cache for personalized content
    try {
      await redis.setex(cacheKey, CACHE_TTL.RECOMMENDATIONS, JSON.stringify(result));
    } catch (redisError) {
      console.warn('Redis cache set error:', redisError.message);
    }

    // Add isLiked status
    return await this.enhanceWithLikeStatus(result, userId);
  }

  /**
   * Get reels with interest-based scoring (fallback when tag matching returns few results)
   */
  static async getReelsWithInterestScoring(topTags, excludeIds, limit) {
    return await Reel.aggregate([
      {
        $match: {
          isActive: true,
          _id: { $nin: excludeIds.map(id => new mongoose.Types.ObjectId(id)) },
        },
      },
      {
        $addFields: {
          // Calculate engagement score
          engagementScore: {
            $add: [
              { $multiply: [{ $ifNull: ['$viewCount', 0] }, 1] },
              { $multiply: [{ $ifNull: ['$like.count', 0] }, 3] },
              { $multiply: [{ $ifNull: ['$comment.count', 0] }, 5] },
            ],
          },
          // Calculate recency score
          recencyScore: {
            $divide: [
              1,
              {
                $add: [
                  1,
                  {
                    $divide: [
                      { $subtract: [new Date(), '$createdAt'] },
                      86400000,
                    ],
                  },
                ],
              },
            ],
          },
        },
      },
      {
        $addFields: {
          combinedScore: {
            $add: [
              { $multiply: ['$engagementScore', 0.1] },
              { $multiply: ['$recencyScore', 5] },
            ],
          },
        },
      },
      { $sort: { combinedScore: -1, createdAt: -1 } },
      { $limit: limit },
    ]);
  }

  /**
   * Build the recommendation query with tag matching
   */
  static async buildRecommendationQuery(topTags, topInterests, excludeIds, skip, limit) {
    // Create tag score map for weighting
    const tagScoreMap = {};
    topInterests.forEach(interest => {
      tagScoreMap[interest.tag] = interest.score;
    });

    // Query reels that match user's interests
    const reels = await Reel.aggregate([
      {
        $match: {
          isActive: true,
          _id: { $nin: excludeIds.map(id => new mongoose.Types.ObjectId(id)) },
          $or: [
            { tags: { $in: topTags } },
            { category: { $in: topTags } },
          ],
        },
      },
      {
        $addFields: {
          // Calculate tag match score
          tagMatchCount: {
            $size: {
              $setIntersection: [
                { $ifNull: ['$tags', []] },
                topTags,
              ],
            },
          },
          // Calculate engagement score
          engagementScore: {
            $add: [
              { $multiply: [{ $ifNull: ['$viewCount', 0] }, 1] },
              { $multiply: [{ $ifNull: ['$like.count', 0] }, 3] },
              { $multiply: [{ $ifNull: ['$comment.count', 0] }, 5] },
            ],
          },
          // Calculate recency score (newer = higher)
          recencyScore: {
            $divide: [
              1,
              {
                $add: [
                  1,
                  {
                    $divide: [
                      { $subtract: [new Date(), '$createdAt'] },
                      86400000, // milliseconds in a day
                    ],
                  },
                ],
              },
            ],
          },
        },
      },
      {
        $addFields: {
          // Combined recommendation score
          recommendationScore: {
            $add: [
              { $multiply: ['$tagMatchCount', 10] },
              { $multiply: ['$engagementScore', 0.1] },
              { $multiply: ['$recencyScore', 5] },
            ],
          },
        },
      },
      { $sort: { recommendationScore: -1, createdAt: -1 } },
      { $skip: skip },
      { $limit: limit },
    ]);

    return reels;
  }

  /**
   * Score recommendations based on user interests
   */
  static scoreRecommendations(reels, topInterests) {
    const tagScoreMap = {};
    topInterests.forEach(interest => {
      tagScoreMap[interest.tag] = interest.score;
    });

    return reels.map(reel => {
      let interestScore = 0;

      // Calculate interest-based score
      if (reel.tags && reel.tags.length > 0) {
        reel.tags.forEach(tag => {
          if (tagScoreMap[tag]) {
            interestScore += tagScoreMap[tag];
          }
        });
      }

      // Add engagement and recency factors
      const engagementScore = (reel.like?.count || 0) * 3 +
                             (reel.comment?.count || 0) * 5 +
                             (reel.viewCount || 0);

      const daysSinceCreation = (Date.now() - new Date(reel.createdAt).getTime()) / (1000 * 60 * 60 * 24);
      const recencyBonus = Math.max(0, 10 - daysSinceCreation);

      reel.finalScore = interestScore * 2 + engagementScore * 0.01 + recencyBonus;

      return reel;
    }).sort((a, b) => b.finalScore - a.finalScore);
  }

  /**
   * Get trending reels for new users without interest data
   */
  static async getTrendingReelsForNewUser(userId, page, limit) {
    const skip = (page - 1) * limit;

    const [reels, total] = await Promise.all([
      Reel.aggregate([
        { $match: { isActive: true } },
        {
          $addFields: {
            engagement: {
              $add: [
                { $ifNull: ['$like.count', 0] },
                { $multiply: [{ $ifNull: ['$comment.count', 0] }, 2] },
              ],
            },
          },
        },
        { $sort: { engagement: -1, createdAt: -1 } },
        { $skip: skip },
        { $limit: limit },
      ]),
      Reel.countDocuments({ isActive: true }),
    ]);

    const result = {
      data: reels,
      pagination: {
        currentPage: page,
        totalPages: Math.ceil(total / limit),
        totalItems: total,
        hasNextPage: page * limit < total,
        hasPrevPage: page > 1,
      },
    };

    return await this.enhanceWithLikeStatus(result, userId);
  }

  /**
   * Get trending reels excluding specific IDs
   */
  static async getTrendingReelsExcluding(excludeIds, limit) {
    return await Reel.find({
      isActive: true,
      _id: { $nin: excludeIds },
    })
      .sort({ 'like.count': -1, createdAt: -1 })
      .limit(limit)
      .lean();
  }

  /**
   * Enhance reels with like status for the current user
   */
  static async enhanceWithLikeStatus(result, userId) {
    if (!userId || !result.data || result.data.length === 0) {
      return result;
    }

    const reelIds = result.data.map(reel => reel._id);
    const likes = await Like.find({
      reel: { $in: reelIds },
      userId,
    }).lean();

    const likedReelIds = new Set(likes.map(like => like.reel.toString()));

    result.data = result.data.map(reel => ({
      ...reel,
      like: {
        ...(reel.like || {}),
        isLiked: likedReelIds.has(reel._id.toString()),
      },
    }));

    return result;
  }

  /**
   * Record user interaction with a reel
   */
  static async recordInteraction(userId, reelId, interactionType) {
    const validTypes = ['view', 'like', 'comment', 'share', 'save'];
    if (!validTypes.includes(interactionType)) {
      throw new Error(`Invalid interaction type: ${interactionType}`);
    }

    // Get or create user interest profile
    let userInterest = await ReelUserInterest.findOrCreate(userId);

    // Get the reel to extract tags
    const reel = await Reel.findById(reelId).lean();
    if (!reel) {
      throw new Error('Reel not found');
    }

    // Get score increment based on interaction type
    const scoreIncrement = REEL_INTEREST_CONSTANTS.INTERACTION_SCORES[interactionType];

    // Extract tags from reel
    let tags = reel.tags || [];

    // If no tags array, extract from description
    if (tags.length === 0 && reel.description) {
      tags = extractHashtags(reel.description);
    }

    // Update interests for each tag
    if (tags.length > 0) {
      userInterest.updateInterests(tags, scoreIncrement);
    }

    // Add to recent views if it's a view interaction
    if (interactionType === 'view') {
      userInterest.addView(reelId);
      userInterest.interactionCounts.views += 1;
    } else if (interactionType === 'like') {
      userInterest.interactionCounts.likes += 1;
    } else if (interactionType === 'comment') {
      userInterest.interactionCounts.comments += 1;
    } else if (interactionType === 'share') {
      userInterest.interactionCounts.shares += 1;
    }

    // Recalculate engagement level
    userInterest.calculateEngagementLevel();

    // Save user interest
    await userInterest.save();

    // Clear recommendation cache for this user
    try {
      const keys = await redis.keys(`reels:recommended:${userId}:*`);
      if (keys.length > 0) {
        await redis.del(...keys);
      }
    } catch (redisError) {
      console.warn('Redis cache clear error:', redisError.message);
    }

    return {
      success: true,
      engagementLevel: userInterest.engagementLevel,
      interactionCounts: userInterest.interactionCounts,
    };
  }

  /**
   * Get user's interest profile
   */
  static async getUserInterests(userId) {
    const userInterest = await ReelUserInterest.findOne({ userId }).lean();

    if (!userInterest) {
      return {
        interests: [],
        engagementLevel: 'low',
        interactionCounts: { views: 0, likes: 0, comments: 0, shares: 0 },
      };
    }

    return {
      interests: userInterest.interests
        .sort((a, b) => b.score - a.score)
        .slice(0, 20),
      engagementLevel: userInterest.engagementLevel,
      interactionCounts: userInterest.interactionCounts,
      lastActive: userInterest.lastActive,
    };
  }

  /**
   * Sync tags from description to tags array for existing reels
   * (Utility method for data migration)
   */
  static async syncReelTags(reelId = null) {
    const query = reelId ? { _id: reelId } : {};
    const reels = await Reel.find(query);

    let updatedCount = 0;

    for (const reel of reels) {
      if (reel.description) {
        const tags = extractHashtags(reel.description);
        if (tags.length > 0) {
          reel.tags = tags;
          await reel.save();
          updatedCount++;
        }
      }
    }

    return { updatedCount };
  }

  /**
   * Initialize user interests from their activity history
   */
  static async initializeUserInterests(userId) {
    // Find all reels the user has liked
    const likes = await Like.find({ userId }).populate('reel');

    let userInterest = await ReelUserInterest.findOrCreate(userId);

    for (const like of likes) {
      if (like.reel && like.reel.description) {
        const tags = extractHashtags(like.reel.description);
        userInterest.updateInterests(tags, REEL_INTEREST_CONSTANTS.INTERACTION_SCORES.like);
      }
    }

    userInterest.calculateEngagementLevel();
    await userInterest.save();

    return userInterest;
  }
}

module.exports = RecommendationService;
