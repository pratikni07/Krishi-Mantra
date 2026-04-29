/**
 * Session Service
 * Manages user sessions and calculates session-level analytics
 */

const Session = require('../models/session.model');
const UserMetrics = require('../models/userMetrics.model');
const Redis = require('../config/redis');
const logger = require('../utils/logger');
const { CACHE_TTL } = require('../utils/constants');
const { generateSessionId, getTodayString } = require('../utils/helpers');

class SessionService {
  /**
   * Start a new session
   */
  static async startSession(userId, deviceInfo = {}) {
    try {
      const sessionId = generateSessionId(userId);

      const session = await Session.create({
        sessionId,
        userId,
        startTime: new Date(),
        device: {
          deviceId: deviceInfo.deviceId,
          platform: deviceInfo.platform || 'unknown',
          osVersion: deviceInfo.osVersion,
          appVersion: deviceInfo.appVersion,
          deviceModel: deviceInfo.deviceModel,
          screenResolution: deviceInfo.screenResolution,
        },
        location: deviceInfo.location || {},
        isActive: true,
      });

      // Cache active session
      await Redis.set(
        `session:active:${userId}`,
        JSON.stringify({ sessionId, startTime: session.startTime }),
        CACHE_TTL.SESSION_DATA
      );

      // Update user's session count in Redis
      const today = getTodayString();
      await Redis.increment(`user:sessions:${today}:${userId}`, 1, 86400);

      logger.info(`Session started: ${sessionId} for user ${userId}`);

      return {
        sessionId,
        startTime: session.startTime,
      };
    } catch (error) {
      logger.error('Error starting session:', error.message);
      throw error;
    }
  }

  /**
   * End a session
   */
  static async endSession(sessionId, endData = {}) {
    try {
      const session = await Session.findOne({ sessionId });

      if (!session) {
        logger.warn(`Session not found: ${sessionId}`);
        return null;
      }

      const endTime = new Date();
      const duration = Math.round((endTime - session.startTime) / 1000);

      // Calculate session engagement metrics
      const engagement = this._calculateSessionEngagement(session, duration);

      // Update session
      session.endTime = endTime;
      session.duration = duration;
      session.isActive = false;
      session.exitScreen = endData.exitScreen || session.screenFlow?.[session.screenFlow.length - 1]?.screenName;
      session.engagement = engagement;

      // Check if bounce (less than 10 seconds or only 1 screen view)
      session.isBounce = duration < 10 || (session.eventCounts?.screenViews || 0) <= 1;

      await session.save();

      // Clear active session cache
      await Redis.del(`session:active:${session.userId}`);

      // Update user metrics
      await this._updateUserMetricsOnSessionEnd(session);

      logger.info(`Session ended: ${sessionId}, duration: ${duration}s`);

      return {
        sessionId,
        duration,
        engagement,
        isBounce: session.isBounce,
      };
    } catch (error) {
      logger.error('Error ending session:', error.message);
      throw error;
    }
  }

  /**
   * Get active session for user
   */
  static async getActiveSession(userId) {
    try {
      // Check cache first
      const cached = await Redis.get(`session:active:${userId}`);
      if (cached) {
        return JSON.parse(cached);
      }

      // Check database
      const session = await Session.findOne({
        userId,
        isActive: true,
      }).lean();

      if (session) {
        await Redis.set(
          `session:active:${userId}`,
          JSON.stringify({ sessionId: session.sessionId, startTime: session.startTime }),
          CACHE_TTL.SESSION_DATA
        );
        return { sessionId: session.sessionId, startTime: session.startTime };
      }

      return null;
    } catch (error) {
      logger.error('Error getting active session:', error.message);
      return null;
    }
  }

  /**
   * Track screen view in session
   */
  static async trackScreenView(sessionId, screenName, previousScreen = null) {
    try {
      const now = new Date();

      // Update previous screen's exit time if exists
      const updateOps = {
        $push: {
          screenFlow: {
            screenName,
            enteredAt: now,
            previousScreen,
          },
        },
        $inc: {
          'eventCounts.screenViews': 1,
        },
        $set: {
          lastEventAt: now,
        },
      };

      // If there was a previous screen in this session, update its exit time
      if (previousScreen) {
        await Session.updateOne(
          {
            sessionId,
            'screenFlow.screenName': previousScreen,
            'screenFlow.exitedAt': { $exists: false },
          },
          {
            $set: {
              'screenFlow.$.exitedAt': now,
            },
          }
        );
      }

      await Session.updateOne({ sessionId }, updateOps);

      return { success: true };
    } catch (error) {
      logger.error('Error tracking screen view:', error.message);
      return { success: false, error: error.message };
    }
  }

