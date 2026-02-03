/**
 * Subscription Service for Message Service
 * Fetches subscription limits from main-service
 */

const axios = require('axios');
const redis = require('../config/redis');

// Default limits for free tier
const DEFAULT_LIMITS = {
  planName: 'KISAN',
  aiMessagesPerDay: 5,
  imageAnalysisPerDay: 2,
  consultantChatsPerDay: 10,
  videoConsultationsPerMonth: 0,
};

// Plan-based limits (fallback if main-service is unavailable)
const PLAN_LIMITS = {
  KISAN: {
    aiMessagesPerDay: 5,
    imageAnalysisPerDay: 2,
    consultantChatsPerDay: 10,
    videoConsultationsPerMonth: 0,
  },
  KISAN_PRO: {
    aiMessagesPerDay: 50,
    imageAnalysisPerDay: 20,
    consultantChatsPerDay: 50,
    videoConsultationsPerMonth: 0,
  },
  KISAN_PLUS: {
    aiMessagesPerDay: -1, // Unlimited
    imageAnalysisPerDay: -1,
    consultantChatsPerDay: -1,
    videoConsultationsPerMonth: 2,
  },
  KISAN_MEGA: {
    aiMessagesPerDay: -1,
    imageAnalysisPerDay: -1,
    consultantChatsPerDay: -1,
    videoConsultationsPerMonth: -1,
  },
};

class SubscriptionService {
  constructor() {
    this.mainServiceUrl = process.env.MAIN_SERVICE_URL || 'http://localhost:3002';
    this.cacheTTL = 300; // 5 minutes
  }

  /**
   * Get user's subscription limits
   */
  async getUserLimits(userId) {
    try {
      // Try cache first
      const cacheKey = `subscription:limits:${userId}`;
      const cached = await redis.get(cacheKey);

      if (cached) {
        return JSON.parse(cached);
      }

      // Fetch from main-service
      const response = await axios.get(
        `${this.mainServiceUrl}/subscription/usage`,
        {
          headers: {
            'X-User-Id': userId,
            'X-Internal-Request': 'true',
          },
          timeout: 5000,
        }
      );

      if (response.data.success) {
        const limits = {
          planName: response.data.data.planName,
          ...response.data.data.limits,
          usage: response.data.data.usage,
          remaining: response.data.data.remaining,
        };

        // Cache for 5 minutes
        await redis.set(cacheKey, JSON.stringify(limits), this.cacheTTL);
        return limits;
      }

      return DEFAULT_LIMITS;
    } catch (error) {
      console.error('Error fetching subscription limits:', error.message);
      // Return default limits on error
      return DEFAULT_LIMITS;
    }
  }

  /**
   * Check if user can use AI message feature
   */
  async checkAiMessageLimit(userId) {
    try {
      const limits = await this.getUserLimits(userId);

      // Unlimited for premium plans
      if (limits.aiMessagesPerDay === -1) {
        return {
          canProceed: true,
          remaining: -1,
          limit: -1,
          isUnlimited: true,
          planName: limits.planName,
        };
      }

      // Check remaining
      const remaining = limits.remaining?.aiMessages ?? (limits.aiMessagesPerDay - (limits.usage?.aiMessagesUsed || 0));

      return {
        canProceed: remaining > 0,
        remaining: Math.max(0, remaining),
        limit: limits.aiMessagesPerDay,
        used: limits.usage?.aiMessagesUsed || 0,
        isUnlimited: false,
        planName: limits.planName,
      };
    } catch (error) {
      console.error('Error checking AI message limit:', error);
      // Default to allowing with free tier limit
      return {
        canProceed: true,
        remaining: DEFAULT_LIMITS.aiMessagesPerDay,
        limit: DEFAULT_LIMITS.aiMessagesPerDay,
        isUnlimited: false,
        planName: 'KISAN',
      };
    }
  }

  /**
   * Check if user can use image analysis feature
   */
  async checkImageAnalysisLimit(userId) {
    try {
      const limits = await this.getUserLimits(userId);

      if (limits.imageAnalysisPerDay === -1) {
        return {
          canProceed: true,
          remaining: -1,
          limit: -1,
          isUnlimited: true,
          planName: limits.planName,
        };
      }

      const remaining = limits.remaining?.imageAnalysis ?? (limits.imageAnalysisPerDay - (limits.usage?.imageAnalysisUsed || 0));

      return {
        canProceed: remaining > 0,
        remaining: Math.max(0, remaining),
        limit: limits.imageAnalysisPerDay,
        used: limits.usage?.imageAnalysisUsed || 0,
        isUnlimited: false,
        planName: limits.planName,
      };
    } catch (error) {
      console.error('Error checking image analysis limit:', error);
      return {
        canProceed: true,
        remaining: DEFAULT_LIMITS.imageAnalysisPerDay,
        limit: DEFAULT_LIMITS.imageAnalysisPerDay,
        isUnlimited: false,
        planName: 'KISAN',
      };
    }
  }

  /**
   * Check if user can use consultant chat feature
   */
  async checkConsultantChatLimit(userId) {
    try {
      const limits = await this.getUserLimits(userId);

      if (limits.consultantChatsPerDay === -1) {
        return {
          canProceed: true,
          remaining: -1,
          limit: -1,
          isUnlimited: true,
          planName: limits.planName,
        };
      }

      const remaining = limits.remaining?.consultantChats ?? (limits.consultantChatsPerDay - (limits.usage?.consultantChatsUsed || 0));

      return {
        canProceed: remaining > 0,
        remaining: Math.max(0, remaining),
        limit: limits.consultantChatsPerDay,
        used: limits.usage?.consultantChatsUsed || 0,
        isUnlimited: false,
        planName: limits.planName,
      };
    } catch (error) {
      console.error('Error checking consultant chat limit:', error);
      return {
        canProceed: true,
        remaining: DEFAULT_LIMITS.consultantChatsPerDay,
        limit: DEFAULT_LIMITS.consultantChatsPerDay,
        isUnlimited: false,
        planName: 'KISAN',
      };
    }
  }

  /**
   * Increment usage after successful operation
   */
  async incrementUsage(userId, feature) {
    try {
      // Clear cache so next request fetches fresh data
      const cacheKey = `subscription:limits:${userId}`;
      await redis.del(cacheKey);

      // Notify main-service about usage (fire and forget)
      axios.post(
        `${this.mainServiceUrl}/subscription/increment-usage`,
        {
          userId,
          feature,
        },
        {
          headers: {
            'X-Internal-Request': 'true',
          },
          timeout: 3000,
        }
      ).catch((err) => {
        console.error('Error incrementing usage:', err.message);
      });

      return true;
    } catch (error) {
      console.error('Error incrementing usage:', error);
      return false;
    }
  }

  /**
   * Get limits by plan name (static helper)
   */
  getLimitsByPlan(planName) {
    return PLAN_LIMITS[planName] || PLAN_LIMITS.KISAN;
  }

  /**
   * Clear user's limit cache
   */
  async clearCache(userId) {
    const cacheKey = `subscription:limits:${userId}`;
    await redis.del(cacheKey);
  }
}

module.exports = new SubscriptionService();
