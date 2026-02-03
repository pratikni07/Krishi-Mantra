const mongoose = require('mongoose');

/**
 * User Engagement Metrics Schema
 * Aggregated metrics per user - optimized for 100k+ users with efficient queries
 */
const userMetricsSchema = new mongoose.Schema(
  {
    userId: {
      type: String,
      required: true,
      unique: true,
      index: true,
    },

    // Session metrics
    sessions: {
      total: { type: Number, default: 0 },
      last7Days: { type: Number, default: 0 },
      last30Days: { type: Number, default: 0 },
      avgDuration: { type: Number, default: 0 }, // seconds
      totalDuration: { type: Number, default: 0 },
      longestSession: { type: Number, default: 0 },
    },

    // Activity metrics
    activity: {
      totalEvents: { type: Number, default: 0 },
      last7DaysEvents: { type: Number, default: 0 },
      last30DaysEvents: { type: Number, default: 0 },
      firstActivity: Date,
      lastActivity: { type: Date, index: true },
      daysActive: { type: Number, default: 0 },
      streakCurrent: { type: Number, default: 0 },
      streakLongest: { type: Number, default: 0 },
    },

    // Content engagement
    engagement: {
      feeds: {
        viewed: { type: Number, default: 0 },
        liked: { type: Number, default: 0 },
        commented: { type: Number, default: 0 },
        shared: { type: Number, default: 0 },
        created: { type: Number, default: 0 },
        avgViewDuration: { type: Number, default: 0 },
      },
      reels: {
        viewed: { type: Number, default: 0 },
        liked: { type: Number, default: 0 },
        commented: { type: Number, default: 0 },
        shared: { type: Number, default: 0 },
        totalWatchTime: { type: Number, default: 0 },
        avgCompletionRate: { type: Number, default: 0 },
      },
      products: {
        viewed: { type: Number, default: 0 },
        searched: { type: Number, default: 0 },
        shared: { type: Number, default: 0 },
        purchased: { type: Number, default: 0 },
      },
      ai: {
        chatsStarted: { type: Number, default: 0 },
        messagesSent: { type: Number, default: 0 },
        imagesAnalyzed: { type: Number, default: 0 },
      },
      chat: {
        conversationsStarted: { type: Number, default: 0 },
        messagesSent: { type: Number, default: 0 },
        groupsJoined: { type: Number, default: 0 },
      },
    },

    // Screen usage
    screenUsage: {
      type: Map,
      of: {
        visits: { type: Number, default: 0 },
        totalTime: { type: Number, default: 0 }, // seconds
        avgTime: { type: Number, default: 0 },
        lastVisit: Date,
      },
      default: {},
    },

    // Feature adoption
    featureAdoption: {
      feedsUsed: { type: Boolean, default: false },
      reelsUsed: { type: Boolean, default: false },
      chatUsed: { type: Boolean, default: false },
      aiUsed: { type: Boolean, default: false },
      marketplaceUsed: { type: Boolean, default: false },
      cropCalendarUsed: { type: Boolean, default: false },
      schemesUsed: { type: Boolean, default: false },
      weatherUsed: { type: Boolean, default: false },
    },

    // User segments
    segments: {
      engagementLevel: {
        type: String,
        enum: ['inactive', 'low', 'medium', 'high', 'power_user'],
        default: 'low',
        index: true,
      },
      userType: {
        type: String,
        enum: ['new', 'returning', 'loyal', 'churned', 'resurrected'],
        default: 'new',
        index: true,
      },
      primaryFeature: String, // Most used feature
      cohort: String, // Registration week/month
    },

    // Churn prediction
    churnRisk: {
      score: { type: Number, default: 0, min: 0, max: 100 },
      level: {
        type: String,
        enum: ['low', 'medium', 'high'],
        default: 'low',
      },
      lastCalculated: Date,
      factors: [String],
    },

    // Engagement score (0-100)
    engagementScore: {
      current: { type: Number, default: 0, min: 0, max: 100 },
      last7Days: { type: Number, default: 0 },
      last30Days: { type: Number, default: 0 },
      trend: {
        type: String,
        enum: ['increasing', 'stable', 'decreasing'],
        default: 'stable',
      },
    },

    // Top content
    topContent: {
      topHashtags: [{ tag: String, count: Number }],
      topCategories: [{ category: String, count: Number }],
      favoriteScreens: [String],
    },

    // Device info
    devices: [
      {
        deviceId: String,
        platform: String,
        lastUsed: Date,
        sessions: Number,
      },
    ],

    // Processing metadata
    lastAggregated: Date,
    version: { type: Number, default: 1 },
  },
  {
    timestamps: true,
    collection: 'user_metrics',
  }
);

