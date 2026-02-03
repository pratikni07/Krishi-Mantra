/**
 * Aggregation Worker
 * Runs periodic jobs to aggregate metrics and update user scores
 * Designed for 100k+ users with batch processing
 */

const cron = require('node-cron');
const Event = require('../models/event.model');
const Session = require('../models/session.model');
const UserMetrics = require('../models/userMetrics.model');
const DailyMetrics = require('../models/dailyMetrics.model');
const SessionService = require('../services/sessionService');
const Redis = require('../config/redis');
const logger = require('../utils/logger');
const {
  getTodayString,
  getDateStringDaysAgo,
  calculateEngagementScore,
  calculateChurnRisk,
  batchArray,
} = require('../utils/helpers');

const BATCH_SIZE = 500; // Process users in batches

class AggregationWorker {
  static isRunning = false;
  static jobs = [];

  /**
   * Initialize and start all cron jobs
   */
  static init() {
    // Close stale sessions - every 5 minutes
    this.jobs.push(
      cron.schedule('*/5 * * * *', async () => {
        await this.closeStaleSession();
      })
    );

    // Update daily metrics - every 15 minutes
    this.jobs.push(
      cron.schedule('*/15 * * * *', async () => {
        await this.updateDailyMetrics();
      })
    );

    // Update user engagement scores - every hour
    this.jobs.push(
      cron.schedule('0 * * * *', async () => {
        await this.updateUserEngagementScores();
      })
    );

    // Calculate churn risk - every 6 hours
    this.jobs.push(
      cron.schedule('0 */6 * * *', async () => {
        await this.calculateChurnRiskForUsers();
      })
    );

    // End of day aggregation - at midnight
    this.jobs.push(
      cron.schedule('0 0 * * *', async () => {
        await this.runEndOfDayAggregation();
      })
    );

    // Weekly retention calculation - Sunday at 1 AM
    this.jobs.push(
      cron.schedule('0 1 * * 0', async () => {
        await this.calculateWeeklyRetention();
      })
    );

    logger.info('Aggregation worker initialized with cron jobs');
  }

  /**
   * Stop all cron jobs
   */
  static stop() {
    for (const job of this.jobs) {
      job.stop();
    }
    this.jobs = [];
    logger.info('Aggregation worker stopped');
  }

  /**
   * Close stale sessions
   */
  static async closeStaleSession() {
    if (this.isRunning) return;
    this.isRunning = true;

    try {
      const startTime = Date.now();
      const closed = await SessionService.closeStaleSession();
      logger.performance('Close stale sessions', startTime, { closed });
    } catch (error) {
      logger.error('Error closing stale sessions:', error.message);
    } finally {
      this.isRunning = false;
    }
  }

  /**
   * Update daily metrics from events
   */
  static async updateDailyMetrics() {
    try {
      const startTime = Date.now();
      const today = getTodayString();
      const client = Redis.getClient();

      // Get daily metrics document
      const metrics = await DailyMetrics.getOrCreate(today);

      // Get DAU from Redis
      if (client) {
        const activeUsers = await client.scard(`users:active:${today}`);
        metrics.users.dau = activeUsers || 0;
      }

      // Aggregate session data for today
      const todayStart = new Date(today);
      const todayEnd = new Date(today);
      todayEnd.setUTCHours(23, 59, 59, 999);

      const sessionStats = await Session.aggregate([
        {
          $match: {
            startTime: { $gte: todayStart, $lte: todayEnd },
            isActive: false,
          },
        },
        {
          $group: {
            _id: null,
            total: { $sum: 1 },
            totalDuration: { $sum: '$duration' },
            avgDuration: { $avg: '$duration' },
            bounces: { $sum: { $cond: ['$isBounce', 1, 0] } },
            avgEvents: { $avg: '$eventCounts.total' },
          },
        },
      ]);

      if (sessionStats.length > 0) {
        const stats = sessionStats[0];
        metrics.sessions.total = stats.total;
        metrics.sessions.totalDuration = stats.totalDuration;
        metrics.sessions.avgDuration = Math.round(stats.avgDuration);
        metrics.sessions.bounceRate = stats.total > 0 ? Math.round((stats.bounces / stats.total) * 100) : 0;
        metrics.sessions.avgEventsPerSession = Math.round(stats.avgEvents);
      }

      // Get event counts by category from Redis
      if (client) {
        const categories = ['navigation', 'engagement', 'content', 'social', 'commerce', 'communication', 'ai', 'system'];
        for (const category of categories) {
          const count = await Redis.get(`events:category:${today}:${category}`);
          if (count && metrics.events.byCategory[category] !== undefined) {
            metrics.events.byCategory[category] = parseInt(count);
          }
        }
      }

      // Get top screens
      const topScreens = await Session.aggregate([
        {
          $match: {
            startTime: { $gte: todayStart, $lte: todayEnd },
          },
        },
        { $unwind: '$screenFlow' },
        {
          $group: {
            _id: '$screenFlow.screenName',
            visits: { $sum: 1 },
            uniqueUsers: { $addToSet: '$userId' },
          },
        },
        {
          $project: {
            screenName: '$_id',
            visits: 1,
            uniqueUsers: { $size: '$uniqueUsers' },
          },
        },
        { $sort: { visits: -1 } },
        { $limit: 10 },
      ]);

      metrics.screens.topScreens = topScreens;

      // Save metrics
      metrics.processed = true;
      metrics.processedAt = new Date();
      await metrics.save();

      logger.performance('Update daily metrics', startTime);
    } catch (error) {
      logger.error('Error updating daily metrics:', error.message);
    }
  }

