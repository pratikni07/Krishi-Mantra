const Chat = require("../models/chat.model");
const User = require("../models/user.model");
const MessageService = require("../services/message.service");

class ChatController {
  async createDirectChat(req, res) {
    try {
      const {
        participantId,
        userId,
        userName,
        participantName,
        profilePhoto,
        participantProfilePhoto,
      } = req.body;

      // Check if chat already exists
      const existingChat = await Chat.findOne({
        type: "direct",
        "participants.userId": { $all: [userId, participantId] },
      });

      if (existingChat) {
        return res.json(existingChat);
      }

      const chat = await Chat.create({
        type: "direct",
        participants: [
          {
            userId,
            userName,
            profilePhoto,
          },
          {
            userId: participantId,
            userName: participantName,
            profilePhoto: participantProfilePhoto,
          },
        ],
      });

      return res.status(201).json(chat);
    } catch (error) {
      console.error("Create direct chat error:", error);
      return res.status(500).json({ error: "Internal server error" });
    }
  }

  async getUserChats(req, res) {
    try {
      const { userId } = req.body;
      const page = parseInt(req.query.page) || 1;
      const limit = parseInt(req.query.limit) || 20;

      const chats = await Chat.aggregate([
        {
          $match: {
            "participants.userId": userId,
          },
        },
        {
          $lookup: {
            from: "messages",
            localField: "lastMessage",
            foreignField: "_id",
            as: "lastMessageDetails",
          },
        },
        {
          $lookup: {
            from: "groups",
            localField: "_id",
            foreignField: "chatId",
            as: "groupDetails",
          },
        },
        {
          $addFields: {
            otherParticipants: {
              $filter: {
                input: "$participants",
                as: "participant",
                cond: { $ne: ["$$participant.userId", userId] },
              },
            },
          },
        },
        {
          $sort: { "lastMessageDetails.createdAt": -1 },
        },
        {
          $skip: (page - 1) * limit,
        },
        {
          $limit: limit,
        },
      ]);

      return res.json(chats);
    } catch (error) {
      console.error("Get user chats error:", error);
      return res.status(500).json({ error: "Internal server error" });
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

module.exports = new ChatController();
