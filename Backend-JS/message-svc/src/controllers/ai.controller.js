const AIService = require("../services/ai.service");
const AIChat = require("../models/ai-chat.model");
const MessageLimitService = require("../services/message-limit.service");
const multer = require("multer");
const upload = multer({
  limits: {
    fileSize: process.env.MAX_FILE_SIZE || 50 * 1024 * 1024,
  },
});

class AIController {
  async sendMessage(req, res) {
    try {
      const {
        userId,
        userName,
        userProfilePhoto,
        chatId,
        message,
        preferredLanguage,
        location,
        weather,
      } = req.body;

      // Check message limits
      const limitStatus = await MessageLimitService.checkAndUpdateMessageCount(
        userId
      );

      // If user has reached their limit
      if (!limitStatus.canSendMessage) {
        return res.status(429).json({
          error: "Daily message limit reached",
          limitInfo: {
            dailyLimit: MessageLimitService.FREE_DAILY_LIMIT,
            remainingMessages: 0,
            resetsAt: new Date(new Date().setHours(24, 0, 0, 0)),
          },
        });
      }

      // Add rate limit headers to response
      res.set({
        "X-RateLimit-Limit": MessageLimitService.FREE_DAILY_LIMIT,
        "X-RateLimit-Remaining":
          limitStatus.remainingMessages !== null
            ? limitStatus.remainingMessages
            : "unlimited",
        "X-RateLimit-Reset": new Date(
          new Date().setHours(24, 0, 0, 0)
        ).getTime(),
      });

      let chat;
      if (chatId) {
        chat = await AIChat.findById(chatId);
        if (!chat) {
          return res.status(404).json({ error: "Chat not found" });
        }

        // Reset daily count if it's a new day
        const today = new Date();
        today.setHours(0, 0, 0, 0);
        if (chat.dailyMessageCount.lastResetDate < today) {
          chat.dailyMessageCount = {
            count: 1,
            lastResetDate: new Date(),
          };
        }
      } else {
        // Create new chat with today's count
        chat = new AIChat({
          userId,
          userName,
          userProfilePhoto,
          metadata: {
            preferredLanguage,
            location,
            weather,
          },
          context: {
            currentTopic: "",
            lastContext: "",
            identifiedIssues: [],
            suggestedSolutions: [],
          },
          dailyMessageCount: {
            count: 1,
            lastResetDate: new Date(),
          },
        });
      }

      // Add user message to history
      const userMessage = {
        role: "user",
        content: message,
        timestamp: new Date(),
      };
      chat.messages.push(userMessage);

      try {
        // Format messages for AI context
        const formattedMessages = chat.messages.map((msg) => ({
          role: msg.role,
          content: msg.content,
        }));

        const { response: aiResponse, context: updatedContext } =
          await AIService.getChatResponse(
            formattedMessages,
            preferredLanguage,
            location,
            weather,
            chat.context
          );

        // Update chat context and save
        chat.context = updatedContext;
        const assistantMessage = {
          role: "assistant",
          content: aiResponse,
          timestamp: new Date(),
        };
        chat.messages.push(assistantMessage);
        await chat.save();

        res.json({
          chatId: chat._id,
          message: aiResponse,
          context: chat.context,
          history: chat.messages,
          limitInfo: limitStatus.isLimited
            ? {
                dailyLimit: MessageLimitService.FREE_DAILY_LIMIT,
                remainingMessages: limitStatus.remainingMessages,
                resetsAt: new Date(new Date().setHours(24, 0, 0, 0)),
              }
            : null,
        });
      } catch (error) {
        if (error.response?.status === 429) {
          const retryAfter = error.response.headers["retry-after"] || 30;
          res.status(429).json({
            error: "Rate limit exceeded",
            retryAfter: parseInt(retryAfter),
            message: "Please wait before sending another message",
          });
          return;
        }
        throw error;
      }
    } catch (error) {
      console.error("Error in sendMessage:", error);
      res.status(error.response?.status || 500).json({
        error: "Failed to process message",
        message: error.message,
        retryAfter: error.response?.headers?.["retry-after"] || 30,
      });
    }
  }