// Indexes
userMetricsSchema.index({ 'activity.lastActivity': -1 });
userMetricsSchema.index({ 'segments.engagementLevel': 1 });
userMetricsSchema.index({ 'segments.userType': 1 });
userMetricsSchema.index({ 'churnRisk.level': 1 });
userMetricsSchema.index({ 'engagementScore.current': -1 });

// Static methods
userMetricsSchema.statics = {
  /**
   * Get or create user metrics
   */
  async getOrCreate(userId) {
    let metrics = await this.findOne({ userId });

    if (!metrics) {
      metrics = await this.create({
        userId,
        'activity.firstActivity': new Date(),
        'activity.lastActivity': new Date(),
      });
    }

    return metrics;
  },

  /**
   * Update metrics with new event
   */
  async recordEvent(userId, eventData) {
    const updateQuery = {
      $inc: {
        'activity.totalEvents': 1,
      },
      $set: {
        'activity.lastActivity': new Date(),
      },
    };

    // Update engagement metrics based on event type
    const eventMetricMap = {
      feed_view: { 'engagement.feeds.viewed': 1 },
      feed_like: { 'engagement.feeds.liked': 1 },
      feed_comment: { 'engagement.feeds.commented': 1 },
      feed_share: { 'engagement.feeds.shared': 1 },
      feed_create: { 'engagement.feeds.created': 1 },
      reel_view: { 'engagement.reels.viewed': 1 },
      reel_like: { 'engagement.reels.liked': 1 },
      reel_comment: { 'engagement.reels.commented': 1 },
      reel_share: { 'engagement.reels.shared': 1 },
      product_view: { 'engagement.products.viewed': 1 },
      product_search: { 'engagement.products.searched': 1 },
      product_share: { 'engagement.products.shared': 1 },
      product_purchase: { 'engagement.products.purchased': 1 },
      ai_chat_start: { 'engagement.ai.chatsStarted': 1 },
      ai_message_send: { 'engagement.ai.messagesSent': 1 },
      ai_image_analyze: { 'engagement.ai.imagesAnalyzed': 1 },
      chat_message_send: { 'engagement.chat.messagesSent': 1 },
      group_create: { 'engagement.chat.conversationsStarted': 1 },
      group_join: { 'engagement.chat.groupsJoined': 1 },
    };

    const metricUpdate = eventMetricMap[eventData.eventName];
    if (metricUpdate) {
      Object.assign(updateQuery.$inc, metricUpdate);
    }

    // Update feature adoption
    const featureAdoptionMap = {
      feed_view: 'featureAdoption.feedsUsed',
      reel_view: 'featureAdoption.reelsUsed',
      chat_message_send: 'featureAdoption.chatUsed',
      ai_message_send: 'featureAdoption.aiUsed',
      product_view: 'featureAdoption.marketplaceUsed',
    };

    const featureField = featureAdoptionMap[eventData.eventName];
    if (featureField) {
      updateQuery.$set[featureField] = true;
    }

    // Update screen usage
    if (eventData.eventName === 'screen_view' && eventData.properties?.screenName) {
      const screenKey = `screenUsage.${eventData.properties.screenName.replace(/\./g, '_')}`;
      updateQuery.$inc[`${screenKey}.visits`] = 1;
      updateQuery.$set[`${screenKey}.lastVisit`] = new Date();
    }

    // Update reel watch time
    if (eventData.eventName === 'reel_view' && eventData.properties?.watchDuration) {
      updateQuery.$inc['engagement.reels.totalWatchTime'] = eventData.properties.watchDuration;
    }

    await this.updateOne({ userId }, updateQuery, { upsert: true });
  },

  /**
   * Calculate engagement score
   */
  calculateEngagementScore(metrics) {
    let score = 0;

    // Session frequency (max 25 points)
    const sessionsPerWeek = metrics.sessions.last7Days || 0;
    score += Math.min(sessionsPerWeek * 5, 25);

    // Session duration (max 20 points)
    const avgDuration = metrics.sessions.avgDuration || 0;
    score += Math.min(avgDuration / 60, 20); // 1 point per minute, max 20

    // Content engagement (max 30 points)
    const totalEngagements =
      (metrics.engagement.feeds.liked || 0) +
      (metrics.engagement.feeds.commented || 0) +
      (metrics.engagement.reels.liked || 0) +
      (metrics.engagement.chat.messagesSent || 0);
    score += Math.min(totalEngagements, 30);

    // Feature adoption (max 15 points)
    const featuresUsed = Object.values(metrics.featureAdoption || {}).filter(Boolean).length;
    score += featuresUsed * 2; // 2 points per feature

    // Streak bonus (max 10 points)
    score += Math.min(metrics.activity.streakCurrent || 0, 10);

    return Math.min(Math.round(score), 100);
  },

  /**
   * Determine engagement level
   */
  determineEngagementLevel(score) {
    if (score >= 80) return 'power_user';
    if (score >= 60) return 'high';
    if (score >= 40) return 'medium';
    if (score >= 20) return 'low';
    return 'inactive';
  },

  /**
   * Calculate churn risk
   */
  calculateChurnRisk(metrics) {
    let riskScore = 0;
    const factors = [];

    // Days since last activity
    const lastActivity = metrics.activity.lastActivity;
    if (lastActivity) {
      const daysSinceActive = Math.floor((Date.now() - lastActivity) / (1000 * 60 * 60 * 24));
      if (daysSinceActive > 30) {
        riskScore += 40;
        factors.push('inactive_30_days');
      } else if (daysSinceActive > 14) {
        riskScore += 25;
        factors.push('inactive_14_days');
      } else if (daysSinceActive > 7) {
        riskScore += 15;
        factors.push('inactive_7_days');
      }
    }

    // Declining engagement
    if (
      metrics.engagementScore.trend === 'decreasing' ||
      metrics.engagementScore.last7Days < metrics.engagementScore.last30Days * 0.5
    ) {
      riskScore += 20;
      factors.push('declining_engagement');
    }

    // Low feature adoption
    const featuresUsed = Object.values(metrics.featureAdoption || {}).filter(Boolean).length;
    if (featuresUsed <= 2) {
      riskScore += 15;
      factors.push('low_feature_adoption');
    }

    // Broken streak
    if (metrics.activity.streakCurrent === 0 && metrics.activity.streakLongest > 5) {
      riskScore += 10;
      factors.push('broken_streak');
    }

    // Short sessions
    if (metrics.sessions.avgDuration < 60) {
      riskScore += 10;
      factors.push('short_sessions');
    }

    let level = 'low';
    if (riskScore >= 60) level = 'high';
    else if (riskScore >= 30) level = 'medium';

    return {
      score: Math.min(riskScore, 100),
      level,
      factors,
      lastCalculated: new Date(),
    };
  },

  /**
   * Get top users by engagement
   */
  async getTopUsers(limit = 100, options = {}) {
    const { segment, minScore = 0 } = options;

    const query = { 'engagementScore.current': { $gte: minScore } };
    if (segment) {
      query['segments.engagementLevel'] = segment;
    }

    return this.find(query)
      .sort({ 'engagementScore.current': -1 })
      .limit(limit)
      .select('userId engagementScore segments activity.lastActivity')
      .lean();
  },

  /**
   * Get users at churn risk
   */
  async getChurnRiskUsers(level = 'high', limit = 100) {
    return this.find({ 'churnRisk.level': level })
      .sort({ 'churnRisk.score': -1 })
      .limit(limit)
      .select('userId churnRisk activity.lastActivity engagementScore')
      .lean();
  },

  /**
   * Get engagement distribution
   */
  async getEngagementDistribution() {
    return this.aggregate([
      {
        $group: {
          _id: '$segments.engagementLevel',
          count: { $sum: 1 },
          avgScore: { $avg: '$engagementScore.current' },
        },
      },
      {
        $project: {
          _id: 0,
          level: '$_id',
          count: 1,
          avgScore: { $round: ['$avgScore', 2] },
        },
      },
    ]);
  },
};

module.exports = mongoose.model('UserMetrics', userMetricsSchema);
