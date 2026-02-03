const mongoose = require('mongoose');

/**
 * Session Schema
 * Tracks user sessions - optimized for 100k+ users
 */
const sessionSchema = new mongoose.Schema(
  {
    // Session identification
    sessionId: {
      type: String,
      required: true,
      unique: true,
      index: true,
    },
    userId: {
      type: String,
      required: true,
      index: true,
    },

    // Session timing
    startTime: {
      type: Date,
      required: true,
      index: true,
    },
    endTime: Date,
    duration: {
      type: Number, // in seconds
      default: 0,
    },
    isActive: {
      type: Boolean,
      default: true,
      index: true,
    },

    // Device information
    device: {
      deviceId: String,
      platform: {
        type: String,
        enum: ['ios', 'android', 'web'],
      },
      osVersion: String,
      appVersion: String,
      model: String,
      manufacturer: String,
    },

    // Location
    location: {
      latitude: Number,
      longitude: Number,
      country: String,
      region: String,
      city: String,
    },

    // Event summary
    eventCounts: {
      total: { type: Number, default: 0 },
      screenViews: { type: Number, default: 0 },
      feedViews: { type: Number, default: 0 },
      feedLikes: { type: Number, default: 0 },
      feedComments: { type: Number, default: 0 },
      reelViews: { type: Number, default: 0 },
      reelLikes: { type: Number, default: 0 },
      messages: { type: Number, default: 0 },
      aiChats: { type: Number, default: 0 },
      searches: { type: Number, default: 0 },
      productViews: { type: Number, default: 0 },
    },

    // Screen flow tracking
    screenFlow: [
      {
        screenName: String,
        enteredAt: Date,
        exitedAt: Date,
        duration: Number,
      },
    ],

    // Engagement metrics
    engagement: {
      totalScreenTime: { type: Number, default: 0 }, // seconds
      averageScreenTime: { type: Number, default: 0 },
      bounceRate: { type: Number, default: 0 },
      interactionRate: { type: Number, default: 0 },
      contentConsumption: {
        feedsViewed: { type: Number, default: 0 },
        reelsWatched: { type: Number, default: 0 },
        productsViewed: { type: Number, default: 0 },
        totalWatchTime: { type: Number, default: 0 },
      },
    },

    // Session metadata
    referrer: String,
    entryScreen: String,
    exitScreen: String,
    networkType: String,

    // Processing flags
    processed: {
      type: Boolean,
      default: false,
    },
    aggregatedToDaily: {
      type: Boolean,
      default: false,
    },
  },
  {
    timestamps: true,
    collection: 'sessions',
  }
);

// Indexes
sessionSchema.index({ userId: 1, startTime: -1 });
sessionSchema.index({ startTime: -1 });
sessionSchema.index({ isActive: 1, userId: 1 });
sessionSchema.index({ 'device.platform': 1, startTime: -1 });
sessionSchema.index({ createdAt: 1 }, { expireAfterSeconds: 7776000 }); // 90 days TTL

