/**
 * Event Service
 * Handles high-throughput event processing for 100k+ users
 * Uses in-memory batching with periodic flushes to MongoDB
 */

const Event = require('../models/event.model');
const Session = require('../models/session.model');
const UserMetrics = require('../models/userMetrics.model');
const DailyMetrics = require('../models/dailyMetrics.model');
const Redis = require('../config/redis');
const RabbitMQ = require('../config/rabbitmq');
const config = require('../config');
const logger = require('../utils/logger');
const { BATCH_SETTINGS, QUEUES, EVENT_CATEGORIES } = require('../utils/constants');
const {
  getTodayString,
  getCurrentHour,
  validateEventData,
  calculateEngagementScore,
} = require('../utils/helpers');

// In-memory event buffer for batch processing.
// Bounded at MAX_BUFFER_SIZE; overflow spills to RabbitMQ so a Mongo outage
// or flush stall cannot grow the buffer until the process OOMs.
let eventBuffer = [];
let flushTimer = null;
let isFlushing = false;
let droppedEvents = 0;
const MAX_BUFFER_SIZE = Math.max(1000, (config.batch.size || 100) * 10);

class EventService {
  /**
   * Initialize event service
   */
  static async init() {
    // Start periodic flush timer
    flushTimer = setInterval(() => {
      this.flushBuffer();
    }, config.batch.intervalMs);

    // Start RabbitMQ consumer
    await this.startConsumer();

    logger.info('Event service initialized');
  }

  /**
   * Track a single event (adds to buffer)
   */
  static async trackEvent(eventData) {
    try {
      // Validate event
      const validation = validateEventData(eventData);
      if (!validation.isValid) {
        logger.warn('Invalid event data', { errors: validation.errors });
        return { success: false, errors: validation.errors };
      }

      // Enrich event with timestamp and defaults
      const enrichedEvent = {
        ...eventData,
        timestamp: eventData.timestamp || new Date(),
        eventCategory: eventData.eventCategory || this._getEventCategory(eventData.eventName),
      };

      // If buffer is at its hard cap, spill to RabbitMQ instead of growing
      // the in-process array. Prevents unbounded growth if flushes stall.
      if (eventBuffer.length >= MAX_BUFFER_SIZE) {
        droppedEvents++;
        if (droppedEvents === 1 || droppedEvents % 100 === 0) {
          logger.warn('Event buffer full, spilling to RabbitMQ', {
            bufferSize: eventBuffer.length,
            droppedTotal: droppedEvents,
          });
        }
        if (RabbitMQ.isConnected()) {
          await RabbitMQ.sendToQueue(enrichedEvent, QUEUES.EVENTS);
          return { success: true, queued: true, spilled: true };
        }
        // RabbitMQ unavailable too — drop the event rather than OOM the process.
        return { success: false, dropped: true, reason: 'buffer_full' };
      }

      // Add to buffer
      eventBuffer.push(enrichedEvent);

      // Update real-time counters in Redis
      await this._updateRealTimeCounters(enrichedEvent);

      // Fire-and-forget threshold flush — callers shouldn't block on disk I/O
      if (eventBuffer.length >= config.batch.size && !isFlushing) {
        this.flushBuffer().catch((err) =>
          logger.error('Background flush failed:', err.message)
        );
      }

      return { success: true, buffered: true };
    } catch (error) {
      logger.error('Error tracking event:', error.message);
      return { success: false, error: error.message };
    }
  }

  /**
   * Track multiple events (batch)
   */
  static async trackBatch(events) {
    try {
      const results = {
        success: 0,
        failed: 0,
        errors: [],
      };

      for (const event of events) {
        const result = await this.trackEvent(event);
        if (result.success) {
          results.success++;
        } else {
          results.failed++;
          results.errors.push(result.errors || result.error);
        }
      }

      return results;
    } catch (error) {
      logger.error('Error tracking batch:', error.message);
      return { success: 0, failed: events.length, error: error.message };
    }
  }

