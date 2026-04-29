/**
 * Analytics Controller
 * Handles analytics and dashboard API endpoints
 */

const AnalyticsService = require('../services/analyticsService');
const SessionService = require('../services/sessionService');
const Event = require('../models/event.model');
const UserMetrics = require('../models/userMetrics.model');
const logger = require('../utils/logger');
const { HTTP_STATUS, ERROR_CODES } = require('../utils/constants');
const { timeframeToDays } = require('../utils/timeframeHelper');

const CONSULTANT_EVENTS = [
  'consultant_directory_view',
  'consultant_profile_view',
  'consultant_chat_request',
  'consultant_chat_accepted',
  'consultant_chat_completed',
  'consultant_rating_submitted',
];

class AnalyticsController {
  /**
   * Get dashboard summary
   * GET /api/engagement/analytics/dashboard
   */
  static async getDashboardSummary(req, res) {
    try {
      const { days = 30 } = req.query;
      const daysNum = Math.min(parseInt(days), 365); // Max 1 year

      const summary = await AnalyticsService.getDashboardSummary(daysNum);

      return res.status(HTTP_STATUS.OK).json({
        success: true,
        data: summary,
      });
    } catch (error) {
      logger.error('Error in getDashboardSummary:', error.message);
      return res.status(HTTP_STATUS.INTERNAL_ERROR).json({
        success: false,
        error: ERROR_CODES.INTERNAL_ERROR,
        message: 'Failed to get dashboard summary',
      });
    }
  }

  /**
   * Get real-time statistics
   * GET /api/engagement/analytics/realtime
   */
  static async getRealTimeStats(req, res) {
    try {
      const stats = await AnalyticsService.getRealTimeStats();

      return res.status(HTTP_STATUS.OK).json({
        success: true,
        data: stats,
      });
    } catch (error) {
      logger.error('Error in getRealTimeStats:', error.message);
      return res.status(HTTP_STATUS.INTERNAL_ERROR).json({
        success: false,
        error: ERROR_CODES.INTERNAL_ERROR,
        message: 'Failed to get real-time stats',
      });
    }
  }

  /**
   * Get engagement breakdown
   * GET /api/engagement/analytics/engagement
   */
  static async getEngagementBreakdown(req, res) {
    try {
      const { days = 30 } = req.query;
      const daysNum = Math.min(parseInt(days), 365);

      const breakdown = await AnalyticsService.getEngagementBreakdown(daysNum);

      return res.status(HTTP_STATUS.OK).json({
        success: true,
        data: breakdown,
      });
    } catch (error) {
      logger.error('Error in getEngagementBreakdown:', error.message);
      return res.status(HTTP_STATUS.INTERNAL_ERROR).json({
        success: false,
        error: ERROR_CODES.INTERNAL_ERROR,
        message: 'Failed to get engagement breakdown',
      });
    }
  }

  /**
   * Get feature usage analytics
   * GET /api/engagement/analytics/features
   */
  static async getFeatureUsage(req, res) {
    try {
      const { days = 30 } = req.query;
      const daysNum = Math.min(parseInt(days), 365);

      const usage = await AnalyticsService.getFeatureUsage(daysNum);

      return res.status(HTTP_STATUS.OK).json({
        success: true,
        data: usage,
      });
    } catch (error) {
      logger.error('Error in getFeatureUsage:', error.message);
      return res.status(HTTP_STATUS.INTERNAL_ERROR).json({
        success: false,
        error: ERROR_CODES.INTERNAL_ERROR,
        message: 'Failed to get feature usage',
      });
    }
  }

  /**
   * Get session analytics
   * GET /api/engagement/analytics/sessions
   */
  static async getSessionAnalytics(req, res) {
    try {
      const { startDate, endDate } = req.query;

      if (!startDate || !endDate) {
        return res.status(HTTP_STATUS.BAD_REQUEST).json({
          success: false,
          error: ERROR_CODES.VALIDATION_ERROR,
          message: 'startDate and endDate are required',
        });
      }

      const analytics = await SessionService.getSessionAnalytics(startDate, endDate);

      return res.status(HTTP_STATUS.OK).json({
        success: true,
        data: analytics,
      });
    } catch (error) {
      logger.error('Error in getSessionAnalytics:', error.message);
      return res.status(HTTP_STATUS.INTERNAL_ERROR).json({
        success: false,
        error: ERROR_CODES.INTERNAL_ERROR,
        message: 'Failed to get session analytics',
      });
    }
  }

