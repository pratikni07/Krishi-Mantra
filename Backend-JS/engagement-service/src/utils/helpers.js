/**
 * Utility helpers for engagement service
 */

const { ENGAGEMENT_LEVELS, ENGAGEMENT_THRESHOLDS, CHURN_RISK_LEVELS, CHURN_RISK_THRESHOLDS } = require('./constants');

/**
 * Get today's date string in YYYY-MM-DD format
 */
const getTodayString = () => {
  return new Date().toISOString().split('T')[0];
};

/**
 * Get date string for N days ago
 */
const getDateStringDaysAgo = (days) => {
  const date = new Date();
  date.setDate(date.getDate() - days);
  return date.toISOString().split('T')[0];
};

/**
 * Get start and end of day in UTC
 */
const getDayBounds = (date = new Date()) => {
  const start = new Date(date);
  start.setUTCHours(0, 0, 0, 0);

  const end = new Date(date);
  end.setUTCHours(23, 59, 59, 999);

  return { start, end };
};

/**
 * Get current hour in HH format
 */
const getCurrentHour = () => {
  return new Date().getUTCHours().toString().padStart(2, '0');
};

/**
 * Calculate engagement level based on score
 */
const getEngagementLevel = (score) => {
  if (score >= ENGAGEMENT_THRESHOLDS.POWER_USER) return ENGAGEMENT_LEVELS.POWER_USER;
  if (score >= ENGAGEMENT_THRESHOLDS.HIGH) return ENGAGEMENT_LEVELS.HIGH;
  if (score >= ENGAGEMENT_THRESHOLDS.MEDIUM) return ENGAGEMENT_LEVELS.MEDIUM;
  if (score >= ENGAGEMENT_THRESHOLDS.LOW) return ENGAGEMENT_LEVELS.LOW;
  return ENGAGEMENT_LEVELS.INACTIVE;
};

/**
 * Calculate churn risk level based on score
 */
const getChurnRiskLevel = (score) => {
  if (score >= CHURN_RISK_THRESHOLDS.CRITICAL) return CHURN_RISK_LEVELS.CRITICAL;
  if (score >= CHURN_RISK_THRESHOLDS.HIGH) return CHURN_RISK_LEVELS.HIGH;
  if (score >= CHURN_RISK_THRESHOLDS.MEDIUM) return CHURN_RISK_LEVELS.MEDIUM;
  return CHURN_RISK_LEVELS.LOW;
};

/**
 * Calculate engagement score based on activities
 * Optimized formula for agricultural app engagement
 */
const calculateEngagementScore = (activities) => {
  const weights = {
    feedViews: 1,
    feedLikes: 3,
    feedComments: 5,
    feedCreates: 10,
    reelViews: 1,
    reelLikes: 3,
    reelComments: 5,
    reelCompletes: 2,
    productViews: 2,
    productInquiries: 8,
    chatMessages: 4,
    aiChats: 6,
    schemeViews: 2,
    weatherChecks: 1,
    cropCalendarViews: 2,
    videoTutorialViews: 3,
    screenViews: 0.5,
    sessionDuration: 0.01, // per second
  };

  let score = 0;

  for (const [key, weight] of Object.entries(weights)) {
    if (activities[key]) {
      score += activities[key] * weight;
    }
  }

  // Normalize to 0-100 scale with diminishing returns
  return Math.min(100, Math.round(Math.log10(score + 1) * 25));
};

/**
 * Calculate churn risk based on user behavior
 */
