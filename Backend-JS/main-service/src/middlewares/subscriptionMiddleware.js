/**
 * Subscription Middleware
 * Middleware for checking subscription limits and feature access
 */

const { checkUserFeatureAccess, incrementUsage } = require('../controller/SubscriptionController');
const { HTTP_STATUS } = require('../utils/constants');
const logger = require('../utils/logger');

/**
 * Check AI message limit
 */
const checkAiMessageLimit = async (req, res, next) => {
  try {
    const userId = req.user?._id;

    if (!userId) {
      return res.status(HTTP_STATUS.UNAUTHORIZED).json({
        success: false,
        message: 'Authentication required',
      });
    }

    const access = await checkUserFeatureAccess(userId, 'aiMessage');

    if (!access.allowed) {
      return res.status(HTTP_STATUS.FORBIDDEN).json({
        success: false,
        message: 'Daily AI message limit reached. Upgrade your plan for more messages.',
        code: 'AI_LIMIT_REACHED',
        data: {
          limit: access.limit,
          used: access.used,
          remaining: 0,
          upgradeRequired: true,
        },
      });
    }

    // Attach access info to request
    req.aiAccess = access;
    next();
  } catch (error) {
    logger.error('Error checking AI message limit:', error);
    next(error);
  }
};

/**
 * Check image analysis limit
 */
const checkImageAnalysisLimit = async (req, res, next) => {
  try {
    const userId = req.user?._id;

    if (!userId) {
      return res.status(HTTP_STATUS.UNAUTHORIZED).json({
        success: false,
        message: 'Authentication required',
      });
    }

    const access = await checkUserFeatureAccess(userId, 'imageAnalysis');

    if (!access.allowed) {
      return res.status(HTTP_STATUS.FORBIDDEN).json({
        success: false,
        message: 'Daily image analysis limit reached. Upgrade your plan for more analyses.',
        code: 'IMAGE_ANALYSIS_LIMIT_REACHED',
        data: {
          limit: access.limit,
          used: access.used,
          remaining: 0,
          upgradeRequired: true,
        },
      });
    }

    req.imageAnalysisAccess = access;
    next();
  } catch (error) {
    logger.error('Error checking image analysis limit:', error);
    next(error);
  }
};

/**
 * Check consultant chat limit
 */
const checkConsultantChatLimit = async (req, res, next) => {
  try {
    const userId = req.user?._id;

    if (!userId) {
      return res.status(HTTP_STATUS.UNAUTHORIZED).json({
        success: false,
        message: 'Authentication required',
      });
    }

    const access = await checkUserFeatureAccess(userId, 'consultantChat');

    if (!access.allowed) {
      return res.status(HTTP_STATUS.FORBIDDEN).json({
        success: false,
        message: 'Daily consultant chat limit reached. Upgrade your plan for more chats.',
        code: 'CONSULTANT_CHAT_LIMIT_REACHED',
        data: {
          limit: access.limit,
          used: access.used,
          remaining: 0,
          upgradeRequired: true,
        },
      });
    }

    req.consultantChatAccess = access;
    next();
  } catch (error) {
    logger.error('Error checking consultant chat limit:', error);
    next(error);
  }
};

/**
 * Check if user can create posts
 */
const checkCanCreatePost = async (req, res, next) => {
  try {
    const userId = req.user?._id;
    const accountType = req.user?.accountType;

    // Admins and consultants can always create posts
    if (accountType === 'admin' || accountType === 'consultant') {
      return next();
    }

    if (!userId) {
      return res.status(HTTP_STATUS.UNAUTHORIZED).json({
        success: false,
        message: 'Authentication required',
      });
    }

    const access = await checkUserFeatureAccess(userId, 'createPost');

    if (!access.allowed) {
      return res.status(HTTP_STATUS.FORBIDDEN).json({
        success: false,
        message: 'Your plan does not allow creating posts. Upgrade to Kisan Pro or higher.',
        code: 'CREATE_POST_NOT_ALLOWED',
        data: {
          upgradeRequired: true,
          requiredPlan: 'KISAN_PRO',
        },
      });
    }

    next();
  } catch (error) {
    logger.error('Error checking create post permission:', error);
    next(error);
  }
};

/**
 * Check if user can create reels
 */
const checkCanCreateReel = async (req, res, next) => {
  try {
    const userId = req.user?._id;
    const accountType = req.user?.accountType;

    // Admins and consultants can always create reels
    if (accountType === 'admin' || accountType === 'consultant') {
      return next();
    }

    if (!userId) {
      return res.status(HTTP_STATUS.UNAUTHORIZED).json({
        success: false,
        message: 'Authentication required',
      });
    }

    const access = await checkUserFeatureAccess(userId, 'createReel');

    if (!access.allowed) {
      return res.status(HTTP_STATUS.FORBIDDEN).json({
        success: false,
        message: 'Your plan does not allow creating reels. Upgrade to Kisan Plus or higher.',
        code: 'CREATE_REEL_NOT_ALLOWED',
        data: {
          upgradeRequired: true,
          requiredPlan: 'KISAN_PLUS',
        },
      });
    }

    next();
  } catch (error) {
    logger.error('Error checking create reel permission:', error);
    next(error);
  }
};

