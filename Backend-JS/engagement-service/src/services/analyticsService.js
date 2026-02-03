/**
 * Analytics Service
 * Provides aggregated analytics and dashboard data
 * Optimized for 100k+ users with caching
 */

const Event = require('../models/event.model');
const Session = require('../models/session.model');
const UserMetrics = require('../models/userMetrics.model');
const DailyMetrics = require('../models/dailyMetrics.model');
const Redis = require('../config/redis');
const logger = require('../utils/logger');
const { CACHE_TTL, ENGAGEMENT_LEVELS, TIME_PERIODS } = require('../utils/constants');
const {
  getTodayString,
  getDateStringDaysAgo,
  calculateEngagementScore,
  calculateChurnRisk,
} = require('../utils/helpers');

class AnalyticsService {
  /**
   * Get dashboard summary
   */
  static async getDashboardSummary(days = 30) {
    try {
      const cacheKey = `dashboard:summary:${days}`;
      const cached = await Redis.get(cacheKey);

      if (cached) {
        return JSON.parse(cached);
      }

      const summary = await DailyMetrics.getDashboardSummary(days);

      if (summary) {
        await Redis.set(cacheKey, JSON.stringify(summary), CACHE_TTL.DASHBOARD_SUMMARY);
      }

      return summary;
    } catch (error) {
      logger.error('Error getting dashboard summary:', error.message);
      return null;
    }
  }

  /**
   * Get real-time statistics
   */
  static async getRealTimeStats() {
    try {
      const cacheKey = 'realtime:stats';
      const cached = await Redis.get(cacheKey);

      if (cached) {
        return JSON.parse(cached);
      }

      const today = getTodayString();
      const client = Redis.getClient();

      // Get counts from Redis
      const [todayEvents, activeUsers, todayMetrics] = await Promise.all([
        Redis.get(`events:count:${today}`),
        client ? client.scard(`users:active:${today}`) : 0,
        DailyMetrics.findOne({ date: today }).lean(),
      ]);

      // Get active sessions count
      const activeSessions = await Session.countDocuments({ isActive: true });

      const stats = {
        timestamp: new Date(),
        today: {
          events: parseInt(todayEvents) || todayMetrics?.events?.total || 0,
          activeUsers: activeUsers || todayMetrics?.users?.dau || 0,
          activeSessions,
          newUsers: todayMetrics?.users?.newUsers || 0,
        },
        content: {
          feedViews: todayMetrics?.content?.feeds?.views || 0,
          feedLikes: todayMetrics?.content?.feeds?.likes || 0,
          reelViews: todayMetrics?.content?.reels?.views || 0,
          reelLikes: todayMetrics?.content?.reels?.likes || 0,
        },
      };

      await Redis.set(cacheKey, JSON.stringify(stats), CACHE_TTL.REAL_TIME_STATS);

      return stats;
    } catch (error) {
      logger.error('Error getting real-time stats:', error.message);
      return null;
    }
  }

  /**
   * Get user engagement breakdown
   */
  static async getEngagementBreakdown(days = 30) {
    try {
      const cacheKey = `analytics:engagement:${days}`;
      const cached = await Redis.get(cacheKey);

      if (cached) {
        return JSON.parse(cached);
      }

      const startDate = getDateStringDaysAgo(days);

      const breakdown = await UserMetrics.aggregate([
        {
          $match: {
            'activity.lastActivity': { $gte: new Date(startDate) },
          },
        },
        {
          $group: {
            _id: '$segments.engagementLevel',
            count: { $sum: 1 },
            avgScore: { $avg: '$engagementScore.current' },
            avgSessions: { $avg: '$sessions.total' },
          },
        },
        {
          $project: {
            level: '$_id',
            count: 1,
            avgScore: { $round: ['$avgScore', 1] },
            avgSessions: { $round: ['$avgSessions', 0] },
          },
        },
        { $sort: { count: -1 } },
      ]);

      // Ensure all levels are represented
      const allLevels = Object.values(ENGAGEMENT_LEVELS);
      const result = allLevels.map((level) => {
        const found = breakdown.find((b) => b.level === level);
        return (
          found || {
            level,
            count: 0,
            avgScore: 0,
            avgSessions: 0,
          }
        );
      });

      await Redis.set(cacheKey, JSON.stringify(result), CACHE_TTL.DASHBOARD_SUMMARY);

      return result;
    } catch (error) {
      logger.error('Error getting engagement breakdown:', error.message);
      return [];
    }
  }

