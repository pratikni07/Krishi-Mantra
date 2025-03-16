const UserInterest = require("../model/userInterest");
const Feed = require("../model/FeedModel");
const redis = require("../config/redis");
const { extractTags } = require("./contentUtils");

const USER_INTEREST_CACHE_KEY = "user-interest:";
const RECOMMENDED_FEEDS_CACHE_KEY = "recommended-feeds:";

/**
 * Updates user interest based on content interaction
 * @param {string} userId - User ID 
 * @param {string} feedId - Feed ID
 * @param {string} interactionType - Type of interaction (view, like, comment, share, save)
 * @returns {Promise<void>}
 */
async function updateUserInterestForInteraction(userId, feedId, interactionType) {
  try {
    // Skip if no userId provided
    if (!userId) return;
    
    const feed = await Feed.findById(feedId);
    if (!feed) {
      console.error(`Feed ${feedId} not found when updating user interest`);
      return;
    }

    // Find or create user interest
    let userInterest = await UserInterest.findOne({ userId });
    if (!userInterest) {
      userInterest = new UserInterest({
        userId,
        interests: [],
        recentViews: [],
        engagementLevel: "low",
      });
    }

    // Update user's last active timestamp
    userInterest.lastActive = new Date();

    // Extract tags from feed content
    const tags = extractTags(feed.content);
    
    // Set interaction score based on type
    const interactionScore = {
      view: 0.2,
      like: 0.5,
      unlike: -0.3, // Negative score for unlike
      comment: 1.0,
      share: 1.5,
      save: 1.2,
    }[interactionType] || 0.1;

    // Update interest scores for each tag
    for (const tag of tags) {
      const existingInterest = userInterest.interests.find(
        (i) => i.tag === tag
      );
      
      if (existingInterest) {
        existingInterest.score += interactionScore;
        // Ensure score doesn't go below zero for unlikes
        if (existingInterest.score < 0) existingInterest.score = 0;
        existingInterest.lastInteraction = new Date();
      } else if (interactionScore > 0) { // Only create new interests for positive interactions
        userInterest.interests.push({
          tag,
          score: interactionScore,
          lastInteraction: new Date(),
        });
      }
    }

    // Record view if interaction type is "view"
    if (interactionType === "view") {
      // Check if already viewed
      const alreadyViewed = userInterest.recentViews.some(
        (view) => view.feedId.toString() === feedId.toString()
      );

      // Add to recent views or update timestamp
      const viewIndex = userInterest.recentViews.findIndex(
        (view) => view.feedId.toString() === feedId.toString()
      );

      if (viewIndex >= 0) {
        userInterest.recentViews[viewIndex].viewedAt = new Date();
      } else {
        userInterest.recentViews.push({
          feedId,
          viewedAt: new Date(),
        });
      }

      // Limit to most recent 500 views
      if (userInterest.recentViews.length > 500) {
        userInterest.recentViews = userInterest.recentViews
          .sort((a, b) => b.viewedAt - a.viewedAt)
          .slice(0, 500);
      }
    }

    // Calculate user engagement level based on interaction patterns
    const lastMonthInteractions = userInterest.recentViews.filter(
      (view) => new Date() - new Date(view.viewedAt) < 30 * 24 * 60 * 60 * 1000
    ).length;

    if (lastMonthInteractions > 100) {
      userInterest.engagementLevel = "high";
    } else if (lastMonthInteractions > 30) {
      userInterest.engagementLevel = "medium";
    } else {
      userInterest.engagementLevel = "low";
    }

    await userInterest.save();
    
    // Invalidate caches
    await redis.del(`${USER_INTEREST_CACHE_KEY}${userId}`);
    await redis.del(`${RECOMMENDED_FEEDS_CACHE_KEY}${userId}`);

    return userInterest;
  } catch (error) {
    console.error("Error updating user interest:", error);
  }
}

module.exports = {
  updateUserInterestForInteraction
}; 