  /**
   * Get top screens
   * GET /api/engagement/analytics/screens
   */
  static async getTopScreens(req, res) {
    try {
      const { startDate, endDate, limit = 10 } = req.query;

      if (!startDate || !endDate) {
        return res.status(HTTP_STATUS.BAD_REQUEST).json({
          success: false,
          error: ERROR_CODES.VALIDATION_ERROR,
          message: 'startDate and endDate are required',
        });
      }

      const screens = await SessionService.getTopScreens(
        startDate,
        endDate,
        Math.min(parseInt(limit), 50)
      );

      return res.status(HTTP_STATUS.OK).json({
        success: true,
        data: screens,
      });
    } catch (error) {
      logger.error('Error in getTopScreens:', error.message);
      return res.status(HTTP_STATUS.INTERNAL_ERROR).json({
        success: false,
        error: ERROR_CODES.INTERNAL_ERROR,
        message: 'Failed to get top screens',
      });
    }
  }

  /**
   * Get retention metrics
   * GET /api/engagement/analytics/retention
   */
  static async getRetentionMetrics(req, res) {
    try {
      const { cohortDate } = req.query;

      if (!cohortDate) {
        return res.status(HTTP_STATUS.BAD_REQUEST).json({
          success: false,
          error: ERROR_CODES.VALIDATION_ERROR,
          message: 'cohortDate is required (YYYY-MM-DD)',
        });
      }

      const metrics = await AnalyticsService.getRetentionMetrics(cohortDate);

      return res.status(HTTP_STATUS.OK).json({
        success: true,
        data: metrics,
      });
    } catch (error) {
      logger.error('Error in getRetentionMetrics:', error.message);
      return res.status(HTTP_STATUS.INTERNAL_ERROR).json({
        success: false,
        error: ERROR_CODES.INTERNAL_ERROR,
        message: 'Failed to get retention metrics',
      });
    }
  }

  /**
   * Get churn risk analysis
   * GET /api/engagement/analytics/churn
   */
  static async getChurnRiskAnalysis(req, res) {
    try {
      const analysis = await AnalyticsService.getChurnRiskAnalysis();

      return res.status(HTTP_STATUS.OK).json({
        success: true,
        data: analysis,
      });
    } catch (error) {
      logger.error('Error in getChurnRiskAnalysis:', error.message);
      return res.status(HTTP_STATUS.INTERNAL_ERROR).json({
        success: false,
        error: ERROR_CODES.INTERNAL_ERROR,
        message: 'Failed to get churn risk analysis',
      });
    }
  }

  /**
   * Get top content by engagement
   * GET /api/engagement/analytics/content
   */
  static async getTopContent(req, res) {
    try {
      const { type = 'feed', days = 7, limit = 10 } = req.query;

      const content = await AnalyticsService.getTopContent(
        type,
        Math.min(parseInt(days), 90),
        Math.min(parseInt(limit), 50)
      );

      return res.status(HTTP_STATUS.OK).json({
        success: true,
        data: content,
      });
    } catch (error) {
      logger.error('Error in getTopContent:', error.message);
      return res.status(HTTP_STATUS.INTERNAL_ERROR).json({
        success: false,
        error: ERROR_CODES.INTERNAL_ERROR,
        message: 'Failed to get top content',
      });
    }
  }

  /**
   * Get hourly activity pattern
   * GET /api/engagement/analytics/hourly
   */
  static async getHourlyPattern(req, res) {
    try {
      const { days = 7 } = req.query;
      const daysNum = Math.min(parseInt(days), 30);

      const pattern = await AnalyticsService.getHourlyActivityPattern(daysNum);

      return res.status(HTTP_STATUS.OK).json({
        success: true,
        data: pattern,
      });
    } catch (error) {
      logger.error('Error in getHourlyPattern:', error.message);
      return res.status(HTTP_STATUS.INTERNAL_ERROR).json({
        success: false,
        error: ERROR_CODES.INTERNAL_ERROR,
        message: 'Failed to get hourly pattern',
      });
    }
  }