  /**
   * Get feature usage analytics
   */
  static async getFeatureUsage(days = 30) {
    try {
      const cacheKey = `analytics:features:${days}`;
      const cached = await Redis.get(cacheKey);

      if (cached) {
        return JSON.parse(cached);
      }

      const startDate = new Date();
      startDate.setDate(startDate.getDate() - days);

      const usage = await Event.aggregate([
        {
          $match: {
            timestamp: { $gte: startDate },
            eventName: { $in: ['screen_view', 'feed_view', 'reel_view', 'ai_chat_start', 'product_view'] },
          },
        },
        {
          $group: {
            _id: {
              eventName: '$eventName',
              date: { $dateToString: { format: '%Y-%m-%d', date: '$timestamp' } },
            },
            count: { $sum: 1 },
            uniqueUsers: { $addToSet: '$userId' },
          },
        },
        {
          $group: {
            _id: '$_id.eventName',
            totalCount: { $sum: '$count' },
            avgDaily: { $avg: '$count' },
            dailyUniqueUsers: { $avg: { $size: '$uniqueUsers' } },
            trend: {
              $push: {
                date: '$_id.date',
                count: '$count',
              },
            },
          },
        },
        {
          $project: {
            feature: '$_id',
            totalCount: 1,
            avgDaily: { $round: ['$avgDaily', 0] },
            avgDailyUsers: { $round: ['$dailyUniqueUsers', 0] },
            trend: { $slice: [{ $sortArray: { input: '$trend', sortBy: { date: 1 } } }, -7] },
          },
        },
        { $sort: { totalCount: -1 } },
      ]);

      // Map event names to friendly feature names
      const featureMap = {
        feed_view: 'Feed',
        reel_view: 'Reels',
        ai_chat_start: 'AI Assistant',
        product_view: 'Marketplace',
        screen_view: 'Navigation',
      };

      const result = usage.map((u) => ({
        ...u,
        featureName: featureMap[u.feature] || u.feature,
      }));

      await Redis.set(cacheKey, JSON.stringify(result), CACHE_TTL.DASHBOARD_SUMMARY);

      return result;
    } catch (error) {
      logger.error('Error getting feature usage:', error.message);
      return [];
    }
  }

  /**
   * Get retention metrics
   */
  static async getRetentionMetrics(cohortDate) {
    try {
      const cacheKey = `analytics:retention:${cohortDate}`;
      const cached = await Redis.get(cacheKey);

      if (cached) {
        return JSON.parse(cached);
      }

      // Get users who joined on cohort date
      const cohortStart = new Date(cohortDate);
      cohortStart.setUTCHours(0, 0, 0, 0);
      const cohortEnd = new Date(cohortDate);
      cohortEnd.setUTCHours(23, 59, 59, 999);

      const cohortUsers = await UserMetrics.find({
        'activity.firstSeen': { $gte: cohortStart, $lte: cohortEnd },
      }).select('userId');

      const cohortUserIds = cohortUsers.map((u) => u.userId);
      const cohortSize = cohortUserIds.length;

      if (cohortSize === 0) {
        return { cohortDate, cohortSize: 0, retention: {} };
      }

      // Calculate retention for different periods
      const retentionPeriods = [1, 3, 7, 14, 30];
      const retention = {};

      for (const days of retentionPeriods) {
        const periodStart = new Date(cohortDate);
        periodStart.setDate(periodStart.getDate() + days);
        const periodEnd = new Date(periodStart);
        periodEnd.setUTCHours(23, 59, 59, 999);

        // Count users who had activity on that day
        const activeCount = await Event.distinct('userId', {
          userId: { $in: cohortUserIds },
          timestamp: { $gte: periodStart, $lte: periodEnd },
        });

        retention[`day${days}`] = {
          retained: activeCount.length,
          rate: Math.round((activeCount.length / cohortSize) * 100),
        };
      }

      const result = {
        cohortDate,
        cohortSize,
        retention,
      };

      await Redis.set(cacheKey, JSON.stringify(result), CACHE_TTL.DAILY_METRICS);

      return result;
    } catch (error) {
      logger.error('Error getting retention metrics:', error.message);
      return null;
    }
  }