  /**
   * Touch a session to keep it alive — bumps `lastActivity` and optionally
   * records the user's current screen. Used by the heartbeat endpoint.
   * Does NOT write an event row. Cheap per-session UPDATE only.
   */
  static async touchSession(sessionId, { currentScreen } = {}) {
    try {
      const update = { lastActivity: new Date() };
      if (currentScreen) update.currentScreen = currentScreen;
      await Session.updateOne(
        { sessionId, isActive: true },
        { $set: update }
      );
      return true;
    } catch (error) {
      logger.error('Error touching session:', error.message);
      return false;
    }
  }

  /**
   * Get session details
   */
  static async getSession(sessionId) {
    try {
      const cacheKey = `session:details:${sessionId}`;
      const cached = await Redis.get(cacheKey);

      if (cached) {
        return JSON.parse(cached);
      }

      const session = await Session.findOne({ sessionId }).lean();

      if (session && !session.isActive) {
        await Redis.set(cacheKey, JSON.stringify(session), CACHE_TTL.SESSION_DATA);
      }

      return session;
    } catch (error) {
      logger.error('Error getting session:', error.message);
      return null;
    }
  }

  /**
   * Get user's recent sessions
   */
  static async getUserSessions(userId, limit = 10) {
    try {
      const sessions = await Session.find({ userId })
        .sort({ startTime: -1 })
        .limit(limit)
        .lean();

      return sessions;
    } catch (error) {
      logger.error('Error getting user sessions:', error.message);
      return [];
    }
  }

  /**
   * Get session analytics for a time period
   */
  static async getSessionAnalytics(startDate, endDate) {
    try {
      const cacheKey = `analytics:sessions:${startDate}:${endDate}`;
      const cached = await Redis.get(cacheKey);

      if (cached) {
        return JSON.parse(cached);
      }

      const analytics = await Session.aggregate([
        {
          $match: {
            startTime: { $gte: new Date(startDate), $lte: new Date(endDate) },
            isActive: false,
          },
        },
        {
          $group: {
            _id: null,
            totalSessions: { $sum: 1 },
            uniqueUsers: { $addToSet: '$userId' },
            totalDuration: { $sum: '$duration' },
            avgDuration: { $avg: '$duration' },
            bounces: { $sum: { $cond: ['$isBounce', 1, 0] } },
            avgScreenViews: { $avg: '$eventCounts.screenViews' },
            avgEvents: { $avg: '$eventCounts.total' },
          },
        },
        {
          $project: {
            _id: 0,
            totalSessions: 1,
            uniqueUsers: { $size: '$uniqueUsers' },
            totalDuration: 1,
            avgDuration: { $round: ['$avgDuration', 0] },
            bounceRate: {
              $round: [{ $multiply: [{ $divide: ['$bounces', '$totalSessions'] }, 100] }, 1],
            },
            avgScreenViews: { $round: ['$avgScreenViews', 1] },
            avgEvents: { $round: ['$avgEvents', 1] },
          },
        },
      ]);

      const result = analytics[0] || {
        totalSessions: 0,
        uniqueUsers: 0,
        totalDuration: 0,
        avgDuration: 0,
        bounceRate: 0,
        avgScreenViews: 0,
        avgEvents: 0,
      };

      await Redis.set(cacheKey, JSON.stringify(result), CACHE_TTL.DASHBOARD_SUMMARY);

      return result;
    } catch (error) {
      logger.error('Error getting session analytics:', error.message);
      return null;
    }
  }