  /**
   * Flush event buffer to MongoDB
   */
  static async flushBuffer() {
    // Non-reentrant: if a flush is already in flight, skip. Otherwise two
    // concurrent flushes would double-insert the same event batch when the
    // interval timer and threshold trigger fire together.
    if (isFlushing || eventBuffer.length === 0) return;
    isFlushing = true;

    const eventsToFlush = eventBuffer;
    eventBuffer = [];

    const startTime = Date.now();
    logger.info(`Flushing ${eventsToFlush.length} events to MongoDB`);

    try {
      // Use ordered: false for better performance
      await Event.insertMany(eventsToFlush, { ordered: false });

      // Update session data
      await this._updateSessionsFromEvents(eventsToFlush);

      // Update daily metrics
      await this._updateDailyMetrics(eventsToFlush);

      logger.performance('Event flush', startTime, { count: eventsToFlush.length });
    } catch (error) {
      logger.error('Error flushing events:', error.message);

      // On error, send to dead letter queue via RabbitMQ
      if (RabbitMQ.isConnected()) {
        await RabbitMQ.sendBatchToQueue(eventsToFlush);
      }
    } finally {
      isFlushing = false;
    }
  }

  /**
   * Buffer telemetry for /health or metrics scraping.
   */
  static getBufferStats() {
    return {
      bufferSize: eventBuffer.length,
      maxBufferSize: MAX_BUFFER_SIZE,
      droppedEvents,
      isFlushing,
    };
  }

  /**
   * Start RabbitMQ consumer for async event processing
   */
  static async startConsumer() {
    await RabbitMQ.consume(QUEUES.EVENTS, async (data) => {
      await this.trackEvent(data);
    });

    await RabbitMQ.consume(QUEUES.BATCH, async (data) => {
      if (data.events && Array.isArray(data.events)) {
        await this.trackBatch(data.events);
      }
    });
  }

  /**
   * Send event to queue for async processing
   */
  static async queueEvent(eventData) {
    try {
      if (RabbitMQ.isConnected()) {
        await RabbitMQ.sendToQueue(eventData, QUEUES.EVENTS);
        return { success: true, queued: true };
      } else {
        // Fallback to direct processing
        return await this.trackEvent(eventData);
      }
    } catch (error) {
      logger.error('Error queuing event:', error.message);
      return { success: false, error: error.message };
    }
  }

  /**
   * Get event category from event name
   */
  static _getEventCategory(eventName) {
    const categoryMap = {
      screen_view: EVENT_CATEGORIES.NAVIGATION,
      app_open: EVENT_CATEGORIES.NAVIGATION,
      app_close: EVENT_CATEGORIES.NAVIGATION,
      feed_view: EVENT_CATEGORIES.CONTENT,
      feed_like: EVENT_CATEGORIES.ENGAGEMENT,
      feed_comment: EVENT_CATEGORIES.SOCIAL,
      feed_share: EVENT_CATEGORIES.SOCIAL,
      feed_create: EVENT_CATEGORIES.CONTENT,
      reel_view: EVENT_CATEGORIES.CONTENT,
      reel_like: EVENT_CATEGORIES.ENGAGEMENT,
      reel_comment: EVENT_CATEGORIES.SOCIAL,
      reel_share: EVENT_CATEGORIES.SOCIAL,
      product_view: EVENT_CATEGORIES.COMMERCE,
      product_search: EVENT_CATEGORIES.COMMERCE,
      chat_message_sent: EVENT_CATEGORIES.COMMUNICATION,
      ai_chat_message: EVENT_CATEGORIES.AI,
      user_login: EVENT_CATEGORIES.SYSTEM,
      user_logout: EVENT_CATEGORIES.SYSTEM,
    };

    return categoryMap[eventName] || EVENT_CATEGORIES.SYSTEM;
  }

  /**
   * Update real-time counters in Redis
   */
  static async _updateRealTimeCounters(event) {
    try {
      const today = getTodayString();
      const hour = getCurrentHour();

      // Use pipeline for atomic operations
      const pipeline = [
        // Increment today's event count
        { key: `events:count:${today}`, operation: 'incr' },
        // Increment hourly count
        { key: `events:hourly:${today}:${hour}`, operation: 'incr' },
        // Add user to today's active users set
        { key: `users:active:${today}`, value: event.userId, operation: 'sadd' },
        // Increment event type count
        { key: `events:type:${today}:${event.eventName}`, operation: 'incr' },
        // Increment category count
        { key: `events:category:${today}:${event.eventCategory}`, operation: 'incr' },
      ];

      for (const op of pipeline) {
        if (op.operation === 'incr') {
          await Redis.increment(op.key, 1, 86400); // 24 hour TTL
        } else if (op.operation === 'sadd') {
          // Use Redis client directly for set operations
          const client = Redis.getClient();
          if (client) {
            await client.sadd(op.key, op.value);
            await client.expire(op.key, 86400);
          }
        }
      }
    } catch (error) {
      logger.error('Error updating real-time counters:', error.message);
    }
  }

