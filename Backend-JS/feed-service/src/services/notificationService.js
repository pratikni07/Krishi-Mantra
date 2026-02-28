const rabbitmq = require('../config/rabbitmq');

/**
 * Notification categories for different events
 */
const NOTIFICATION_CATEGORIES = {
  NEW_POST: 'new_post',
  LIKE: 'post_engagement',
  COMMENT: 'post_engagement',
  FOLLOW: 'system',
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
 * Notification Service for Feed Events
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
        source: 'feed-service',
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
   * Send notification when someone likes a post
   * @param {Object} params - Like notification parameters
   * @param {string} params.feedOwnerId - User ID of the feed owner
   * @param {string} params.feedOwnerName - Name of the feed owner
   * @param {string} params.likerId - User ID of the person who liked
   * @param {string} params.likerName - Name of the person who liked
   * @param {string} params.likerPhoto - Profile photo of the liker
   * @param {string} params.feedId - ID of the feed that was liked
   * @param {string} params.feedContent - Content of the feed (for preview)
   */
  async sendLikeNotification({ feedOwnerId, feedOwnerName, likerId, likerName, likerPhoto, feedId, feedContent }) {
    // Don't notify if user liked their own post
    if (feedOwnerId === likerId) {
      return false;
    }

    const contentPreview = feedContent ? feedContent.substring(0, 50) + (feedContent.length > 50 ? '...' : '') : '';

    return this.sendNotification({
      userId: feedOwnerId,
      type: 'in_app',
      category: NOTIFICATION_CATEGORIES.LIKE,
      priority: NOTIFICATION_PRIORITY.MEDIUM,
      title: 'New Like',
      body: `${likerName} liked your post${contentPreview ? `: "${contentPreview}"` : ''}`,
      data: {
        type: 'like',
        feedId,
        likerId,
        likerName,
        likerPhoto,
        actionUrl: `/feed/${feedId}`,
        screen: 'FeedDetailsScreen',
      },
    });
  }

  /**
   * Send notification when someone comments on a post
   * @param {Object} params - Comment notification parameters
   * @param {string} params.feedOwnerId - User ID of the feed owner
   * @param {string} params.feedOwnerName - Name of the feed owner
   * @param {string} params.commenterId - User ID of the commenter
   * @param {string} params.commenterName - Name of the commenter
   * @param {string} params.commenterPhoto - Profile photo of the commenter
   * @param {string} params.feedId - ID of the feed that was commented on
   * @param {string} params.commentId - ID of the comment
   * @param {string} params.commentContent - Content of the comment (for preview)
   * @param {boolean} params.isReply - Whether this is a reply to another comment
   * @param {string} params.parentCommentOwnerId - Owner of the parent comment (for replies)
   */
  async sendCommentNotification({
    feedOwnerId,
    feedOwnerName,
    commenterId,
    commenterName,
    commenterPhoto,
    feedId,
    commentId,
    commentContent,
    isReply = false,
    parentCommentOwnerId = null,
  }) {
    const notifications = [];

    // Don't notify if user commented on their own post
    if (feedOwnerId !== commenterId) {
      const contentPreview = commentContent
        ? commentContent.substring(0, 50) + (commentContent.length > 50 ? '...' : '')
        : '';

      notifications.push(
        this.sendNotification({
          userId: feedOwnerId,
          type: 'in_app',
          category: NOTIFICATION_CATEGORIES.COMMENT,
          priority: NOTIFICATION_PRIORITY.HIGH,
          title: isReply ? 'New Reply' : 'New Comment',
          body: `${commenterName} ${isReply ? 'replied to a comment on' : 'commented on'} your post: "${contentPreview}"`,
          data: {
            type: 'comment',
            feedId,
            commentId,
            commenterId,
            commenterName,
            commenterPhoto,
            isReply,
            actionUrl: `/feed/${feedId}`,
            screen: 'FeedDetailsScreen',
          },
        })
      );
    }

    // If this is a reply, also notify the parent comment owner
    if (isReply && parentCommentOwnerId && parentCommentOwnerId !== commenterId && parentCommentOwnerId !== feedOwnerId) {
      const contentPreview = commentContent
        ? commentContent.substring(0, 50) + (commentContent.length > 50 ? '...' : '')
        : '';

      notifications.push(
        this.sendNotification({
          userId: parentCommentOwnerId,
          type: 'in_app',
          category: NOTIFICATION_CATEGORIES.COMMENT,
          priority: NOTIFICATION_PRIORITY.HIGH,
          title: 'New Reply',
          body: `${commenterName} replied to your comment: "${contentPreview}"`,
          data: {
            type: 'reply',
            feedId,
            commentId,
            commenterId,
            commenterName,
            commenterPhoto,
            actionUrl: `/feed/${feedId}`,
            screen: 'FeedDetailsScreen',
          },
        })
      );
    }

    await Promise.all(notifications);
    return notifications.length > 0;
  }

  /**
   * Send notification when a new post is created (for followers)
   * @param {Object} params - New post notification parameters
   * @param {Array<string>} params.followerIds - Array of follower user IDs
   * @param {string} params.authorId - User ID of the post author
   * @param {string} params.authorName - Name of the post author
   * @param {string} params.authorPhoto - Profile photo of the author
   * @param {string} params.feedId - ID of the new feed
   * @param {string} params.feedContent - Content of the feed (for preview)
   */
  async sendNewPostNotification({ followerIds, authorId, authorName, authorPhoto, feedId, feedContent }) {
    if (!followerIds || followerIds.length === 0) {
      return false;
    }

    const contentPreview = feedContent
      ? feedContent.substring(0, 50) + (feedContent.length > 50 ? '...' : '')
      : '';

    const notifications = followerIds
      .filter((followerId) => followerId !== authorId)
      .map((followerId) =>
        this.sendNotification({
          userId: followerId,
          type: 'in_app',
          category: NOTIFICATION_CATEGORIES.NEW_POST,
          priority: NOTIFICATION_PRIORITY.LOW,
          title: 'New Post',
          body: `${authorName} shared a new post${contentPreview ? `: "${contentPreview}"` : ''}`,
          data: {
            type: 'new_post',
            feedId,
            authorId,
            authorName,
            authorPhoto,
            actionUrl: `/feed/${feedId}`,
            screen: 'FeedDetailsScreen',
          },
        })
      );

    await Promise.all(notifications);
    return notifications.length > 0;
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