  /**
   * Get churn risk analysis
   */
  static async getChurnRiskAnalysis() {
    try {
      const cacheKey = 'analytics:churn_risk';
      const cached = await Redis.get(cacheKey);

      if (cached) {
        return JSON.parse(cached);
      }

      const analysis = await UserMetrics.aggregate([
        {
          $match: {
            'churnRisk.score': { $exists: true },
          },
        },
        {
          $group: {
            _id: '$churnRisk.level',
            count: { $sum: 1 },
            avgScore: { $avg: '$churnRisk.score' },
            avgEngagement: { $avg: '$engagementScore.current' },
          },
        },
        {
          $project: {
            riskLevel: '$_id',
            count: 1,
            avgScore: { $round: ['$avgScore', 1] },
            avgEngagement: { $round: ['$avgEngagement', 1] },
          },
        },
      ]);

      // Get top churn factors
      const churnFactors = await UserMetrics.aggregate([
        {
          $match: {
            'churnRisk.level': { $in: ['high', 'critical'] },
          },
        },
        { $unwind: '$churnRisk.factors' },
        {
          $group: {
            _id: '$churnRisk.factors',
            count: { $sum: 1 },
          },
        },
        { $sort: { count: -1 } },
        { $limit: 10 },
      ]);

      const result = {
        breakdown: analysis,
        topFactors: churnFactors.map((f) => ({ factor: f._id, count: f.count })),
        timestamp: new Date(),
      };

      await Redis.set(cacheKey, JSON.stringify(result), CACHE_TTL.DASHBOARD_SUMMARY);

      return result;
    } catch (error) {
      logger.error('Error getting churn risk analysis:', error.message);
      return null;
    }
  }

  /**
   * Get top content by engagement
   */
  static async getTopContent(contentType = 'feed', days = 7, limit = 10) {
    try {
      const cacheKey = `analytics:top_content:${contentType}:${days}`;
      const cached = await Redis.get(cacheKey);

      if (cached) {
        return JSON.parse(cached);
      }

      const startDate = new Date();
      startDate.setDate(startDate.getDate() - days);

      const eventNames =
        contentType === 'feed'
          ? ['feed_view', 'feed_like', 'feed_comment', 'feed_share']
          : ['reel_view', 'reel_like', 'reel_comment', 'reel_share'];

      const topContent = await Event.aggregate([
        {
          $match: {
            timestamp: { $gte: startDate },
            eventName: { $in: eventNames },
            'properties.contentId': { $exists: true },
          },
        },
        {
          $group: {
            _id: '$properties.contentId',
            views: {
              $sum: { $cond: [{ $in: ['$eventName', [`${contentType}_view`]] }, 1, 0] },
            },
            likes: {
              $sum: { $cond: [{ $in: ['$eventName', [`${contentType}_like`]] }, 1, 0] },
            },
            comments: {
              $sum: { $cond: [{ $in: ['$eventName', [`${contentType}_comment`]] }, 1, 0] },
            },
            shares: {
              $sum: { $cond: [{ $in: ['$eventName', [`${contentType}_share`]] }, 1, 0] },
            },
            uniqueViewers: { $addToSet: '$userId' },
          },
        },
        {
          $addFields: {
            engagementScore: {
              $add: [
                '$views',
                { $multiply: ['$likes', 3] },
                { $multiply: ['$comments', 5] },
                { $multiply: ['$shares', 7] },
              ],
            },
            uniqueViewerCount: { $size: '$uniqueViewers' },
          },
        },
        { $sort: { engagementScore: -1 } },
        { $limit: limit },
        {
          $project: {
            contentId: '$_id',
            views: 1,
            likes: 1,
            comments: 1,
            shares: 1,
            uniqueViewers: '$uniqueViewerCount',
            engagementScore: 1,
          },
        },
      ]);

      await Redis.set(cacheKey, JSON.stringify(topContent), CACHE_TTL.DASHBOARD_SUMMARY);

      return topContent;
    } catch (error) {
      logger.error('Error getting top content:', error.message);
      return [];
    }
  }