const calculateChurnRisk = (userMetrics) => {
  const factors = [];
  let riskScore = 0;

  const now = new Date();
  const lastActivity = userMetrics.activity?.lastActivity
    ? new Date(userMetrics.activity.lastActivity)
    : null;

  // Days since last activity
  if (lastActivity) {
    const daysSinceActivity = Math.floor((now - lastActivity) / (1000 * 60 * 60 * 24));

    if (daysSinceActivity > 14) {
      riskScore += 40;
      factors.push('inactive_14_days');
    } else if (daysSinceActivity > 7) {
      riskScore += 25;
      factors.push('inactive_7_days');
    } else if (daysSinceActivity > 3) {
      riskScore += 10;
      factors.push('inactive_3_days');
    }
  } else {
    riskScore += 30;
    factors.push('no_activity_recorded');
  }

  // Session frequency decline
  const sessionsLast7 = userMetrics.sessions?.last7Days || 0;
  const sessionsLast30 = userMetrics.sessions?.last30Days || 0;
  const avgWeeklySessions = sessionsLast30 / 4;

  if (avgWeeklySessions > 0 && sessionsLast7 < avgWeeklySessions * 0.5) {
    riskScore += 20;
    factors.push('session_frequency_decline');
  }

  // Engagement score decline
  const currentScore = userMetrics.engagementScore?.current || 0;
  const previousScore = userMetrics.engagementScore?.last7Days || 0;

  if (previousScore > 0 && currentScore < previousScore * 0.5) {
    riskScore += 15;
    factors.push('engagement_score_decline');
  }

  // Low overall engagement
  if (currentScore < 10) {
    riskScore += 10;
    factors.push('low_engagement');
  }

  // Streak broken
  if (userMetrics.activity?.streakLongest > 7 && userMetrics.activity?.streakCurrent === 0) {
    riskScore += 10;
    factors.push('streak_broken');
  }

  return {
    score: Math.min(100, riskScore),
    level: getChurnRiskLevel(riskScore),
    factors,
    calculatedAt: new Date(),
  };
};

/**
 * Generate a unique session ID
 */
const generateSessionId = (userId) => {
  const timestamp = Date.now().toString(36);
  const random = Math.random().toString(36).substr(2, 9);
  return `${userId}_${timestamp}_${random}`;
};

/**
 * Batch array into chunks
 */
const batchArray = (array, batchSize) => {
  const batches = [];
  for (let i = 0; i < array.length; i += batchSize) {
    batches.push(array.slice(i, i + batchSize));
  }
  return batches;
};

/**
 * Retry function with exponential backoff
 */
const retryWithBackoff = async (fn, maxRetries = 3, baseDelay = 1000) => {
  let lastError;

  for (let attempt = 0; attempt < maxRetries; attempt++) {
    try {
      return await fn();
    } catch (error) {
      lastError = error;
      if (attempt < maxRetries - 1) {
        const delay = baseDelay * Math.pow(2, attempt);
        await new Promise((resolve) => setTimeout(resolve, delay));
      }
    }
  }

  throw lastError;
};

/**
 * Safe JSON parse
 */
const safeJsonParse = (str, defaultValue = null) => {
  try {
    return JSON.parse(str);
  } catch {
    return defaultValue;
  }
};

/**
 * Validate event data
 */
const validateEventData = (event) => {
  const errors = [];

  if (!event.userId) errors.push('userId is required');
  if (!event.eventName) errors.push('eventName is required');
  if (!event.sessionId) errors.push('sessionId is required');

  return {
    isValid: errors.length === 0,
    errors,
  };
};

/**
 * Sanitize user input
 */
const sanitizeInput = (input) => {
  if (typeof input !== 'string') return input;

  return input
    .replace(/[<>]/g, '') // Remove potential HTML tags
    .trim()
    .substring(0, 1000); // Limit length
};

/**
 * Calculate percentile
 */
const calculatePercentile = (value, sortedArray) => {
  if (sortedArray.length === 0) return 0;

  let count = 0;
  for (const v of sortedArray) {
    if (v <= value) count++;
  }

  return Math.round((count / sortedArray.length) * 100);
};

/**
 * Format duration (seconds) to human readable
 */
const formatDuration = (seconds) => {
  if (seconds < 60) return `${seconds}s`;
  if (seconds < 3600) return `${Math.floor(seconds / 60)}m ${seconds % 60}s`;
  return `${Math.floor(seconds / 3600)}h ${Math.floor((seconds % 3600) / 60)}m`;
};

module.exports = {
  getTodayString,
  getDateStringDaysAgo,
  getDayBounds,
  getCurrentHour,
  getEngagementLevel,
  getChurnRiskLevel,
  calculateEngagementScore,
  calculateChurnRisk,
  generateSessionId,
  batchArray,
  retryWithBackoff,
  safeJsonParse,
  validateEventData,
  sanitizeInput,
  calculatePercentile,
  formatDuration,
};
