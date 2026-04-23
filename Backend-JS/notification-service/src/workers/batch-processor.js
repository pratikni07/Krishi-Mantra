const rabbitmq = require('../config/rabbitmq');
const config = require('../config');
const Notification = require('../models/notification.model');
const processor = require('./processor');
const eventNotificationService = require('../services/event-notification.service');
const logger = require('../utils/logger');
const digestService = require('../services/digest.service');
const { NOTIFICATION_STATUS } = require('../utils/constants');

class BatchProcessor {
  async startConsumer() {
    try {
      const channel = rabbitmq.getChannel();
      await channel.prefetch(10);

      // Register each consumer with the shutdown tracker so graceful
      // shutdown can drain in-flight handler invocations before Mongo/Redis
      // close under us.
      const notifTag = await channel.consume(config.rabbitmq.queues.notification, async (msg) => {
        if (!msg) return;

        rabbitmq.onHandlerStart();
        try {
          const notificationData = JSON.parse(msg.content.toString());

          let notification;
          if (notificationData._id) {
            notification = notificationData;
          } else {
            notification = await Notification.create({
              userId: notificationData.userId,
              type: notificationData.type || 'in_app',
              title: notificationData.title,
              body: notificationData.body,
              data: notificationData.data,
              category: notificationData.category || 'system',
              priority: notificationData.priority || 'medium',
              status: NOTIFICATION_STATUS.PENDING,
              scheduledFor: new Date(),
            });
          }

          await processor.processNotification(notification);
          channel.ack(msg);
        } catch (error) {
          // Route every failed message to the DLQ (configured on the queue's
          // x-dead-letter-exchange) instead of requeueing. Prior logic only
          // dropped ValidationErrors; a malformed payload that threw any other
          // kind of error could still pin the consumer in a nack/requeue loop.
          logger.error('Error processing notification from queue, routing to DLQ:', error);
          channel.nack(msg, false, false);
        } finally {
          rabbitmq.onHandlerEnd();
        }
      });
      rabbitmq.trackConsumerTag(notifTag.consumerTag);

      const batchTag = await channel.consume(config.rabbitmq.queues.batch, async (msg) => {
        if (!msg) return;

        rabbitmq.onHandlerStart();
        try {
          const batch = JSON.parse(msg.content.toString());
          logger.info(`Processing batch: ${batch.batchId} with ${batch.count} notifications`);

          for (const notification of batch.notifications) {
            await processor.processNotification(notification);
          }

          channel.ack(msg);
        } catch (error) {
          logger.error('Error processing batch from queue, routing to DLQ:', error);
          channel.nack(msg, false, false);
        } finally {
          rabbitmq.onHandlerEnd();
        }
      });
      rabbitmq.trackConsumerTag(batchTag.consumerTag);

      const eventTag = await channel.consume(config.rabbitmq.queues.event, async (msg) => {
        if (!msg) return;

        rabbitmq.onHandlerStart();
        try {
          const eventPayload = JSON.parse(msg.content.toString());
          await eventNotificationService.handleEvent(eventPayload);
          channel.ack(msg);
        } catch (error) {
          logger.error('Error processing event from queue:', error);
          channel.nack(msg, false, false);
        } finally {
          rabbitmq.onHandlerEnd();
        }
      });
      rabbitmq.trackConsumerTag(eventTag.consumerTag);

      logger.info('Batch processor started and consuming notification, batch and event queues');
    } catch (error) {
      logger.error('Failed to start batch processor:', error);
      throw error;
    }
  }

  async scheduleBatchProcessing() {
    const batchInterval = config.batch.intervalMs;

    setInterval(async () => {
      try {
        logger.debug('Starting scheduled batch processing');
        const pendingCount = await this._processPendingNotifications();
        logger.info(`Scheduled batch processing completed. Processed ${pendingCount} notifications.`);
      } catch (error) {
        logger.error('Error in scheduled batch processing:', error);
      }
    }, batchInterval);

    setInterval(async () => {
      try {
        const flushed = await digestService.flushDigests();
        if (flushed) {
          logger.info(`Digest flush completed. Generated ${flushed} digest notifications.`);
        }
      } catch (error) {
        logger.error('Error during digest flush:', error);
      }
    }, config.batch.digestFlushIntervalMs || 300000);

    logger.info(`Scheduled batch processing every ${batchInterval}ms`);
  }

  async _processPendingNotifications() {
    try {
      const now = new Date();
      const batchSize = config.batch.size;

      const pendingNotifications = await Notification.find({
        status: { $in: [NOTIFICATION_STATUS.PENDING, NOTIFICATION_STATUS.DEFERRED] },
        scheduledFor: { $lte: now },
      }).limit(batchSize);

      if (pendingNotifications.length === 0) {
        logger.debug('No pending notifications found for batch processing');
        return 0;
      }

      const groupedByUser = this._groupByUser(pendingNotifications);
      let processedCount = 0;

      for (const [userId, notifications] of Object.entries(groupedByUser)) {
        const batchId = `batch-${Date.now()}-${userId}`;
        const notificationIds = notifications.map((n) => n._id);

        await Notification.updateMany(
          { _id: { $in: notificationIds } },
          { batchId, status: NOTIFICATION_STATUS.PROCESSING }
        );

        await this._sendToBatchQueue(notifications, batchId);
        processedCount += notifications.length;
      }

      return processedCount;
    } catch (error) {
      logger.error('Error processing pending notifications:', error);
      return 0;
    }
  }

  _groupByUser(notifications) {
    const grouped = {};

    for (const notification of notifications) {
      if (!grouped[notification.userId]) {
        grouped[notification.userId] = [];
      }
      grouped[notification.userId].push(notification);
    }

    return grouped;
  }

  async _sendToBatchQueue(notifications, batchId) {
    try {
      const channel = rabbitmq.getChannel();

      const message = JSON.stringify({
        batchId,
        count: notifications.length,
        notifications,
      });

      await channel.sendToQueue(
        config.rabbitmq.queues.batch,
        Buffer.from(message),
        { persistent: true }
      );

      logger.debug(`Sent batch ${batchId} with ${notifications.length} notifications to queue`);
      return true;
    } catch (error) {
      logger.error('Error sending batch to queue:', error);
      return false;
    }
  }
}

module.exports = new BatchProcessor();