  /**
   * Get user analytics
   * GET /api/engagement/analytics/users/:userId
   */
  static async getUserAnalytics(req, res) {
    try {
      const { userId } = req.params;

      if (!userId) {
        return res.status(HTTP_STATUS.BAD_REQUEST).json({
          success: false,
          error: ERROR_CODES.VALIDATION_ERROR,
          message: 'userId is required',
        });
      }

      const analytics = await AnalyticsService.getUserAnalytics(userId);

      if (!analytics) {
        return res.status(HTTP_STATUS.NOT_FOUND).json({
          success: false,
          error: ERROR_CODES.USER_NOT_FOUND,
          message: 'User analytics not found',
        });
      }

      return res.status(HTTP_STATUS.OK).json({
        success: true,
        data: analytics,
      });
    } catch (error) {
      logger.error('Error in getUserAnalytics:', error.message);
      return res.status(HTTP_STATUS.INTERNAL_ERROR).json({
        success: false,
        error: ERROR_CODES.INTERNAL_ERROR,
        message: 'Failed to get user analytics',
      });
    }
  }

  /**
   * Get period comparison
   * GET /api/engagement/analytics/comparison
   */
  static async getPeriodComparison(req, res) {
    try {
      const { period = 'week' } = req.query;

      if (!['day', 'week', 'month'].includes(period)) {
        return res.status(HTTP_STATUS.BAD_REQUEST).json({
          success: false,
          error: ERROR_CODES.VALIDATION_ERROR,
          message: 'period must be day, week, or month',
        });
      }

      const comparison = await AnalyticsService.getPeriodComparison(period);

      return res.status(HTTP_STATUS.OK).json({
        success: true,
        data: comparison,
      });
    } catch (error) {
      logger.error('Error in getPeriodComparison:', error.message);
      return res.status(HTTP_STATUS.INTERNAL_ERROR).json({
        success: false,
        error: ERROR_CODES.INTERNAL_ERROR,
        message: 'Failed to get period comparison',
      });
    }
  }

  /**
   * Get leaderboard (top engaged users)
   * GET /api/engagement/analytics/leaderboard
   */
  static async getLeaderboard(req, res) {
    try {
      const { limit = 10 } = req.query;
      const limitNum = Math.min(parseInt(limit), 100);

      const leaderboard = await UserMetrics.find({
        'engagementScore.current': { $gt: 0 },
      })
        .sort({ 'engagementScore.current': -1 })
        .limit(limitNum)
        .select('userId engagementScore sessions.total activity.lastActivity segments')
        .lean();

      return res.status(HTTP_STATUS.OK).json({
        success: true,
        data: leaderboard.map((user, index) => ({
          rank: index + 1,
          userId: user.userId,
          score: user.engagementScore?.current || 0,
          totalSessions: user.sessions?.total || 0,
          lastActive: user.activity?.lastActivity,
          engagementLevel: user.segments?.engagementLevel,
        })),
      });
    } catch (error) {
      logger.error('Error in getLeaderboard:', error.message);
      return res.status(HTTP_STATUS.INTERNAL_ERROR).json({
        success: false,
        error: ERROR_CODES.INTERNAL_ERROR,
        message: 'Failed to get leaderboard',
      });
    }
  }

  /**
   * Get user analytics
   * GET /api/engagement/analytics/users/:userId
   */
  static async getUserAnalytics(req, res) {
    try {
      const { userId } = req.params;
      const { days = 30 } = req.query;

      const metrics = await UserMetrics.findOne({ userId }).lean();

      if (!metrics) {
        return res.status(HTTP_STATUS.NOT_FOUND).json({
          success: false,
          error: ERROR_CODES.NOT_FOUND,
          message: 'User metrics not found',
        });
      }

      return res.status(HTTP_STATUS.OK).json({
        success: true,
        data: metrics,
      });
    } catch (error) {
      logger.error('Error in getUserAnalytics:', error.message);
      return res.status(HTTP_STATUS.INTERNAL_ERROR).json({
        success: false,
        error: ERROR_CODES.INTERNAL_ERROR,
        message: 'Failed to get user analytics',
      });
    }
  }

