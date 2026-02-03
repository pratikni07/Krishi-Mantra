const mongoose = require('mongoose');

/**
 * Daily Aggregated Metrics Schema
 * Pre-aggregated daily analytics for fast dashboard queries
 */
const dailyMetricsSchema = new mongoose.Schema(
  {
    // Date identifier (YYYY-MM-DD format)
    date: {
      type: String,
      required: true,
      index: true,
    },

    // User metrics
    users: {
      dau: { type: Number, default: 0 }, // Daily Active Users
      newUsers: { type: Number, default: 0 },
      returningUsers: { type: Number, default: 0 },
      uniqueVisitors: { type: Number, default: 0 },
    },

    // Session metrics
    sessions: {
      total: { type: Number, default: 0 },
      avgDuration: { type: Number, default: 0 }, // seconds
      totalDuration: { type: Number, default: 0 },
      bounceRate: { type: Number, default: 0 },
      avgEventsPerSession: { type: Number, default: 0 },
    },

    // Event metrics
    events: {
      total: { type: Number, default: 0 },
      byCategory: {
        navigation: { type: Number, default: 0 },
        engagement: { type: Number, default: 0 },
        content: { type: Number, default: 0 },
        social: { type: Number, default: 0 },
        commerce: { type: Number, default: 0 },
        communication: { type: Number, default: 0 },
        ai: { type: Number, default: 0 },
        system: { type: Number, default: 0 },
      },
      topEvents: [
        {
          eventName: String,
          count: Number,
          uniqueUsers: Number,
        },
      ],
    },

    // Content metrics
    content: {
      feeds: {
        created: { type: Number, default: 0 },
        views: { type: Number, default: 0 },
        likes: { type: Number, default: 0 },
        comments: { type: Number, default: 0 },
        shares: { type: Number, default: 0 },
        uniqueViewers: { type: Number, default: 0 },
      },
      reels: {
        created: { type: Number, default: 0 },
        views: { type: Number, default: 0 },
        likes: { type: Number, default: 0 },
        comments: { type: Number, default: 0 },
        shares: { type: Number, default: 0 },
        totalWatchTime: { type: Number, default: 0 }, // seconds
        avgCompletionRate: { type: Number, default: 0 },
      },
      products: {
        views: { type: Number, default: 0 },
        searches: { type: Number, default: 0 },
        purchases: { type: Number, default: 0 },
      },
    },

    // Feature usage
    features: {
      feedActive: { type: Number, default: 0 },
      reelActive: { type: Number, default: 0 },
      chatActive: { type: Number, default: 0 },
      aiActive: { type: Number, default: 0 },
      marketplaceActive: { type: Number, default: 0 },
      cropCalendarActive: { type: Number, default: 0 },
      schemesActive: { type: Number, default: 0 },
      weatherActive: { type: Number, default: 0 },
    },

    // Screen analytics
    screens: {
      topScreens: [
        {
          screenName: String,
          visits: Number,
          uniqueUsers: Number,
          avgTime: Number,
        },
      ],
    },

    // Device breakdown
    devices: {
      ios: { type: Number, default: 0 },
      android: { type: Number, default: 0 },
      web: { type: Number, default: 0 },
    },

    // Location breakdown
    locations: {
      topCountries: [
        {
          country: String,
          users: Number,
        },
      ],
      topRegions: [
        {
          region: String,
          users: Number,
        },
      ],
    },

    // Engagement distribution
    engagement: {
      powerUsers: { type: Number, default: 0 },
      highEngagement: { type: Number, default: 0 },
      mediumEngagement: { type: Number, default: 0 },
      lowEngagement: { type: Number, default: 0 },
      inactive: { type: Number, default: 0 },
      avgEngagementScore: { type: Number, default: 0 },
    },

    // Retention metrics
    retention: {
      day1: { type: Number, default: 0 }, // % of users who returned next day
      day7: { type: Number, default: 0 },
      day30: { type: Number, default: 0 },
    },

    // Hourly breakdown
    hourlyActivity: {
      type: Map,
      of: {
        sessions: Number,
        events: Number,
        uniqueUsers: Number,
      },
      default: {},
    },

    // Processing metadata
    processed: { type: Boolean, default: false },
    processedAt: Date,
  },
  {
    timestamps: true,
    collection: 'daily_metrics',
  }
);

// Indexes
dailyMetricsSchema.index({ date: -1 });
dailyMetricsSchema.index({ createdAt: 1 }, { expireAfterSeconds: 31536000 }); // 1 year TTL

