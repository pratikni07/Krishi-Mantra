// services/message.service.js
const Message = require("../models/message.model");
const Chat = require("../models/chat.model");
const Group = require("../models/group.model");

class MessageService {
  /**
   * Create a new message
   * @param {Object} messageData - Message data
   * @param {string} messageData.chatId - Chat ID
   * @param {string} messageData.sender - Sender user ID
   * @param {string} messageData.senderName - Sender name
   * @param {string} messageData.senderPhoto - Sender profile photo
   * @param {string} messageData.content - Message content
   * @param {string} messageData.mediaType - Media type (optional)
   * @param {string} messageData.mediaUrl - Media URL (optional)
   * @param {Object} messageData.mediaMetadata - Media metadata (optional)
   * @returns {Promise<Object>} Created message
   */
  async createMessage(messageData) {
    const {
      chatId,
      sender,
      senderName,
      senderPhoto,
      content,
      mediaType,
      mediaUrl,
      mediaMetadata,
    } = messageData;

    // Check if chat exists
    const chat = await Chat.findById(chatId);
    if (!chat) {
      throw new Error("Chat not found");
    }

    // Check if user is a participant
    const senderInfo = chat.participants.find((p) => p.userId === sender);
    if (!senderInfo) {
      throw new Error("Access denied");
    }
    if (chat.type === "group") {
      const group = await Group.findOne({ chatId });
      if (group.onlyAdminCanMessage && !group.admin.includes(sender)) {
        throw new Error("Only admins can send messages");
      }
    }
    const message = await Message.create({
      chatId,
      sender,
      senderName: senderName || senderInfo.userName,
      senderPhoto: senderPhoto || senderInfo.profilePhoto,
      content,
      mediaType: mediaType || "text",
      mediaUrl,
      mediaMetadata,
      deliveredTo: [
        {
          userId: sender,
          userName: senderName || senderInfo.userName,
          profilePhoto: senderPhoto || senderInfo.profilePhoto,
          deliveredAt: new Date(),
        },
      ],
    });
    await Chat.findByIdAndUpdate(chatId, {
      lastMessage: message._id,
      $inc: { [`unreadCount.${sender}`]: 1 },
    });

    // Handle message delivery without using a message queue
    await this.handleDirectMessageDelivery(message._id, chatId, {
      userId: sender,
      userName: senderName || senderInfo.userName,
      profilePhoto: senderPhoto || senderInfo.profilePhoto,
    });

    return message;
  }

  /**
   * Handle message delivery directly instead of using a message queue
   * @param {string} messageId - Message ID
   * @param {string} chatId - Chat ID
   * @param {Object} sender - Sender information
   */
  async handleDirectMessageDelivery(messageId, chatId, sender) {
    try {
      // Get the chat to find participants
      const chat = await Chat.findById(chatId);
      if (!chat) return;

      // Get the message
      const message = await Message.findById(messageId);
      if (!message) return;

      // Implement direct delivery logic here
      // For example, update deliveredTo for all participants
      const deliveryUpdates = chat.participants
        .filter((p) => p.userId !== sender.userId) // Skip sender
        .map((p) => ({
          userId: p.userId,
          userName: p.userName,
          profilePhoto: p.profilePhoto,
          deliveredAt: new Date(),
        }));

      if (deliveryUpdates.length > 0) {
        await Message.findByIdAndUpdate(messageId, {
          $push: { deliveredTo: { $each: deliveryUpdates } },
        });
      }

      // This is where you would trigger notifications or socket events
      // to notify clients about new messages

      console.log(
        `Message ${messageId} delivered to ${deliveryUpdates.length} recipients`
      );
    } catch (error) {
      console.error("Error in direct message delivery:", error);
    }
  }

  /**
   * Mark a message as read by a user
   * @param {string} messageId - Message ID
   * @param {string} userId - User ID
   * @returns {Promise<Object>} Updated message
   */
  async markMessageAsRead(messageId, userId) {
    const message = await Message.findById(messageId);
    if (!message) {
      throw new Error("Message not found");
    }

    // Get chat to access user info
    const chat = await Chat.findById(message.chatId);
    const userInfo = chat.participants.find((p) => p.userId === userId);

    if (!userInfo) {
      throw new Error("Access denied");
    }

    if (message.readBy.some((r) => r.userId === userId)) {
      return message;
    }

    message.readBy.push({
      userId,
      userName: userInfo.userName,
      profilePhoto: userInfo.profilePhoto,
      readAt: new Date(),
    });
    await message.save();

    // Update unread count in chat
    await Chat.findByIdAndUpdate(message.chatId, {
      $inc: { [`unreadCount.${userId}`]: -1 },
    });

    return message;
  }

  /**
   * Mark multiple messages as read by a user
   * @param {string} chatId - Chat ID
   * @param {Array<string>} messageIds - Array of message IDs
   * @param {string} userId - User ID
   * @returns {Promise<Object>} Result of the operation
   */
  async markMultipleMessagesAsRead(chatId, messageIds, userId) {
    const chat = await Chat.findById(chatId);
    if (!chat) {
      throw new Error("Chat not found");
    }

    const userInfo = chat.participants.find((p) => p.userId === userId);
    if (!userInfo) {
      throw new Error("Access denied");
    }

    const result = await Message.updateMany(
      {
        _id: { $in: messageIds },
        "readBy.userId": { $ne: userId },
      },
      {
        $push: {
          readBy: {
            userId,
            userName: userInfo.userName,
            profilePhoto: userInfo.profilePhoto,
            readAt: new Date(),
          },
        },
      }
    );

    // Update unread count in chat
    await Chat.findByIdAndUpdate(chatId, {
      $inc: { [`unreadCount.${userId}`]: -result.modifiedCount },
    });

    return {
      modifiedCount: result.modifiedCount,
      messageIds,
    };
  }

  /**
   * Delete a message
   * @param {string} messageId - Message ID
   * @param {string} userId - User ID
   * @returns {Promise<Object>} Result of the operation
   */
  async deleteMessage(messageId, userId) {
    const message = await Message.findById(messageId);
    if (!message) {
      throw new Error("Message not found");
    }

    if (message.sender !== userId) {
      throw new Error("Access denied");
    }

    message.isDeleted = true;
    await message.save();

    return { success: true, message: "Message deleted successfully" };
  }

  /**
   * Get messages for a chat
   * @param {string} chatId - Chat ID
   * @param {string} userId - User ID
   * @param {number} page - Page number
   * @param {number} limit - Limit of messages per page
   * @returns {Promise<Array>} List of messages
   */
  async getChatMessages(chatId, userId, page = 1, limit = 50) {
    const chat = await Chat.findById(chatId);
    if (!chat) {
      throw new Error("Chat not found");
    }

    // Check if user is a participant
    const isParticipant = chat.participants.some((p) => p.userId === userId);
    if (!isParticipant) {
      throw new Error("Access denied");
    }

    const messages = await Message.find({
      chatId,
      isDeleted: false,
    })
      .sort({ createdAt: -1 })
      .skip((page - 1) * limit)
      .limit(limit)
      .lean();

    // Mark messages as read
    await Message.updateMany(
      {
        chatId,
        "readBy.userId": { $ne: userId },
        sender: { $ne: userId },
      },
      {
        $push: {
          readBy: {
            userId,
            readAt: new Date(),
          },
        },
      }
    );

    return messages.reverse();
  }
}

module.exports = new MessageService();
