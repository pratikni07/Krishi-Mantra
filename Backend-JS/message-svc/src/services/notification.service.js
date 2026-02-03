const rabbitmq = require('../config/rabbitmq');

/**
 * Notification categories for different events
 */
const NOTIFICATION_CATEGORIES = {
  CONSULTANT_SERVICE: 'consultant_service',
  CHAT_MESSAGE: 'consultant_service',
  GROUP_MESSAGE: 'system',
  AI_CHAT: 'crop_care_ai',
  SYSTEM: 'system',
};

/**
 * Notification priorities
 */
const NOTIFICATION_PRIORITY = {
  LOW: 'low',
  MEDIUM: 'medium',
  HIGH: 'high',
};

/**
 * Notification Service for Message Events
 * Publishes notification events to RabbitMQ for processing by notification-service
 */
class NotificationService {
  /**
   * Send a notification to the queue
   * @param {Object} notification - Notification data
   * @returns {Promise<boolean>}
   */
  async sendNotification(notification) {
    try {
      const channel = rabbitmq.getChannel();
      if (!channel) {
        console.warn('[NotificationService] RabbitMQ not connected, skipping notification');
        return false;
      }

      const message = JSON.stringify({
        ...notification,
        createdAt: new Date().toISOString(),
        source: 'message-svc',
      });

      await channel.sendToQueue(
        rabbitmq.RABBITMQ_CONFIG.queues.notification,
        Buffer.from(message),
        {
          persistent: true,
          priority: this._getPriorityValue(notification.priority),
        }
      );

      console.log(`[NotificationService] Notification sent: ${notification.type} for user ${notification.userId}`);
      return true;
    } catch (error) {
      console.error('[NotificationService] Error sending notification:', error.message);
      return false;
    }
  }

  /**
   * Send notification when a message is received (for consultant/chat messages)
   * @param {Object} params - Message notification parameters
   * @param {string} params.recipientId - User ID of the message recipient
   * @param {string} params.recipientName - Name of the recipient
   * @param {string} params.senderId - User ID of the sender
   * @param {string} params.senderName - Name of the sender
   * @param {string} params.senderPhoto - Profile photo of the sender
   * @param {string} params.chatId - ID of the chat
   * @param {string} params.messageId - ID of the message
   * @param {string} params.messageContent - Content of the message (for preview)
   * @param {string} params.messageType - Type of message (text, image, etc.)
   * @param {boolean} params.isConsultant - Whether sender is a consultant
   * @param {boolean} params.isGroup - Whether this is a group message
   */
  async sendMessageNotification({
    recipientId,
    recipientName,
    senderId,
    senderName,
    senderPhoto,
    chatId,
    messageId,
    messageContent,
    messageType = 'text',
    isConsultant = false,
    isGroup = false,
  }) {
    // Don't notify the sender
    if (recipientId === senderId) {
      return false;
    }

    const contentPreview = messageContent
      ? messageContent.substring(0, 50) + (messageContent.length > 50 ? '...' : '')
      : '';

    const category = isConsultant
      ? NOTIFICATION_CATEGORIES.CONSULTANT_SERVICE
      : isGroup
      ? NOTIFICATION_CATEGORIES.GROUP_MESSAGE
      : NOTIFICATION_CATEGORIES.CHAT_MESSAGE;

    let body = '';
    if (messageType === 'text') {
      body = `${senderName}: ${contentPreview}`;
    } else if (messageType === 'image') {
      body = `${senderName} sent an image`;
    } else if (messageType === 'video') {
      body = `${senderName} sent a video`;
    } else if (messageType === 'audio') {
      body = `${senderName} sent a voice message`;
    } else if (messageType === 'file') {
      body = `${senderName} sent a file`;
    } else {
      body = `${senderName} sent a message`;
    }

    return this.sendNotification({
      userId: recipientId,
      type: 'in_app',
      category,
      priority: isConsultant ? NOTIFICATION_PRIORITY.HIGH : NOTIFICATION_PRIORITY.MEDIUM,
      title: isConsultant ? 'Consultant Message' : isGroup ? 'Group Message' : 'New Message',
      body,
      data: {
        type: 'message',
        chatId,
        messageId,
        senderId,
        senderName,
        senderPhoto,
        messageType,
        isConsultant,
        isGroup,
        actionUrl: `/chat/${chatId}`,
        screen: 'ChatDetailScreen',
      },
    });
  }

  /**
   * Send notification to multiple recipients (for group messages)
   * @param {Array<Object>} recipients - Array of recipient info objects
   * @param {Object} messageData - Message data
   */
  async sendGroupMessageNotifications(recipients, messageData) {
    const notifications = recipients
      .filter((recipient) => recipient.userId !== messageData.senderId)
      .map((recipient) =>
        this.sendMessageNotification({
          recipientId: recipient.userId,
          recipientName: recipient.userName,
          senderId: messageData.senderId,
          senderName: messageData.senderName,
          senderPhoto: messageData.senderPhoto,
          chatId: messageData.chatId,
          messageId: messageData.messageId,
          messageContent: messageData.content,
          messageType: messageData.mediaType || 'text',
          isConsultant: false,
          isGroup: true,
        })
      );

    await Promise.all(notifications);
    return notifications.length > 0;
  }

  /**
   * Send notification for AI chat response
   * @param {Object} params - AI notification parameters
   */
  async sendAIChatNotification({
    userId,
    userName,
    chatId,
    messageId,
    messageContent,
  }) {
    const contentPreview = messageContent
      ? messageContent.substring(0, 100) + (messageContent.length > 100 ? '...' : '')
      : 'New response from Crop Care AI';

    return this.sendNotification({
      userId,
      type: 'in_app',
      category: NOTIFICATION_CATEGORIES.AI_CHAT,
      priority: NOTIFICATION_PRIORITY.MEDIUM,
      title: 'Crop Care AI Response',
      body: contentPreview,
      data: {
        type: 'ai_chat',
        chatId,
        messageId,
        actionUrl: `/ai-chat/${chatId}`,
        screen: 'ChatDetailScreen',
      },
    });
  }

  /**
   * Convert priority string to numeric value
   * @param {string} priority - Priority level
   * @returns {number}
   */
  _getPriorityValue(priority) {
    switch (priority) {
      case 'high':
        return 3;
      case 'medium':
        return 2;
      case 'low':
        return 1;
      default:
        return 2;
    }
  }
}

module.exports = new NotificationService();