  /**
   * Get top screens by visits
   */
  static async getTopScreens(startDate, endDate, limit = 10) {
    try {
      const topScreens = await Session.aggregate([
        {
          $match: {
            startTime: { $gte: new Date(startDate), $lte: new Date(endDate) },
          },
        },
        { $unwind: '$screenFlow' },
        {
          $group: {
            _id: '$screenFlow.screenName',
            visits: { $sum: 1 },
            uniqueUsers: { $addToSet: '$userId' },
            totalTime: {
              $sum: {
                $cond: [
                  { $and: ['$screenFlow.enteredAt', '$screenFlow.exitedAt'] },
                  {
                    $divide: [{ $subtract: ['$screenFlow.exitedAt', '$screenFlow.enteredAt'] }, 1000],
                  },
                  0,
                ],
              },
            },
          },
        },
        {
          $project: {
            screenName: '$_id',
            visits: 1,
            uniqueUsers: { $size: '$uniqueUsers' },
            avgTime: {
              $round: [{ $cond: [{ $gt: ['$visits', 0] }, { $divide: ['$totalTime', '$visits'] }, 0] }, 0],
            },
          },
        },
        { $sort: { visits: -1 } },
        { $limit: limit },
      ]);

      return topScreens;
    } catch (error) {
      logger.error('Error getting top screens:', error.message);
      return [];
    }
  }

  /**
   * Calculate session engagement metrics
   */
  static _calculateSessionEngagement(session, duration) {
    const eventCounts = session.eventCounts || {};

    const totalInteractions =
      (eventCounts.feedLikes || 0) +
      (eventCounts.feedComments || 0) +
      (eventCounts.reelLikes || 0) +
      (eventCounts.reelComments || 0) +
      (eventCounts.chatMessagesSent || 0);

    const totalViews =
      (eventCounts.feedViews || 0) + (eventCounts.reelViews || 0) + (eventCounts.productViews || 0);

    const interactionRate = totalViews > 0 ? (totalInteractions / totalViews) * 100 : 0;

    return {
      totalScreenTime: duration,
      totalInteractions,
      totalViews,
      interactionRate: Math.round(interactionRate * 10) / 10,
      screensVisited: session.screenFlow?.length || 0,
    };
  }

  /**
   * Update user metrics when session ends
   */
  static async _updateUserMetricsOnSessionEnd(session) {
    try {
      const userId = session.userId;
      const today = getTodayString();

      // Get or create user metrics
      let userMetrics = await UserMetrics.findOne({ userId });

      if (!userMetrics) {
        userMetrics = new UserMetrics({ userId });
      }

      // Update session counts
      userMetrics.sessions.total += 1;
      userMetrics.sessions.totalDuration += session.duration || 0;
      userMetrics.sessions.avgDuration = Math.round(
        userMetrics.sessions.totalDuration / userMetrics.sessions.total
      );

      // Update last session info
      userMetrics.sessions.lastSessionAt = session.endTime;
      userMetrics.sessions.lastSessionDuration = session.duration || 0;

      // Update activity
      userMetrics.activity.lastActivity = session.endTime;
      userMetrics.activity.totalEvents += session.eventCounts?.total || 0;

      // Update streak
      const lastActive = userMetrics.activity.lastActivity;
      if (lastActive) {
        const lastActiveDate = lastActive.toISOString().split('T')[0];
        const yesterday = new Date();
        yesterday.setDate(yesterday.getDate() - 1);
        const yesterdayStr = yesterday.toISOString().split('T')[0];

        if (lastActiveDate === yesterdayStr || lastActiveDate === today) {
          userMetrics.activity.streakCurrent += 1;
          userMetrics.activity.streakLongest = Math.max(
            userMetrics.activity.streakLongest,
            userMetrics.activity.streakCurrent
          );
        } else if (lastActiveDate !== today) {
          userMetrics.activity.streakCurrent = 1;
        }
      } else {
        userMetrics.activity.streakCurrent = 1;
      }

      await userMetrics.save();
    } catch (error) {
      logger.error('Error updating user metrics on session end:', error.message);
    }
  }

  /**
   * Close stale sessions (sessions inactive for more than 30 minutes)
   */
  static async closeStaleSession() {
    try {
      const thirtyMinutesAgo = new Date(Date.now() - 30 * 60 * 1000);

      const staleSessions = await Session.find({
        isActive: true,
        lastEventAt: { $lt: thirtyMinutesAgo },
      });

      let closed = 0;
      for (const session of staleSessions) {
        await this.endSession(session.sessionId, {
          exitScreen: session.screenFlow?.[session.screenFlow.length - 1]?.screenName,
        });
        closed++;
      }

      if (closed > 0) {
        logger.info(`Closed ${closed} stale sessions`);
      }

      return closed;
    } catch (error) {
      logger.error('Error closing stale sessions:', error.message);
      return 0;
    }
  }
}

module.exports = SessionService;