  /**
   * Update session data from events
   */
  static async _updateSessionsFromEvents(events) {
    try {
      // Group events by session
      const sessionEvents = {};
      for (const event of events) {
        if (!sessionEvents[event.sessionId]) {
          sessionEvents[event.sessionId] = [];
        }
        sessionEvents[event.sessionId].push(event);
      }

      // Update each session
      const updates = Object.entries(sessionEvents).map(([sessionId, sessionEvts]) => {
        const eventCounts = {};
        let lastScreen = null;
        let lastTimestamp = null;

        for (const evt of sessionEvts) {
          // Count event types
          const countKey = evt.eventName.replace(/_/g, '');
          eventCounts[countKey] = (eventCounts[countKey] || 0) + 1;
          eventCounts.total = (eventCounts.total || 0) + 1;

          // Track screen flow
          if (evt.eventName === 'screen_view' && evt.properties?.screenName) {
            lastScreen = evt.properties.screenName;
          }

          // Track last timestamp
          if (!lastTimestamp || evt.timestamp > lastTimestamp) {
            lastTimestamp = evt.timestamp;
          }
        }

        return {
          updateOne: {
            filter: { sessionId },
            update: {
              $inc: eventCounts,
              $set: { lastEventAt: lastTimestamp },
              $setOnInsert: {
                userId: sessionEvts[0].userId,
                startTime: sessionEvts[0].timestamp,
                device: sessionEvts[0].device || {},
              },
            },
            upsert: true,
          },
        };
      });

      if (updates.length > 0) {
        await Session.bulkWrite(updates, { ordered: false });
      }
    } catch (error) {
      logger.error('Error updating sessions:', error.message);
    }
  }

  /**
   * Update daily metrics from events
   */
  static async _updateDailyMetrics(events) {
    try {
      const today = getTodayString();
      const metrics = await DailyMetrics.getOrCreate(today);

      // Aggregate event counts by category
      const categoryCounts = {};
      const eventTypeCounts = {};
      const uniqueUsers = new Set();

      for (const event of events) {
        uniqueUsers.add(event.userId);

        // Category counts
        const category = event.eventCategory || 'system';
        categoryCounts[category] = (categoryCounts[category] || 0) + 1;

        // Event type counts
        eventTypeCounts[event.eventName] = (eventTypeCounts[event.eventName] || 0) + 1;
      }

      // Update metrics
      metrics.events.total += events.length;

      for (const [category, count] of Object.entries(categoryCounts)) {
        if (metrics.events.byCategory[category] !== undefined) {
          metrics.events.byCategory[category] += count;
        }
      }

      // Update content metrics
      if (eventTypeCounts.feed_view) {
        metrics.content.feeds.views += eventTypeCounts.feed_view;
      }
      if (eventTypeCounts.feed_like) {
        metrics.content.feeds.likes += eventTypeCounts.feed_like;
      }
      if (eventTypeCounts.feed_comment) {
        metrics.content.feeds.comments += eventTypeCounts.feed_comment;
      }
      if (eventTypeCounts.reel_view) {
        metrics.content.reels.views += eventTypeCounts.reel_view;
      }
      if (eventTypeCounts.reel_like) {
        metrics.content.reels.likes += eventTypeCounts.reel_like;
      }

      await metrics.save();
    } catch (error) {
      logger.error('Error updating daily metrics:', error.message);
    }
  }

  /**
   * Get real-time stats
   */
  static async getRealTimeStats() {
    try {
      const today = getTodayString();
      const hour = getCurrentHour();

      const client = Redis.getClient();

      const [todayEvents, hourlyEvents, activeUsers] = await Promise.all([
        Redis.get(`events:count:${today}`),
        Redis.get(`events:hourly:${today}:${hour}`),
        client ? client.scard(`users:active:${today}`) : 0,
      ]);

      return {
        todayEvents: parseInt(todayEvents) || 0,
        currentHourEvents: parseInt(hourlyEvents) || 0,
        activeUsers: activeUsers || 0,
        timestamp: new Date(),
      };
    } catch (error) {
      logger.error('Error getting real-time stats:', error.message);
      return null;
    }
  }

  /**
   * Cleanup and shutdown
   */
  static async shutdown() {
    if (flushTimer) {
      clearInterval(flushTimer);
    }

    // Flush remaining events
    await this.flushBuffer();

    logger.info('Event service shut down');
  }
}

module.exports = EventService;