  /**
   * Get flexible dashboard data with timeframe support
   * GET /api/engagement/analytics/dashboard?timeframe=week
   */
  static async getDashboard(req, res) {
    try {
      const { timeframe = 'week', startDate, endDate } = req.query;
      
      // Calculate date range based on timeframe
      const days = timeframeToDays(timeframe);

      // Get dashboard summary
      const summary = await AnalyticsService.getDashboardSummary(days);
      
      // Get session analytics for the period
      const now = new Date();
      const start = startDate || new Date(now.getTime() - days * 24 * 60 * 60 * 1000).toISOString();
      const end = endDate || now.toISOString();
      
      const sessionAnalytics = await SessionService.getSessionAnalytics(start, end);

      // Combine data
      const dashboardData = {
        ...summary,
        ...sessionAnalytics,
        period: {
          timeframe,
          days,
          startDate: start,
          endDate: end,
        },
      };

      return res.status(HTTP_STATUS.OK).json({
        success: true,
        data: dashboardData,
      });
    } catch (error) {
      logger.error('Error in getDashboard:', error.message);
      return res.status(HTTP_STATUS.INTERNAL_ERROR).json({
        success: false,
        error: ERROR_CODES.INTERNAL_ERROR,
        message: 'Failed to get dashboard data',
      });
    }
  }

  /**
   * Get hourly pattern with flexible timeframe
   * GET /api/engagement/analytics/hourly?timeframe=week
   */
  static async getHourlyPattern(req, res) {
    try {
      const { timeframe = 'week', startDate, endDate } = req.query;
      
      // Calculate date range based on timeframe
      const days = timeframeToDays(timeframe);

      const now = new Date();
      const start = startDate || new Date(now.getTime() - days * 24 * 60 * 60 * 1000);
      const end = endDate || now;

      // Aggregate events by hour
      const hourlyData = await Event.aggregate([
        {
          $match: {
            timestamp: {
              $gte: start,
              $lte: end,
            },
          },
        },
        {
          $group: {
            _id: { $hour: '$timestamp' },
            events: { $sum: 1 },
            sessions: { $addToSet: '$sessionId' },
          },
        },
        {
          $project: {
            hour: '$_id',
            events: 1,
            sessions: { $size: '$sessions' },
          },
        },
        {
          $sort: { hour: 1 },
        },
      ]);

      // Format the result
      const formatted = Array.from({ length: 24 }, (_, i) => {
        const hourData = hourlyData.find((d) => d.hour === i);
        return {
          hour: `${i}:00`,
          events: hourData?.events || 0,
          sessions: hourData?.sessions || 0,
        };
      });

      return res.status(HTTP_STATUS.OK).json({
        success: true,
        data: formatted,
      });
    } catch (error) {
      logger.error('Error in getHourlyPattern:', error.message);
      return res.status(HTTP_STATUS.INTERNAL_ERROR).json({
        success: false,
        error: ERROR_CODES.INTERNAL_ERROR,
        message: 'Failed to get hourly pattern',
      });
    }
  }

