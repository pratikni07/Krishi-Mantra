/**
 * Helper functions for notification service
 */

/**
 * Generate a unique batch ID
 * @param {string} prefix - Optional prefix for the batch ID
 * @returns {string} - Unique batch ID
 */
exports.generateBatchId = (prefix = 'batch') => {
  const timestamp = Date.now().toString();
  const random = Math.floor(Math.random() * 10000).toString().padStart(4, '0');
  return `${prefix}-${timestamp}-${random}`;
};

/**
 * Check if an object is empty
 * @param {Object} obj - Object to check
 * @returns {boolean} - True if object is empty
 */
exports.isEmpty = (obj) => {
  return Object.keys(obj).length === 0;
};

/**
 * Chunk an array into smaller arrays
 * @param {Array} array - Array to chunk
 * @param {number} size - Size of each chunk
 * @returns {Array} - Array of chunks
 */
exports.chunkArray = (array, size) => {
  const chunks = [];
  for (let i = 0; i < array.length; i += size) {
    chunks.push(array.slice(i, i + size));
  }
  return chunks;
};

/**
 * Calculate time to next batch processing
 * @param {number} intervalMs - Batch interval in milliseconds
 * @returns {number} - Milliseconds until next batch processing
 */
exports.timeToNextBatch = (intervalMs) => {
  const now = Date.now();
  const nextBatchTime = Math.ceil(now / intervalMs) * intervalMs;
  return nextBatchTime - now;
};

/**
 * Build push notification payload for different platforms
 * @param {Object} notification - Notification object
 * @returns {Object} - Push notification payload
 */
exports.buildPushPayload = (notification) => {
  return {
    title: notification.title,
    body: notification.body,
    data: notification.data || {},
    android: {
      priority: notification.priority === 'high' ? 'high' : 'normal',
      notification: {
        sound: 'default',
        channelId: notification.category || 'default',
        clickAction: notification.data?.action || 'OPEN_ACTIVITY'
      }
    },
    apns: {
      headers: {
        'apns-priority': notification.priority === 'high' ? '10' : '5'
      },
      payload: {
        aps: {
          alert: {
            title: notification.title,
            body: notification.body
          },
          sound: 'default',
          badge: 1,
          category: notification.category || 'default'
        }
      }
    },
    webpush: {
      headers: {
        Urgency: notification.priority === 'high' ? 'high' : 'normal'
      },
      notification: {
        title: notification.title,
        body: notification.body,
        icon: notification.data?.icon || '/icon.png',
        actions: notification.data?.actions || []
      }
    }
  };
}; 