  /**
   * Update user engagement scores in batches
   */
  static async updateUserEngagementScores() {
    try {
      const startTime = Date.now();
      const last7Days = getDateStringDaysAgo(7);

      // Get all users with recent activity
      const userIds = await Event.distinct('userId', {
        timestamp: { $gte: new Date(last7Days) },
      });

      logger.info(`Updating engagement scores for ${userIds.length} users`);

      // Process in batches
      const batches = batchArray(userIds, BATCH_SIZE);
      let processed = 0;

      for (const batch of batches) {
        // Get activity summary for each user in batch
        const activities = await Event.aggregate([
          {
            $match: {
              userId: { $in: batch },
              timestamp: { $gte: new Date(last7Days) },
            },
          },
          {
            $group: {
              _id: '$userId',
              feedViews: { $sum: { $cond: [{ $eq: ['$eventName', 'feed_view'] }, 1, 0] } },
              feedLikes: { $sum: { $cond: [{ $eq: ['$eventName', 'feed_like'] }, 1, 0] } },
              feedComments: { $sum: { $cond: [{ $eq: ['$eventName', 'feed_comment'] }, 1, 0] } },
              reelViews: { $sum: { $cond: [{ $eq: ['$eventName', 'reel_view'] }, 1, 0] } },
              reelLikes: { $sum: { $cond: [{ $eq: ['$eventName', 'reel_like'] }, 1, 0] } },
              productViews: { $sum: { $cond: [{ $eq: ['$eventName', 'product_view'] }, 1, 0] } },
              chatMessages: { $sum: { $cond: [{ $eq: ['$eventName', 'chat_message_sent'] }, 1, 0] } },
              aiChats: { $sum: { $cond: [{ $eq: ['$eventName', 'ai_chat_message'] }, 1, 0] } },
              screenViews: { $sum: { $cond: [{ $eq: ['$eventName', 'screen_view'] }, 1, 0] } },
              totalEvents: { $sum: 1 },
            },
          },
        ]);

        // Update user metrics
        const bulkOps = activities.map((activity) => {
          const score = calculateEngagementScore(activity);
          const level =
            score >= 80
              ? 'power_user'
              : score >= 50
              ? 'high'
              : score >= 20
              ? 'medium'
              : score >= 5
              ? 'low'
              : 'inactive';

          return {
            updateOne: {
              filter: { userId: activity._id },
              update: {
                $set: {
                  'engagementScore.current': score,
                  'engagementScore.last7Days': score,
                  'engagementScore.calculatedAt': new Date(),
                  'segments.engagementLevel': level,
                  'engagement.feeds.viewed': activity.feedViews,
                  'engagement.feeds.liked': activity.feedLikes,
                  'engagement.feeds.commented': activity.feedComments,
                  'engagement.reels.viewed': activity.reelViews,
                  'engagement.reels.liked': activity.reelLikes,
                  'engagement.products.viewed': activity.productViews,
                  'engagement.chat.messagesSent': activity.chatMessages,
                  'engagement.ai.sessionsStarted': activity.aiChats,
                },
              },
              upsert: true,
            },
          };
        });

        if (bulkOps.length > 0) {
          await UserMetrics.bulkWrite(bulkOps, { ordered: false });
        }

        processed += batch.length;
      }

      logger.performance('Update engagement scores', startTime, { processed });
    } catch (error) {
      logger.error('Error updating engagement scores:', error.message);
    }
  }

