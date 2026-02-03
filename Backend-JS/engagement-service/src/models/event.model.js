const mongoose = require('mongoose');

/**
 * Event Log Schema
 * Tracks all user activities - optimized for 100k+ users with proper indexing
 */
const eventSchema = new mongoose.Schema(
  {
    // User identification
    userId: {
      type: String,
      required: true,
      index: true,
    },
    sessionId: {
      type: String,
      required: true,
      index: true,
    },

    // Event details
    eventName: {
      type: String,
      required: true,
      index: true,
      enum: [
        // Screen events
        'screen_view',
        'screen_exit',

        // Feed events
        'feed_view',
        'feed_like',
        'feed_unlike',
        'feed_comment',
        'feed_share',
        'feed_save',
        'feed_create',
        'feed_delete',

        // Reel events
        'reel_view',
        'reel_like',
        'reel_unlike',
        'reel_comment',
        'reel_share',
        'reel_swipe',
        'reel_watch_complete',

        // Chat events
        'chat_open',
        'chat_message_send',
        'chat_message_read',
        'group_create',
        'group_join',
        'group_leave',

        // AI events
        'ai_chat_start',
        'ai_message_send',
        'ai_image_analyze',

        // Marketplace events
        'product_view',
        'product_search',
        'product_filter',
        'product_share',
        'product_add_cart',
        'product_purchase',

        // Company events
        'company_view',
        'company_search',
        'company_contact',

        // Other events
        'search_query',
        'hashtag_click',
        'notification_click',
        'notification_dismiss',
        'profile_view',
        'profile_edit',
        'settings_change',
        'login',
        'logout',
        'app_open',
        'app_close',
        'app_background',
        'app_foreground',
        'error',
        'custom',
      ],
    },
    eventCategory: {
      type: String,
      required: true,
      index: true,
      enum: [
        'navigation',
        'engagement',
        'content',
        'social',
        'commerce',
        'communication',
        'ai',
        'system',
        'error',
      ],
    },

    // Event properties
    properties: {
      // Content identifiers
      contentId: String,
      contentType: {
        type: String,
        enum: ['feed', 'reel', 'product', 'company', 'scheme', 'crop', 'chat', 'message', 'notification'],
      },

      // Screen tracking
      screenName: String,
      previousScreen: String,

      // Duration metrics (in milliseconds)
      duration: Number,
      watchDuration: Number,
      completionRate: Number,

      // Position tracking
      scrollPosition: Number,
      resultPosition: Number,

      // Search and filter
      searchQuery: String,
      filterApplied: mongoose.Schema.Types.Mixed,

      // Interaction details
      interactionType: String,
      value: mongoose.Schema.Types.Mixed,

      // Additional metadata
      metadata: mongoose.Schema.Types.Mixed,
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
      screenWidth: Number,
      screenHeight: Number,
      networkType: String,
    },

    // Location data
    location: {
      latitude: Number,
      longitude: Number,
      country: String,
      region: String,
      city: String,
    },

    // Processing metadata
    processed: {
      type: Boolean,
      default: false,
      index: true,
    },
    processedAt: Date,

    // Timestamp
    timestamp: {
      type: Date,
      default: Date.now,
      index: true,
    },
  },
  {
    timestamps: true,
    collection: 'events',
    // Enable time-series collection for efficient time-based queries
    timeseries: {
      timeField: 'timestamp',
      metaField: 'userId',
      granularity: 'minutes',
    },
  }
);

// Compound indexes for efficient queries
eventSchema.index({ userId: 1, timestamp: -1 });
eventSchema.index({ userId: 1, eventName: 1, timestamp: -1 });
eventSchema.index({ sessionId: 1, timestamp: 1 });
eventSchema.index({ eventName: 1, eventCategory: 1, timestamp: -1 });
eventSchema.index({ 'properties.contentId': 1, eventName: 1 });
eventSchema.index({ timestamp: 1 }, { expireAfterSeconds: 7776000 }); // 90 days TTL

// Static methods for analytics queries
eventSchema.statics = {
  /**
   * Get events by user with pagination
   */
  async getByUser(userId, options = {}) {
    const { page = 1, limit = 50, eventName, startDate, endDate } = options;

    const query = { userId };

    if (eventName) {
      query.eventName = eventName;
    }

    if (startDate || endDate) {
      query.timestamp = {};
      if (startDate) query.timestamp.$gte = new Date(startDate);
      if (endDate) query.timestamp.$lte = new Date(endDate);
    }

    const events = await this.find(query)
      .sort({ timestamp: -1 })
      .skip((page - 1) * limit)
      .limit(limit)
      .lean();

    const total = await this.countDocuments(query);

    return {
      events,
      pagination: {
        page,
        limit,
        total,
        pages: Math.ceil(total / limit),
      },
    };
  },

  /**
   * Get event counts by type for a time period
   */
  async getEventCounts(options = {}) {
    const { userId, startDate, endDate, groupBy = 'eventName' } = options;

    const match = {};
    if (userId) match.userId = userId;
    if (startDate || endDate) {
      match.timestamp = {};
      if (startDate) match.timestamp.$gte = new Date(startDate);
      if (endDate) match.timestamp.$lte = new Date(endDate);
    }

    return this.aggregate([
      { $match: match },
      {
        $group: {
          _id: `$${groupBy}`,
          count: { $sum: 1 },
          uniqueUsers: { $addToSet: '$userId' },
        },
      },
      {
        $project: {
          _id: 0,
          name: '$_id',
          count: 1,
          uniqueUsers: { $size: '$uniqueUsers' },
        },
      },
      { $sort: { count: -1 } },
    ]);
  },

  /**
   * Get time series data for events
   */
  async getTimeSeries(options = {}) {
    const { eventName, startDate, endDate, interval = 'hour' } = options;

    const match = {};
    if (eventName) match.eventName = eventName;
    if (startDate || endDate) {
      match.timestamp = {};
      if (startDate) match.timestamp.$gte = new Date(startDate);
      if (endDate) match.timestamp.$lte = new Date(endDate);
    }

    const dateFormat = {
      minute: { $dateToString: { format: '%Y-%m-%d %H:%M', date: '$timestamp' } },
      hour: { $dateToString: { format: '%Y-%m-%d %H:00', date: '$timestamp' } },
      day: { $dateToString: { format: '%Y-%m-%d', date: '$timestamp' } },
      week: { $dateToString: { format: '%Y-W%V', date: '$timestamp' } },
      month: { $dateToString: { format: '%Y-%m', date: '$timestamp' } },
    };

    return this.aggregate([
      { $match: match },
      {
        $group: {
          _id: dateFormat[interval] || dateFormat.hour,
          count: { $sum: 1 },
          uniqueUsers: { $addToSet: '$userId' },
        },
      },
      {
        $project: {
          _id: 0,
          timestamp: '$_id',
          count: 1,
          uniqueUsers: { $size: '$uniqueUsers' },
        },
      },
      { $sort: { timestamp: 1 } },
    ]);
  },
};

module.exports = mongoose.model('Event', eventSchema);
