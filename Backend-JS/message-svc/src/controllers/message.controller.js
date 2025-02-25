const MessageService = require("../services/message.service");

class MessageController {
  async sendMessage(req, res) {
    try {
      const { userId, chatId, content, mediaType, mediaUrl } = req.body;

      const message = await MessageService.createMessage({
        chatId,
        sender: userId,
        content,
        mediaType,
        mediaUrl,
      });

      return res.status(201).json(message);
    } catch (error) {
      console.error("Send message error:", error);
      return res
        .status(500)
        .json({ error: error.message || "Internal server error" });
    }
  }

  async markMessageAsRead(req, res) {
    try {
      const { messageId } = req.params;
      const { userId } = req.body;

      const message = await MessageService.markMessageAsRead(messageId, userId);

      return res.json(message);
    } catch (error) {
      console.error("Mark message as read error:", error);
      return res
        .status(500)
        .json({ error: error.message || "Internal server error" });
    }
  }

  async deleteMessage(req, res) {
    try {
      const { messageId } = req.params;
      const { userId } = req.body;

      const result = await MessageService.deleteMessage(messageId, userId);

      return res.json(result);
    } catch (error) {
      console.error("Delete message error:", error);
      return res
        .status(500)
        .json({ error: error.message || "Internal server error" });
    }
  }

  async getChatMessages(req, res) {
    try {
      const { userId } = req.body;
      const { chatId } = req.params;
      const page = parseInt(req.query.page) || 1;
      const limit = parseInt(req.query.limit) || 50;

      const messages = await MessageService.getChatMessages(
        chatId,
        userId,
        page,
        limit
      );

      return res.json(messages);
    } catch (error) {
      console.error("Get chat messages error:", error);
      return res
        .status(500)
        .json({ error: error.message || "Internal server error" });
    }
  }
}

module.exports = new MessageController();