  async analyzeCropImage(req, res) {
    const uploadMiddleware = upload.single("image");

    uploadMiddleware(req, res, async (err) => {
      if (err) {
        return res.status(400).json({ error: "File upload error" });
      }

      try {
        const {
          userId,
          userName,
          userProfilePhoto,
          chatId,
          preferredLanguage,
          location,
          weather,
        } = req.body;

        if (!req.file) {
          return res.status(400).json({ error: "No image provided" });
        }

        let chat;
        if (chatId) {
          chat = await AIChat.findById(chatId);
          if (!chat) {
            return res.status(404).json({ error: "Chat not found" });
          }
        } else {
          chat = new AIChat({
            userId,
            userName,
            userProfilePhoto,
            metadata: {
              preferredLanguage,
              location,
              weather,
            },
            context: {
              currentTopic: "plant health",
              lastContext: "",
              identifiedIssues: [],
              suggestedSolutions: [],
            },
          });
        }

        // Process image with Gemini Vision
        const analysis = await AIService.processImageForCropDisease(
          req.file.buffer,
          preferredLanguage,
          location,
          weather,
          chat.context
        );

        // Add the interaction to chat history
        const userMessage = {
          role: "user",
          content: "Uploaded crop image for analysis",
          imageUrl: "image_processed",
          timestamp: new Date(),
        };
        chat.messages.push(userMessage);

        const assistantMessage = {
          role: "assistant",
          content: analysis,
          timestamp: new Date(),
        };
        chat.messages.push(assistantMessage);

        // Update context based on image analysis
        const { issues, solutions } =
          AIService._extractIssuesAndSolutions(analysis);
        chat.context.currentTopic = "plant health";
        chat.context.identifiedIssues = [
          ...new Set([...chat.context.identifiedIssues, ...issues]),
        ];
        chat.context.suggestedSolutions = [
          ...new Set([...chat.context.suggestedSolutions, ...solutions]),
        ];
        chat.context.lastContext = analysis;

        await chat.save();

        res.json({
          chatId: chat._id,
          analysis,
          context: chat.context,
          history: chat.messages,
        });
      } catch (error) {
        console.error("Error in analyzeCropImage:", error);
        res.status(500).json({ error: "Failed to analyze image" });
      }
    });
  }

  async getChatHistory(req, res) {
    try {
      const { userId } = req.query;
      const { page = 1, limit = 10 } = req.query;

      const chats = await AIChat.find({ userId, isActive: true })
        .sort({ lastMessageAt: -1 })
        .skip((page - 1) * limit)
        .limit(limit)
        .select({
          _id: 1,
          title: 1,
          lastMessageAt: 1,
          context: 1,
          "messages.content": 1,
          "messages.role": 1,
          "messages.timestamp": 1,
          "metadata.preferredLanguage": 1,
        });

      const total = await AIChat.countDocuments({ userId, isActive: true });

      // Calculate remaining daily messages
      const today = new Date();
      today.setHours(0, 0, 0, 0);

      const latestChat = await AIChat.findOne(
        { userId, "dailyMessageCount.lastResetDate": { $gte: today } },
        { dailyMessageCount: 1 }
      ).sort({ "dailyMessageCount.lastResetDate": -1 });

      const dailyCount = latestChat?.dailyMessageCount?.count || 0;
      const remainingMessages = Math.max(
        0,
        MessageLimitService.FREE_DAILY_LIMIT - dailyCount
      );

      res.json({
        chats,
        pagination: {
          total,
          page: parseInt(page),
          pages: Math.ceil(total / limit),
        },
        limitInfo: {
          dailyLimit: MessageLimitService.FREE_DAILY_LIMIT,
          remainingMessages: remainingMessages,
          resetsAt: new Date(new Date().setHours(24, 0, 0, 0)),
        },
      });
    } catch (error) {
      console.error("Error in getChatHistory:", error);
      res.status(500).json({ error: "Failed to fetch chat history" });
    }
  }

