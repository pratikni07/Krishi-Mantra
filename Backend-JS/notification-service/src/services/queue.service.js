const rabbitmq = require('../config/rabbitmq');
const config = require('../config');
const logger = require('../utils/logger');

class QueueService {
  async sendToNotificationQueue(notification) {
    try {
      const channel = rabbitmq.getChannel();
      const message = JSON.stringify(notification);
      
      await channel.sendToQueue(
        config.rabbitmq.queues.notification,
        Buffer.from(message),
        { 
          persistent: true,
          priority: this._getPriorityValue(notification.priority)
        }
      );
      
      logger.debug(`Notification sent to queue: ${notification._id}`);
    } catch (error) {
      logger.error('Error sending to notification queue:', error);
      throw error;
    }
  }

  async sendToBatchQueue(notifications) {
    try {
      const channel = rabbitmq.getChannel();
      const batchId = new Date().getTime().toString();
      
      // Add batch ID to each notification
      const batchedNotifications = notifications.map(notification => ({
        ...notification.toObject(),
        batchId
      }));
      
      const message = JSON.stringify({
        batchId,
        count: batchedNotifications.length,
        notifications: batchedNotifications
      });
      
      await channel.sendToQueue(
        config.rabbitmq.queues.batch,
        Buffer.from(message),
        { persistent: true }
      );
      
      logger.debug(`Batch sent to queue: ${batchId} with ${batchedNotifications.length} notifications`);
      return batchId;
    } catch (error) {
      logger.error('Error sending to batch queue:', error);
      throw error;
    }
  }

  _getPriorityValue(priority) {
    switch(priority) {
      case 'high': return 3;
      case 'medium': return 2;
      case 'low': return 1;
      default: return 2;
    }
  }
}

module.exports = new QueueService(); 