  /**
   * Get hourly activity pattern
   */
  static async getHourlyActivityPattern(days = 7) {
    try {
      const cacheKey = `analytics:hourly_pattern:${days}`;
      const cached = await Redis.get(cacheKey);

      if (cached) {
        return JSON.parse(cached);
      }

      const startDate = new Date();
      startDate.setDate(startDate.getDate() - days);

      const hourlyPattern = await Event.aggregate([
        {
          $match: {
            timestamp: { $gte: startDate },
          },
        },
        {
          $group: {
            _id: { $hour: '$timestamp' },
            events: { $sum: 1 },
            uniqueUsers: { $addToSet: '$userId' },
          },
        },
        {
          $project: {
            hour: '$_id',
            events: 1,
            uniqueUsers: { $size: '$uniqueUsers' },
            avgEvents: { $divide: ['$events', days] },
          },
        },
        { $sort: { hour: 1 } },
      ]);

      // Fill in missing hours
      const result = [];
      for (let hour = 0; hour < 24; hour++) {
        const found = hourlyPattern.find((h) => h.hour === hour);
        result.push({
          hour,
          events: found?.events || 0,
          uniqueUsers: found?.uniqueUsers || 0,
          avgEvents: Math.round(found?.avgEvents || 0),
        });
      }

      await Redis.set(cacheKey, JSON.stringify(result), CACHE_TTL.DASHBOARD_SUMMARY);

      return result;
    } catch (error) {
      logger.error('Error getting hourly activity pattern:', error.message);
      return [];
    }
  }

  /**
   * Get user metrics for specific user
   */
  static async getUserAnalytics(userId) {
    try {
      const cacheKey = `analytics:user:${userId}`;
      const cached = await Redis.get(cacheKey);

      if (cached) {
        return JSON.parse(cached);
      }

      const [userMetrics, recentSessions, recentEvents] = await Promise.all([
        UserMetrics.findOne({ userId }).lean(),
        Session.find({ userId }).sort({ startTime: -1 }).limit(10).lean(),
        Event.find({ userId }).sort({ timestamp: -1 }).limit(50).lean(),
      ]);

      if (!userMetrics) {
        return null;
      }

      const result = {
        userId,
        metrics: userMetrics,
        recentSessions,
        recentActivity: recentEvents.map((e) => ({
          eventName: e.eventName,
          category: e.eventCategory,
          timestamp: e.timestamp,
          properties: e.properties,
        })),
      };

      await Redis.set(cacheKey, JSON.stringify(result), CACHE_TTL.USER_METRICS);

      return result;
    } catch (error) {
      logger.error('Error getting user analytics:', error.message);
      return null;
    }
  }

  /**
   * Get period comparison (e.g., this week vs last week)
   */
  static async getPeriodComparison(period = 'week') {
    try {
      const cacheKey = `analytics:comparison:${period}`;
      const cached = await Redis.get(cacheKey);

      if (cached) {
        return JSON.parse(cached);
      }

      let days;
      switch (period) {
        case 'day':
          days = 1;
          break;
        case 'week':
          days = 7;
          break;
        case 'month':
          days = 30;
          break;
        default:
          days = 7;
      }

      const currentEnd = getTodayString();
      const currentStart = getDateStringDaysAgo(days - 1);
      const previousEnd = getDateStringDaysAgo(days);
      const previousStart = getDateStringDaysAgo(days * 2 - 1);

      const comparison = await DailyMetrics.getPeriodComparison(
        currentStart,
        currentEnd,
        previousStart,
        previousEnd
      );

      await Redis.set(cacheKey, JSON.stringify(comparison), CACHE_TTL.DASHBOARD_SUMMARY);

      return comparison;
    } catch (error) {
      logger.error('Error getting period comparison:', error.message);
      return null;
    }
  }
}

module.exports = AnalyticsService;