/**
 * Check marketplace listing limit
 */
const checkMarketplaceLimit = async (req, res, next) => {
  try {
    const userId = req.user?._id;
    const accountType = req.user?.accountType;

    // Admins and marketplace accounts have unlimited access
    if (accountType === 'admin' || accountType === 'marketplace') {
      return next();
    }

    if (!userId) {
      return res.status(HTTP_STATUS.UNAUTHORIZED).json({
        success: false,
        message: 'Authentication required',
      });
    }

    const access = await checkUserFeatureAccess(userId, 'marketplaceListing');

    if (!access.allowed) {
      return res.status(HTTP_STATUS.FORBIDDEN).json({
        success: false,
        message: 'Your plan does not allow marketplace listings. Upgrade to Kisan Plus or higher.',
        code: 'MARKETPLACE_NOT_ALLOWED',
        data: {
          upgradeRequired: true,
          requiredPlan: 'KISAN_PLUS',
        },
      });
    }

    // TODO: Check current listing count against limit
    next();
  } catch (error) {
    logger.error('Error checking marketplace limit:', error);
    next(error);
  }
};

/**
 * Track AI message usage (call after successful AI response)
 */
const trackAiMessageUsage = async (req, res, next) => {
  try {
    const userId = req.user?._id;
    if (userId && req.aiAccess?.limit !== -1) {
      await incrementUsage(userId, 'aiMessage');
    }
    next();
  } catch (error) {
    logger.error('Error tracking AI message usage:', error);
    // Don't fail the request, just log the error
    next();
  }
};

/**
 * Track image analysis usage
 */
const trackImageAnalysisUsage = async (req, res, next) => {
  try {
    const userId = req.user?._id;
    if (userId && req.imageAnalysisAccess?.limit !== -1) {
      await incrementUsage(userId, 'imageAnalysis');
    }
    next();
  } catch (error) {
    logger.error('Error tracking image analysis usage:', error);
    next();
  }
};

/**
 * Track consultant chat usage
 */
const trackConsultantChatUsage = async (req, res, next) => {
  try {
    const userId = req.user?._id;
    if (userId && req.consultantChatAccess?.limit !== -1) {
      await incrementUsage(userId, 'consultantChat');
    }
    next();
  } catch (error) {
    logger.error('Error tracking consultant chat usage:', error);
    next();
  }
};

/**
 * Middleware factory for custom feature checks
 */
const requireFeature = (feature) => {
  return async (req, res, next) => {
    try {
      const userId = req.user?._id;

      if (!userId) {
        return res.status(HTTP_STATUS.UNAUTHORIZED).json({
          success: false,
          message: 'Authentication required',
        });
      }

      const access = await checkUserFeatureAccess(userId, feature);

      if (!access.allowed) {
        return res.status(HTTP_STATUS.FORBIDDEN).json({
          success: false,
          message: `Access to ${feature} is not available with your current plan.`,
          code: 'FEATURE_NOT_ALLOWED',
          data: {
            feature,
            upgradeRequired: true,
          },
        });
      }

      req.featureAccess = access;
      next();
    } catch (error) {
      logger.error(`Error checking feature ${feature}:`, error);
      next(error);
    }
  };
};

/**
 * Add subscription info to request
 */
const attachSubscriptionInfo = async (req, res, next) => {
  try {
    if (!req.user?._id) {
      return next();
    }

    const { UserSubscription } = require('../model/Subscription');
    const stripeConfig = require('../config/stripe');

    const subscription = await UserSubscription.findOne({
      userId: req.user._id,
      status: { $in: ['active', 'trialing'] },
      endDate: { $gt: new Date() },
    }).populate('planId');

    if (subscription?.planId) {
      req.subscription = {
        planName: subscription.planName,
        features: subscription.planId.features,
        endDate: subscription.endDate,
        status: subscription.status,
      };
    } else {
      req.subscription = {
        planName: 'KISAN',
        features: stripeConfig.SUBSCRIPTION_PLANS.KISAN.features,
        endDate: null,
        status: 'free',
      };
    }

    next();
  } catch (error) {
    logger.error('Error attaching subscription info:', error);
    // Don't fail the request
    next();
  }
};

module.exports = {
  checkAiMessageLimit,
  checkImageAnalysisLimit,
  checkConsultantChatLimit,
  checkCanCreatePost,
  checkCanCreateReel,
  checkMarketplaceLimit,
  trackAiMessageUsage,
  trackImageAnalysisUsage,
  trackConsultantChatUsage,
  requireFeature,
  attachSubscriptionInfo,
};
