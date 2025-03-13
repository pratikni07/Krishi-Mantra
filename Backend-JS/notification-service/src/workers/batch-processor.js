const rabbitmq = require('../config/rabbitmq');
const config = require('../config');
const Notification = require('../models/notification.model');
const processor = require('./processor');
const logger = require('../utils/logger');

class BatchProcessor {
  async startConsumer() {
    try {
      const channel = rabbitmq.getChannel();
      
      // Set prefetch to control concurrency
      await channel.prefetch(1);
      
      // Process individual notifications
      await channel.consume(config.rabbitmq.queues.notification, async (msg) => {
        if (!msg) return;
        
        try {
          const notification = JSON.parse(msg.content.toString());
          logger.debug(`Processing notification: ${notification._id}`);
          
          await processor.processNotification(notification);
          
          // Acknowledge message
          channel.ack(msg);
        } catch (error) {
          logger.error('Error processing notification from queue:', error);
          // Negative acknowledge to requeue
          channel.nack(msg, false, true);
        }
      });
      
      // Process batches
      await channel.consume(config.rabbitmq.queues.batch, async (msg) => {
        if (!msg) return;
        
        try {
          const batch = JSON.parse(msg.content.toString());
          logger.info(`Processing batch: ${batch.batchId} with ${batch.count} notifications`);
          
          // Process each notification in the batch
          for (const notification of batch.notifications) {
            await processor.processNotification(notification);
          }
          
          // Acknowledge message
          channel.ack(msg);
        } catch (error) {
          logger.error('Error processing batch from queue:', error);
          // Negative acknowledge to requeue
          channel.nack(msg, false, true);
        }
      });
      
      logger.info('Batch processor started and consuming from queues');
    } catch (error) {
      logger.error('Failed to start batch processor:', error);
      throw error;
    }
  }

  async scheduleBatchProcessing() {
    const batchInterval = config.batch.intervalMs;
    
    // Run batch processing on a schedule
    setInterval(async () => {
      try {
        logger.debug('Starting scheduled batch processing');
        
        // Find pending notifications and process them in batches
        const pendingCount = await this._processPendingNotifications();
        
        logger.info(`Scheduled batch processing completed. Processed ${pendingCount} notifications.`);
      } catch (error) {
        logger.error('Error in scheduled batch processing:', error);
      }
    }, batchInterval);
    
    logger.info(`Scheduled batch processing every ${batchInterval}ms`);
  }

  async _processPendingNotifications() {
    try {
      const now = new Date();
      const batchSize = config.batch.size;
      
      // Find notifications ready to send
      const pendingNotifications = await Notification.find({
        status: 'pending',
        scheduledFor: { $lte: now }
      }).limit(batchSize);
      
      if (pendingNotifications.length === 0) {
        logger.debug('No pending notifications found for batch processing');
        return 0;
      }
      
      // Group notifications by user to avoid overwhelming users
      const groupedByUser = this._groupByUser(pendingNotifications);
      
      let processedCount = 0;
      
      // Process each user's batch
      for (const [userId, notifications] of Object.entries(groupedByUser)) {
        // Create a batch ID
        const batchId = `batch-${Date.now()}-${userId}`;
        
        // Update notifications with batch ID
        const notificationIds = notifications.map(n => n._id);
        await Notification.updateMany(
          { _id: { $in: notificationIds } },
          { batchId, status: 'processing' }
        );
        
        // Send to batch queue
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
        notifications
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