  /**
   * Calculate churn risk for users
   */
  static async calculateChurnRiskForUsers() {
    try {
      const startTime = Date.now();

      // Get users with activity in the last 60 days
      const cutoffDate = getDateStringDaysAgo(60);

      const users = await UserMetrics.find({
        'activity.lastActivity': { $gte: new Date(cutoffDate) },
      }).select('userId sessions activity engagementScore');

      logger.info(`Calculating churn risk for ${users.length} users`);

      const batches = batchArray(users, BATCH_SIZE);
      let processed = 0;

      for (const batch of batches) {
        const bulkOps = batch.map((user) => {
          const churnRisk = calculateChurnRisk(user);

          return {
            updateOne: {
              filter: { userId: user.userId },
              update: {
                $set: {
                  'churnRisk.score': churnRisk.score,
                  'churnRisk.level': churnRisk.level,
                  'churnRisk.factors': churnRisk.factors,
                  'churnRisk.calculatedAt': churnRisk.calculatedAt,
                },
              },
            },
          };
        });

        if (bulkOps.length > 0) {
          await UserMetrics.bulkWrite(bulkOps, { ordered: false });
        }

        processed += batch.length;
      }

      logger.performance('Calculate churn risk', startTime, { processed });
    } catch (error) {
      logger.error('Error calculating churn risk:', error.message);
    }
  }

  /**
   * Run end of day aggregation
   */
  static async runEndOfDayAggregation() {
    try {
      const startTime = Date.now();
      const yesterday = getDateStringDaysAgo(1);

      logger.info(`Running end of day aggregation for ${yesterday}`);

      // Update final daily metrics
      await this.updateDailyMetrics();

      // Update engagement scores
      await this.updateUserEngagementScores();

      // Update 7-day and 30-day session counts
      const users = await UserMetrics.find({}).select('userId');

      const batches = batchArray(users, BATCH_SIZE);

      for (const batch of batches) {
        const userIds = batch.map((u) => u.userId);
        const sevenDaysAgo = new Date(getDateStringDaysAgo(7));
        const thirtyDaysAgo = new Date(getDateStringDaysAgo(30));

        // Get session counts
        const sessionCounts = await Session.aggregate([
          {
            $match: {
              userId: { $in: userIds },
              startTime: { $gte: thirtyDaysAgo },
            },
          },
          {
            $group: {
              _id: '$userId',
              last7Days: {
                $sum: { $cond: [{ $gte: ['$startTime', sevenDaysAgo] }, 1, 0] },
              },
              last30Days: { $sum: 1 },
            },
          },
        ]);

        const bulkOps = sessionCounts.map((count) => ({
          updateOne: {
            filter: { userId: count._id },
            update: {
              $set: {
                'sessions.last7Days': count.last7Days,
                'sessions.last30Days': count.last30Days,
              },
            },
          },
        }));

        if (bulkOps.length > 0) {
          await UserMetrics.bulkWrite(bulkOps, { ordered: false });
        }
      }

      logger.performance('End of day aggregation', startTime);
    } catch (error) {
      logger.error('Error in end of day aggregation:', error.message);
    }
  }

  /**
   * Calculate weekly retention
   */
  static async calculateWeeklyRetention() {
    try {
      const startTime = Date.now();

      // Calculate retention for cohorts from the last 4 weeks
      for (let week = 1; week <= 4; week++) {
        const cohortDate = getDateStringDaysAgo(week * 7);

        const cohortStart = new Date(cohortDate);
        cohortStart.setUTCHours(0, 0, 0, 0);
        const cohortEnd = new Date(cohortDate);
        cohortEnd.setDate(cohortEnd.getDate() + 6);
        cohortEnd.setUTCHours(23, 59, 59, 999);

        // Get users who had their first session in this week
        const cohortUsers = await UserMetrics.find({
          'activity.firstSeen': { $gte: cohortStart, $lte: cohortEnd },
        }).select('userId');

        const cohortUserIds = cohortUsers.map((u) => u.userId);
        const cohortSize = cohortUserIds.length;

        if (cohortSize === 0) continue;

        // Calculate how many returned in subsequent weeks
        const thisWeekStart = new Date(getDateStringDaysAgo(0));
        thisWeekStart.setUTCHours(0, 0, 0, 0);

        const returnedUsers = await Event.distinct('userId', {
          userId: { $in: cohortUserIds },
          timestamp: { $gte: thisWeekStart },
        });

        const retentionRate = Math.round((returnedUsers.length / cohortSize) * 100);

        logger.info(`Week -${week} cohort retention: ${retentionRate}% (${returnedUsers.length}/${cohortSize})`);
      }

      logger.performance('Weekly retention calculation', startTime);
    } catch (error) {
      logger.error('Error calculating weekly retention:', error.message);
    }
  }

  /**
   * Run manual aggregation (for admin/debugging)
   */
  static async runManualAggregation() {
    await this.closeStaleSession();
    await this.updateDailyMetrics();
    await this.updateUserEngagementScores();
    await this.calculateChurnRiskForUsers();
    return { success: true, message: 'Manual aggregation completed' };
  }
}

module.exports = AggregationWorker;