  /**
   * Consultant leaderboard.
   * GET /api/engagement/analytics/consultants/leaderboard
   *
   * Pure engagement metrics keyed by consultantId. The admin panel merges
   * this with consultant names/avatars/ratings from main-service — that
   * data lives outside engagement-service deliberately.
   *
   * Query params:
   *   from, to: ISO dates (default: last 30 days)
   *   limit: 1..100 (default 25)
   *   sortBy: 'requests' | 'profileViews' | 'acceptanceRate' | 'trend' (default 'requests')
   */
  static async getConsultantsLeaderboard(req, res) {
    try {
      const limit = Math.min(100, Math.max(1, parseInt(req.query.limit, 10) || 25));
      const sortBy = String(req.query.sortBy || 'requests');

      const now = new Date();
      const defaultFrom = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
      const to = req.query.to ? new Date(req.query.to) : now;
      const from = req.query.from ? new Date(req.query.from) : defaultFrom;

      if (Number.isNaN(from.getTime()) || Number.isNaN(to.getTime()) || from >= to) {
        return res.status(HTTP_STATUS.BAD_REQUEST).json({
          success: false,
          error: ERROR_CODES.VALIDATION_ERROR,
          message: 'Invalid from/to range',
        });
      }

      // Same-length prior window for trend calculation.
      const windowMs = to.getTime() - from.getTime();
      const priorTo = new Date(from.getTime());
      const priorFrom = new Date(from.getTime() - windowMs);

      const buildPipeline = (start, end) => [
        {
          $match: {
            eventName: { $in: CONSULTANT_EVENTS },
            timestamp: { $gte: start, $lt: end },
            'properties.contentId': { $exists: true, $nin: [null, ''] },
          },
        },
        {
          $group: {
            _id: '$properties.contentId',
            directoryViews: {
              $sum: { $cond: [{ $eq: ['$eventName', 'consultant_directory_view'] }, 1, 0] },
            },
            profileViews: {
              $sum: { $cond: [{ $eq: ['$eventName', 'consultant_profile_view'] }, 1, 0] },
            },
            chatRequests: {
              $sum: { $cond: [{ $eq: ['$eventName', 'consultant_chat_request'] }, 1, 0] },
            },
            chatsAccepted: {
              $sum: { $cond: [{ $eq: ['$eventName', 'consultant_chat_accepted'] }, 1, 0] },
            },
            chatsCompleted: {
              $sum: { $cond: [{ $eq: ['$eventName', 'consultant_chat_completed'] }, 1, 0] },
            },
            ratingsSubmitted: {
              $sum: { $cond: [{ $eq: ['$eventName', 'consultant_rating_submitted'] }, 1, 0] },
            },
            uniqueRequestingUsers: {
              $addToSet: {
                $cond: [
                  { $eq: ['$eventName', 'consultant_chat_request'] },
                  '$userId',
                  '$$REMOVE',
                ],
              },
            },
            sources: {
              $push: {
                $cond: [
                  { $eq: ['$eventName', 'consultant_chat_request'] },
                  { $ifNull: ['$properties.source', 'unknown'] },
                  '$$REMOVE',
                ],
              },
            },
          },
        },
      ];

      const [current, prior] = await Promise.all([
        Event.aggregate(buildPipeline(from, to)),
        Event.aggregate(buildPipeline(priorFrom, priorTo)),
      ]);

      const priorByConsultant = new Map();
      for (const row of prior) priorByConsultant.set(String(row._id), row);

      const formatted = current.map((row) => {
        const priorRow = priorByConsultant.get(String(row._id));
        const priorRequests = priorRow ? priorRow.chatRequests : 0;
        const trendRequests = priorRequests > 0
          ? (row.chatRequests - priorRequests) / priorRequests
          : (row.chatRequests > 0 ? null : 0);

        // top 3 request sources
        const sourceCounts = {};
        for (const s of row.sources || []) sourceCounts[s] = (sourceCounts[s] || 0) + 1;
        const topRequestSources = Object.entries(sourceCounts)
          .sort((a, b) => b[1] - a[1])
          .slice(0, 3)
          .map(([source, count]) => ({ source, count }));

        return {
          consultantId: row._id,
          directoryViews: row.directoryViews,
          profileViews: row.profileViews,
          chatRequests: row.chatRequests,
          chatsAccepted: row.chatsAccepted,
          chatsCompleted: row.chatsCompleted,
          ratingsSubmitted: row.ratingsSubmitted,
          uniqueUsersRequested: (row.uniqueRequestingUsers || []).length,
          acceptanceRate: row.chatRequests > 0
            ? Number((row.chatsAccepted / row.chatRequests).toFixed(2))
            : null,
          completionRate: row.chatsAccepted > 0
            ? Number((row.chatsCompleted / row.chatsAccepted).toFixed(2))
            : null,
          trendRequests: trendRequests == null
            ? null
            : Number(trendRequests.toFixed(2)),
          topRequestSources,
        };
      });

      const sortKey = {
        requests: 'chatRequests',
        profileViews: 'profileViews',
        acceptanceRate: 'acceptanceRate',
        trend: 'trendRequests',
      }[sortBy] || 'chatRequests';

      formatted.sort((a, b) => {
        const av = a[sortKey] ?? -Infinity;
        const bv = b[sortKey] ?? -Infinity;
        return bv - av;
      });

      return res.status(HTTP_STATUS.OK).json({
        success: true,
        data: {
          from: from.toISOString(),
          to: to.toISOString(),
          consultants: formatted.slice(0, limit),
        },
      });
    } catch (error) {
      logger.error('Error in getConsultantsLeaderboard:', error.message);
      return res.status(HTTP_STATUS.INTERNAL_ERROR).json({
        success: false,
        error: ERROR_CODES.INTERNAL_ERROR,
        message: 'Failed to get consultant leaderboard',
      });
    }
  }
}

module.exports = AnalyticsController;