// Static methods
dailyMetricsSchema.statics = {
  /**
   * Get or create daily metrics for a date
   */
  async getOrCreate(date) {
    const dateStr = typeof date === 'string' ? date : date.toISOString().split('T')[0];

    let metrics = await this.findOne({ date: dateStr });

    if (!metrics) {
      metrics = await this.create({ date: dateStr });
    }

    return metrics;
  },

  /**
   * Get metrics for date range
   */
  async getRange(startDate, endDate) {
    return this.find({
      date: {
        $gte: startDate,
        $lte: endDate,
      },
    })
      .sort({ date: 1 })
      .lean();
  },

  /**
   * Get summary metrics for dashboard
   */
  async getDashboardSummary(days = 30) {
    const endDate = new Date();
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - days);

    const metrics = await this.find({
      date: {
        $gte: startDate.toISOString().split('T')[0],
        $lte: endDate.toISOString().split('T')[0],
      },
    }).lean();

    if (metrics.length === 0) {
      return null;
    }

    // Aggregate summary
    const summary = {
      period: { start: startDate, end: endDate, days },
      users: {
        totalDAU: 0,
        avgDAU: 0,
        peakDAU: 0,
        totalNewUsers: 0,
      },
      sessions: {
        total: 0,
        avgPerDay: 0,
        avgDuration: 0,
      },
      events: {
        total: 0,
        avgPerDay: 0,
      },
      content: {
        totalFeedViews: 0,
        totalReelViews: 0,
        totalInteractions: 0,
      },
      engagement: {
        avgScore: 0,
      },
      trend: [],
    };

    let totalDuration = 0;
    let totalDAU = 0;

    for (const day of metrics) {
      summary.users.totalDAU += day.users.dau;
      summary.users.totalNewUsers += day.users.newUsers;
      summary.users.peakDAU = Math.max(summary.users.peakDAU, day.users.dau);

      summary.sessions.total += day.sessions.total;
      totalDuration += day.sessions.totalDuration;

      summary.events.total += day.events.total;

      summary.content.totalFeedViews += day.content.feeds.views;
      summary.content.totalReelViews += day.content.reels.views;
      summary.content.totalInteractions +=
        day.content.feeds.likes +
        day.content.feeds.comments +
        day.content.reels.likes +
        day.content.reels.comments;

      totalDAU += day.users.dau;

      summary.trend.push({
        date: day.date,
        dau: day.users.dau,
        sessions: day.sessions.total,
        events: day.events.total,
      });
    }

    const dayCount = metrics.length || 1;
    summary.users.avgDAU = Math.round(totalDAU / dayCount);
    summary.sessions.avgPerDay = Math.round(summary.sessions.total / dayCount);
    summary.sessions.avgDuration = Math.round(totalDuration / (summary.sessions.total || 1));
    summary.events.avgPerDay = Math.round(summary.events.total / dayCount);

    return summary;
  },

  /**
   * Get comparison between two periods
   */
  async getPeriodComparison(currentStart, currentEnd, previousStart, previousEnd) {
    const [currentMetrics, previousMetrics] = await Promise.all([
      this.getRange(currentStart, currentEnd),
      this.getRange(previousStart, previousEnd),
    ]);

    const sumMetrics = (metrics) => {
      return metrics.reduce(
        (acc, day) => {
          acc.dau += day.users.dau;
          acc.sessions += day.sessions.total;
          acc.events += day.events.total;
          acc.feedViews += day.content.feeds.views;
          acc.reelViews += day.content.reels.views;
          return acc;
        },
        { dau: 0, sessions: 0, events: 0, feedViews: 0, reelViews: 0 }
      );
    };

    const current = sumMetrics(currentMetrics);
    const previous = sumMetrics(previousMetrics);

    const calculateChange = (curr, prev) => {
      if (prev === 0) return curr > 0 ? 100 : 0;
      return Math.round(((curr - prev) / prev) * 100);
    };

    return {
      current: {
        period: { start: currentStart, end: currentEnd },
        ...current,
        avgDAU: Math.round(current.dau / (currentMetrics.length || 1)),
      },
      previous: {
        period: { start: previousStart, end: previousEnd },
        ...previous,
        avgDAU: Math.round(previous.dau / (previousMetrics.length || 1)),
      },
      change: {
        dau: calculateChange(current.dau, previous.dau),
        sessions: calculateChange(current.sessions, previous.sessions),
        events: calculateChange(current.events, previous.events),
        feedViews: calculateChange(current.feedViews, previous.feedViews),
        reelViews: calculateChange(current.reelViews, previous.reelViews),
      },
    };
  },
};

module.exports = mongoose.model('DailyMetrics', dailyMetricsSchema);