// Static methods
sessionSchema.statics = {
  /**
   * Create or get active session
   */
  async getOrCreateSession(userId, sessionId, deviceInfo = {}, location = {}) {
    // Check for existing active session
    let session = await this.findOne({ sessionId, isActive: true });

    if (session) {
      return session;
    }

    // Create new session
    session = await this.create({
      sessionId,
      userId,
      startTime: new Date(),
      device: deviceInfo,
      location,
      isActive: true,
    });

    return session;
  },

  /**
   * End a session
   */
  async endSession(sessionId) {
    const session = await this.findOne({ sessionId });
    if (!session) return null;

    const endTime = new Date();
    const duration = Math.floor((endTime - session.startTime) / 1000);

    // Calculate engagement metrics
    const screenFlow = session.screenFlow || [];
    const totalScreenTime = screenFlow.reduce((sum, s) => sum + (s.duration || 0), 0);
    const averageScreenTime = screenFlow.length > 0 ? totalScreenTime / screenFlow.length : 0;

    const totalEvents = session.eventCounts.total || 0;
    const interactionEvents =
      (session.eventCounts.feedLikes || 0) +
      (session.eventCounts.feedComments || 0) +
      (session.eventCounts.reelLikes || 0) +
      (session.eventCounts.messages || 0);

    const interactionRate = totalEvents > 0 ? (interactionEvents / totalEvents) * 100 : 0;
    const bounceRate = screenFlow.length <= 1 ? 100 : 0;

    await this.updateOne(
      { sessionId },
      {
        $set: {
          endTime,
          duration,
          isActive: false,
          exitScreen: screenFlow.length > 0 ? screenFlow[screenFlow.length - 1].screenName : null,
          'engagement.totalScreenTime': totalScreenTime,
          'engagement.averageScreenTime': averageScreenTime,
          'engagement.bounceRate': bounceRate,
          'engagement.interactionRate': interactionRate,
        },
      }
    );

    return this.findOne({ sessionId });
  },

  /**
   * Update session with event
   */
  async recordEvent(sessionId, eventData) {
    const updateQuery = {
      $inc: {
        'eventCounts.total': 1,
      },
    };

    // Update specific event counter based on event name
    const eventCountMap = {
      screen_view: 'eventCounts.screenViews',
      feed_view: 'eventCounts.feedViews',
      feed_like: 'eventCounts.feedLikes',
      feed_comment: 'eventCounts.feedComments',
      reel_view: 'eventCounts.reelViews',
      reel_like: 'eventCounts.reelLikes',
      chat_message_send: 'eventCounts.messages',
      ai_message_send: 'eventCounts.aiChats',
      search_query: 'eventCounts.searches',
      product_view: 'eventCounts.productViews',
    };

    const counterField = eventCountMap[eventData.eventName];
    if (counterField) {
      updateQuery.$inc[counterField] = 1;
    }

    // Track screen flow
    if (eventData.eventName === 'screen_view' && eventData.properties?.screenName) {
      updateQuery.$push = {
        screenFlow: {
          screenName: eventData.properties.screenName,
          enteredAt: new Date(),
        },
      };
    }

    // Update content consumption
    if (eventData.eventName === 'feed_view') {
      updateQuery.$inc['engagement.contentConsumption.feedsViewed'] = 1;
    }
    if (eventData.eventName === 'reel_view') {
      updateQuery.$inc['engagement.contentConsumption.reelsWatched'] = 1;
      if (eventData.properties?.watchDuration) {
        updateQuery.$inc['engagement.contentConsumption.totalWatchTime'] =
          eventData.properties.watchDuration;
      }
    }
    if (eventData.eventName === 'product_view') {
      updateQuery.$inc['engagement.contentConsumption.productsViewed'] = 1;
    }

    await this.updateOne({ sessionId }, updateQuery);
  },

  /**
   * Get session statistics for a user
   */
  async getUserSessionStats(userId, startDate, endDate) {
    const match = { userId };
    if (startDate || endDate) {
      match.startTime = {};
      if (startDate) match.startTime.$gte = new Date(startDate);
      if (endDate) match.startTime.$lte = new Date(endDate);
    }

    return this.aggregate([
      { $match: match },
      {
        $group: {
          _id: '$userId',
          totalSessions: { $sum: 1 },
          totalDuration: { $sum: '$duration' },
          avgDuration: { $avg: '$duration' },
          avgEventsPerSession: { $avg: '$eventCounts.total' },
          totalFeedViews: { $sum: '$eventCounts.feedViews' },
          totalReelViews: { $sum: '$eventCounts.reelViews' },
          totalInteractions: {
            $sum: {
              $add: [
                '$eventCounts.feedLikes',
                '$eventCounts.feedComments',
                '$eventCounts.reelLikes',
                '$eventCounts.messages',
              ],
            },
          },
          avgBounceRate: { $avg: '$engagement.bounceRate' },
          avgInteractionRate: { $avg: '$engagement.interactionRate' },
          platforms: { $addToSet: '$device.platform' },
        },
      },
    ]);
  },

  /**
   * Get daily active sessions count
   */
  async getDailyActiveSessions(startDate, endDate) {
    return this.aggregate([
      {
        $match: {
          startTime: {
            $gte: new Date(startDate),
            $lte: new Date(endDate),
          },
        },
      },
      {
        $group: {
          _id: {
            $dateToString: { format: '%Y-%m-%d', date: '$startTime' },
          },
          sessions: { $sum: 1 },
          uniqueUsers: { $addToSet: '$userId' },
          avgDuration: { $avg: '$duration' },
          totalEvents: { $sum: '$eventCounts.total' },
        },
      },
      {
        $project: {
          _id: 0,
          date: '$_id',
          sessions: 1,
          uniqueUsers: { $size: '$uniqueUsers' },
          avgDuration: { $round: ['$avgDuration', 2] },
          totalEvents: 1,
        },
      },
      { $sort: { date: 1 } },
    ]);
  },
};

module.exports = mongoose.model('Session', sessionSchema);
