/**
 * Message Limit Service
 * Handles rate limiting for AI messages based on subscription plan
 */

const SubscriptionService = require('./subscription.service');

class MessageLimitService {
  constructor() {
    // Default free tier limit (fallback)
    this.FREE_DAILY_LIMIT = 5;
  }

  /**
   * Check and update message count based on subscription
   */
  async checkAndUpdateMessageCount(userId, incrementBy = 1) {
    try {
      // Check subscription limits
      const limitCheck = await SubscriptionService.checkAiMessageLimit(userId);

      // Unlimited for premium users
      if (limitCheck.isUnlimited) {
        return {
          canSendMessage: true,
          remainingMessages: null,
          isLimited: false,
          planName: limitCheck.planName,
        };
      }

      // Check if can proceed
      if (!limitCheck.canProceed) {
        return {
          canSendMessage: false,
          remainingMessages: 0,
          isLimited: true,
          planName: limitCheck.planName,
          limit: limitCheck.limit,
        };
      }

      // Increment usage if proceeding
      if (incrementBy > 0) {
        await SubscriptionService.incrementUsage(userId, 'aiMessage');
      }

      return {
        canSendMessage: true,
        remainingMessages: Math.max(0, limitCheck.remaining - incrementBy),
        isLimited: true,
        planName: limitCheck.planName,
        limit: limitCheck.limit,
      };
    } catch (error) {
      console.error('Error checking message limits:', error);
      // Fallback to legacy behavior on error
      return this.legacyCheckMessageCount(userId, incrementBy);
    }
  }

  /**
   * Check image analysis limit
   */
  async checkImageAnalysisLimit(userId) {
    try {
      const limitCheck = await SubscriptionService.checkImageAnalysisLimit(userId);

      if (limitCheck.isUnlimited) {
        return {
          canProceed: true,
          remaining: null,
          isLimited: false,
          planName: limitCheck.planName,
        };
      }

      return {
        canProceed: limitCheck.canProceed,
        remaining: limitCheck.remaining,
        limit: limitCheck.limit,
        used: limitCheck.used,
        isLimited: true,
        planName: limitCheck.planName,
      };
    } catch (error) {
      console.error('Error checking image analysis limit:', error);
      return {
        canProceed: true,
        remaining: 2,
        limit: 2,
        isLimited: true,
        planName: 'KISAN',
      };
    }
  }

  /**
   * Check consultant chat limit
   */
  async checkConsultantChatLimit(userId) {
    try {
      const limitCheck = await SubscriptionService.checkConsultantChatLimit(userId);

      if (limitCheck.isUnlimited) {
        return {
          canProceed: true,
          remaining: null,
          isLimited: false,
          planName: limitCheck.planName,
        };
      }

      return {
        canProceed: limitCheck.canProceed,
        remaining: limitCheck.remaining,
        limit: limitCheck.limit,
        used: limitCheck.used,
        isLimited: true,
        planName: limitCheck.planName,
      };
    } catch (error) {
      console.error('Error checking consultant chat limit:', error);
      return {
        canProceed: true,
        remaining: 10,
        limit: 10,
        isLimited: true,
        planName: 'KISAN',
      };
    }
  }

  /**
   * Increment image analysis usage
   */
  async incrementImageAnalysisUsage(userId) {
    try {
      await SubscriptionService.incrementUsage(userId, 'imageAnalysis');
      return true;
    } catch (error) {
      console.error('Error incrementing image analysis usage:', error);
      return false;
    }
  }

  /**
   * Increment consultant chat usage
   */
  async incrementConsultantChatUsage(userId) {
    try {
      await SubscriptionService.incrementUsage(userId, 'consultantChat');
      return true;
    } catch (error) {
      console.error('Error incrementing consultant chat usage:', error);
      return false;
    }
  }

  /**
   * Get limit info for a user
   */
  async getLimitInfo(userId) {
    try {
      const limits = await SubscriptionService.getUserLimits(userId);

      return {
        planName: limits.planName,
        aiMessages: {
          limit: limits.aiMessagesPerDay,
          used: limits.usage?.aiMessagesUsed || 0,
          remaining: limits.remaining?.aiMessages ?? limits.aiMessagesPerDay,
          isUnlimited: limits.aiMessagesPerDay === -1,
        },
        imageAnalysis: {
          limit: limits.imageAnalysisPerDay,
          used: limits.usage?.imageAnalysisUsed || 0,
          remaining: limits.remaining?.imageAnalysis ?? limits.imageAnalysisPerDay,
          isUnlimited: limits.imageAnalysisPerDay === -1,
        },
        consultantChats: {
          limit: limits.consultantChatsPerDay,
          used: limits.usage?.consultantChatsUsed || 0,
          remaining: limits.remaining?.consultantChats ?? limits.consultantChatsPerDay,
          isUnlimited: limits.consultantChatsPerDay === -1,
        },
        resetsAt: new Date(new Date().setHours(24, 0, 0, 0)),
      };
    } catch (error) {
      console.error('Error getting limit info:', error);
      return {
        planName: 'KISAN',
        aiMessages: {
          limit: this.FREE_DAILY_LIMIT,
          used: 0,
          remaining: this.FREE_DAILY_LIMIT,
          isUnlimited: false,
        },
        imageAnalysis: {
          limit: 2,
          used: 0,
          remaining: 2,
          isUnlimited: false,
        },
        consultantChats: {
          limit: 10,
          used: 0,
          remaining: 10,
          isUnlimited: false,
        },
        resetsAt: new Date(new Date().setHours(24, 0, 0, 0)),
      };
    }
  }

  /**
   * Legacy message count check (fallback)
   */
  async legacyCheckMessageCount(userId, incrementBy = 1) {
    try {
      const user = await require('../models/user.model').findOne({ userId });
      if (user && user.isPremium) {
        return {
          canSendMessage: true,
          remainingMessages: null,
          isLimited: false,
        };
      }

      const AIChat = require('../models/ai-chat.model');
      const today = new Date();
      today.setHours(0, 0, 0, 0);

      const latestChat = await AIChat.findOne(
        { userId, 'dailyMessageCount.lastResetDate': { $gte: today } },
        { dailyMessageCount: 1 }
      ).sort({ 'dailyMessageCount.lastResetDate': -1 });

      if (!latestChat || latestChat.dailyMessageCount.lastResetDate < today) {
        await AIChat.updateMany(
          { userId },
          {
            $set: {
              'dailyMessageCount.count': incrementBy,
              'dailyMessageCount.lastResetDate': new Date(),
            },
          }
        );
        return {
          canSendMessage: true,
          remainingMessages: this.FREE_DAILY_LIMIT - incrementBy,
          isLimited: true,
        };
      }

      const currentCount = latestChat.dailyMessageCount.count;

      if (currentCount + incrementBy > this.FREE_DAILY_LIMIT) {
        return {
          canSendMessage: false,
          remainingMessages: Math.max(0, this.FREE_DAILY_LIMIT - currentCount),
          isLimited: true,
        };
      }

      await AIChat.updateMany(
        { userId, 'dailyMessageCount.lastResetDate': { $gte: today } },
        { $inc: { 'dailyMessageCount.count': incrementBy } }
      );

      return {
        canSendMessage: true,
        remainingMessages: this.FREE_DAILY_LIMIT - (currentCount + incrementBy),
        isLimited: true,
      };
    } catch (error) {
      console.error('Error in legacy message check:', error);
      return {
        canSendMessage: true,
        remainingMessages: null,
        isLimited: false,
        error: error.message,
      };
    }
  }
}

module.exports = new MessageLimitService();
