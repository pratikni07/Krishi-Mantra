const AIService = require("../services/ai.service");
const AIChat = require("../models/ai-chat.model");
const MessageLimitService = require("../services/message-limit.service");

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

      // Validate input
      if (!message || !userId) {
        return res.status(400).json({
          error: "Missing required fields: userId and message are required",
        });
      }

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

        // Ensure this chat belongs to the requesting user
        if (chat.userId !== userId) {
          return res
            .status(403)
            .json({ error: "Not authorized to access this chat" });
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

      // Log the chat history for debugging
      console.log(
        `Chat history for ${chatId || "new chat"}: ${
          chat.messages.length
        } messages`
      );

      try {
        // Format messages for AI context - ensure proper history is maintained
        const formattedMessages = chat.messages.map((msg) => ({
          role: msg.role,
          content: msg.content,
        }));

        console.log(
          `Processing request with ${formattedMessages.length} messages in context`
        );

        const { response: aiResponse, context: updatedContext } =
          await AIService.getChatResponse(
            formattedMessages,
            preferredLanguage || "en",
            location || { lat: 0, lon: 0 },
            weather || { temperature: 25, humidity: 60 },
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

        // If this is a new chat, generate a title based on the conversation
        if (!chatId && chat.messages.length >= 2) {
          chat.title =
            message.length > 30 ? `${message.substring(0, 30)}...` : message;
        }

        await chat.save();

        res.json({
          chatId: chat._id,
          message: aiResponse,
          context: chat.context,
          title: chat.title,
          history: chat.messages.slice(-10), // Send only most recent messages
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
    try {
      console.log("Analyze image request received");

      // Debug info to see what's coming in the request
      console.log("Request headers:", req.headers);
      console.log("Request body fields:", Object.keys(req.body || {}));
      console.log("Files object type:", typeof req.file);
      console.log("Files in request:", req.file ? "Yes" : "No");
      if (req.file) {
        console.log("File details:", {
          fieldname: req.file.fieldname,
          originalname: req.file.originalname,
          size: req.file.size,
          mimetype: req.file.mimetype,
        });
      }

      // Validate that files were uploaded
      if (!req.file) {
        console.error("No image file in request");
        return res.status(400).json({ error: "No image provided" });
      }

      // Validate image file
      if (req.file.size === 0) {
        console.error("Empty image file uploaded");
        return res.status(400).json({ error: "Empty image file" });
      }

      if (req.file.size > 10 * 1024 * 1024) {
        console.error(`Image file too large: ${req.file.size} bytes`);
        return res
          .status(400)
          .json({ error: "Image file too large (max 10MB)" });
      }

      if (!req.file.mimetype.startsWith("image/")) {
        console.error(`Invalid file type: ${req.file.mimetype}`);
        return res
          .status(400)
          .json({ error: "Invalid file type. Only images are allowed." });
      }

      console.log(
        `Processing image: ${req.file.originalname}, size: ${req.file.size} bytes, type: ${req.file.mimetype}`
      );

      // Validate user input
      const {
        userId,
        userName,
        chatId,
        preferredLanguage = "en",
        message = "",
      } = req.body;

      if (!userId) {
        return res.status(400).json({ error: "userId is required" });
      }

      // Extract user message if provided
      const userMessage = message || "";

      // Try to parse location and weather from the request
      let location = { lat: 0, lon: 0 };
      let weather = { temperature: 25, humidity: 60 };

      try {
        if (req.body.location) {
          location =
            typeof req.body.location === "string"
              ? JSON.parse(req.body.location)
              : req.body.location;
        }

        if (req.body.weather) {
          weather =
            typeof req.body.weather === "string"
              ? JSON.parse(req.body.weather)
              : req.body.weather;
        }
      } catch (parseError) {
        console.error("Error parsing location/weather data:", parseError);
        // Continue with default values
      }

      // Get the chat history or create a new one
      let chat = null;
      if (chatId) {
        chat = await AIChat.findById(chatId);
        if (!chat) {
          return res.status(404).json({ error: "Chat not found" });
        }
      }

      // Check rate limits and daily message quota
      const { canProceed, limitInfo, errorResponse } =
        await this.checkMessageLimits(userId, "analyze-image");
      if (!canProceed) {
        return res.status(429).json(errorResponse);
      }

      // Convert image to base64
      const imageBuffer = req.file.buffer;
      const base64Image = imageBuffer.toString("base64");

      // Send to AI service for analysis
      try {
        console.log("Sending image to AI service...");
        const analysis = await AIService.processImageForCropDisease(
          base64Image,
          chatId,
          userMessage
        );

        // Create or update chat
        if (!chat) {
          const newChatTitle = `Image Analysis - ${new Date().toLocaleString()}`;
          chat = new AIChat({
            userId,
            userName,
            userProfilePhoto: req.body.userProfilePhoto || "",
            title: newChatTitle,
            metadata: {
              preferredLanguage: preferredLanguage || "en",
              location: location || { lat: 0, lon: 0 },
              weather: weather || { temperature: 25, humidity: 60 },
            },
            context: {
              currentTopic: "plant health",
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

        // Add the user message (image upload)
        const userMessageData = {
          role: "user",
          content: userMessage || "Uploaded an image for analysis",
          timestamp: new Date(),
          imageUrl: "image_upload", // Just a marker to indicate there was an image
        };

        // Add the AI response
        const aiMessageData = {
          role: "assistant",
          content: analysis,
          timestamp: new Date(),
        };

        // Update the chat with the message and response
        chat.messages.push(userMessageData);
        chat.messages.push(aiMessageData);

        // Get full updated chat history
        const updatedChat = await AIChat.findById(chat._id);
        const history = updatedChat.messages;

        // Update chat context based on the AI response
        const context = this.updateContext(
          chat.context || {},
          userMessage,
          analysis
        );
        updatedChat.context = context;
        await updatedChat.save();

        // Apply rate limit headers
        this.applyRateLimitHeaders(res, "analyze-image");

        // Return the full response
        return res.status(200).json({
          chatId: chat._id,
          analysis,
          context,
          history,
          limitInfo,
        });
      } catch (aiError) {
        console.error("AI processing error:", aiError);

        // Check for specific AI service errors
        if (aiError.message?.includes("temporarily unavailable")) {
          return res.status(503).json({
            error: "AI service temporarily unavailable",
            message:
              "The AI service is currently unavailable. Please try again later.",
            status: "error",
          });
        }

        // Rethrow to be caught by the outer catch block
        throw aiError;
      }
    } catch (error) {
      console.error("Error in analyzeCropImage:", error);

      // Check for connection reset errors
      if (
        error.code === "ECONNRESET" ||
        error.message?.includes("ECONNRESET") ||
        error.message?.includes("socket hang up") ||
        error.message?.includes("connection reset")
      ) {
        console.error("Connection reset error in image analysis:", {
          error: error.message,
          code: error.code,
          stack: error.stack?.split("\n")[0],
        });

        return res.status(502).json({
          error: "Message Service unavailable",
          message:
            "The AI service connection was reset. Please try again later.",
          status: "error",
        });
      }

      // Check for timeouts
      if (
        error.message?.includes("timeout") ||
        error.message?.includes("timed out")
      ) {
        return res.status(504).json({
          error: "Request timed out",
          message:
            "The image analysis took too long to complete. Please try again with a different image.",
          status: "error",
        });
      }

      // Handle generic errors
      return res.status(500).json({
        error: "Failed to analyze image",
        message: error.message || "Unknown error occurred",
        status: "error",
      });
    }
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

  async analyzeMultipleImages(req, res) {
    try {
      console.log("Analyze multiple images request received");

      // Debug info to see what's coming in the request
      console.log("Request headers:", req.headers);
      console.log("Request body fields:", Object.keys(req.body || {}));
      console.log(
        "Files in request:",
        req.files ? "Yes (" + req.files.length + ")" : "No"
      );

      // Check if user provided files
      if (!req.files || req.files.length === 0) {
        console.error("No images provided in request");
        return res.status(400).json({ error: "No images provided" });
      }

      // Log file details
      console.log(
        "Files details:",
        req.files.map((file) => ({
          fieldname: file.fieldname,
          originalname: file.originalname,
          size: file.size,
          mimetype: file.mimetype,
        }))
      );

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

      // ... rest of the existing code ...
    } catch (error) {
      console.error("Error in analyzeMultipleImages:", error);

      // Check for common error types
      if (
        error.code === "ECONNRESET" ||
        error.message?.includes("ECONNRESET")
      ) {
        return res.status(502).json({
          status: "error",
          message: "Message Service unavailable",
          error: "read ECONNRESET",
        });
      }

      res.status(500).json({
        status: "error",
        error: "Failed to analyze images",
        message: error.message || "Unknown error occurred",
      });
    }
  }
}

module.exports = new AIController();