  async getChatById(req, res) {
    try {
      const { chatId } = req.params;
      const { userId } = req.query;

      const chat = await AIChat.findOne({
        _id: chatId,
        userId,
        isActive: true,
      });

      if (!chat) {
        return res.status(404).json({ error: "Chat not found" });
      }

      res.json(chat);
    } catch (error) {
      console.error("Error in getChatById:", error);
      res.status(500).json({ error: "Failed to fetch chat" });
    }
  }

  async updateChatTitle(req, res) {
    try {
      const { chatId } = req.params;
      const { userId, title } = req.body;

      const chat = await AIChat.findOne({
        _id: chatId,
        userId,
        isActive: true,
      });

      if (!chat) {
        return res.status(404).json({ error: "Chat not found" });
      }

      chat.title = title;
      await chat.save();

      res.json({ message: "Chat title updated successfully", chat });
    } catch (error) {
      console.error("Error in updateChatTitle:", error);
      res.status(500).json({ error: "Failed to update chat title" });
    }
  }

  async deleteChat(req, res) {
    try {
      const { userId } = req.query;
      const { chatId } = req.params;

      // Soft delete by setting isActive to false
      const result = await AIChat.findOneAndUpdate(
        { _id: chatId, userId },
        { isActive: false },
        { new: true }
      );

      if (!result) {
        return res.status(404).json({ error: "Chat not found" });
      }

      res.json({ message: "Chat deleted successfully" });
    } catch (error) {
      console.error("Error in deleteChat:", error);
      res.status(500).json({ error: "Failed to delete chat" });
    }
  }

  async getMessageLimitInfo(req, res) {
    try {
      const { userId } = req.query;

      // Get today's date (reset at midnight)
      const today = new Date();
      today.setHours(0, 0, 0, 0);

      // Find the latest chat with message count for today
      const latestChat = await AIChat.findOne(
        { userId, "dailyMessageCount.lastResetDate": { $gte: today } },
        { dailyMessageCount: 1 }
      ).sort({ "dailyMessageCount.lastResetDate": -1 });

      const dailyCount = latestChat?.dailyMessageCount?.count || 0;
      const remainingMessages = Math.max(
        0,
        MessageLimitService.FREE_DAILY_LIMIT - dailyCount
      );

      res.json({
        limitInfo: {
          dailyLimit: MessageLimitService.FREE_DAILY_LIMIT,
          remainingMessages: remainingMessages,
          messagesUsedToday: dailyCount,
          resetsAt: new Date(new Date().setHours(24, 0, 0, 0)),
        },
      });
    } catch (error) {
      console.error("Error fetching message limit info:", error);
      res
        .status(500)
        .json({ error: "Failed to get message limit information" });
    }
  }

  async createNewChat(req, res) {
    try {
      const { userId, userName, userProfilePhoto, preferredLanguage } =
        req.body;

      // Create a new empty chat
      const chat = new AIChat({
        userId,
        userName,
        userProfilePhoto,
        title: "New Chat",
        metadata: {
          preferredLanguage: preferredLanguage || "en",
        },
        messages: [], // Start with empty messages
        context: {
          currentTopic: "",
          lastContext: "",
          identifiedIssues: [],
          suggestedSolutions: [],
        },
        dailyMessageCount: {
          count: 0, // Will increment when first message is sent
          lastResetDate: new Date(),
        },
      });

      await chat.save();

      res.json({
        success: true,
        chatId: chat._id,
        chat,
      });
    } catch (error) {
      console.error("Error creating new chat:", error);
      res.status(500).json({ error: "Failed to create new chat" });
    }
  }
}

module.exports = new AIController();
