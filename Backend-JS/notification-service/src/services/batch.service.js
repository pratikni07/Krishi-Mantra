const Notification = require('../models/notification.model');
const queueService = require('./queue.service');
const config = require('../config');
const logger = require('../utils/logger');

class BatchService {
  async processPendingNotifications() {
    try {
      // Get current time
      const now = new Date();
      
      // Find notifications that are scheduled for now or earlier and still pending
      const pendingNotifications = await Notification.find({
        status: 'pending',
        scheduledFor: { $lte: now }
      }).limit(config.batch.size);
      
      if (pendingNotifications.length === 0) {
        logger.debug('No pending notifications to process');
        return 0;
      }
      
      // Group notifications by user to avoid sending too many at once
      const groupedByUser = this._groupByUser(pendingNotifications);
      
      // Send each group to batch queue
      for (const [userId, notifications] of Object.entries(groupedByUser)) {
        await queueService.sendToBatchQueue(notifications);
        
        // Update status to acknowledge they're being processed
        const notificationIds = notifications.map(n => n._id);
        await Notification.updateMany(
          { _id: { $in: notificationIds } },
          { status: 'processing', updatedAt: new Date() }
        );
      }
      
      logger.info(`Processed ${pendingNotifications.length} pending notifications in ${Object.keys(groupedByUser).length} batches`);
      return pendingNotifications.length;
    } catch (error) {
      logger.error('Error in batch processing:', error);
      throw error;
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
}

module.exports = new BatchService(); 