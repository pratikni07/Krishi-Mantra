const AIChat = require("../models/ai-chat.model");
const AIService = require("./ai.service");
const MessageLimitService = require("./message-limit.service");

class AISocketService {
  constructor(io, userSocketMap) {
    this.io = io;
    this.userSocketMap = userSocketMap;
    this.setupAIChatHandlers();
  }

  setupAIChatHandlers() {
    this.io.on("connection", (socket) => {
      // Join AI chat rooms
      this.handleAIChatRooms(socket);

      // Handle AI chat messages
      this.setupAIMessageHandlers(socket);

      // Handle AI image analysis
      this.setupAIImageHandlers(socket);

      // Handle typing indicators for AI chat
      this.setupAITypingHandlers(socket);

      // Handle new chat creation
      this.setupNewChatHandler(socket);
    });
  }

  async handleAIChatRooms(socket) {
    try {
      // Join user's AI chat rooms
      const aiChats = await AIChat.find({
        userId: socket.userId,
        isActive: true,
      });

      aiChats.forEach((chat) => {
        socket.join(`ai-chat-${chat._id.toString()}`);
      });

      // Send message limit info
      this.sendMessageLimitInfo(socket);
    } catch (error) {
      console.error("AI chat room setup error:", error);
    }
  }

  async sendMessageLimitInfo(socket) {
    try {
      const today = new Date();
      today.setHours(0, 0, 0, 0);

      const latestChat = await AIChat.findOne(
        {
          userId: socket.userId,
          "dailyMessageCount.lastResetDate": { $gte: today },
        },
        { dailyMessageCount: 1 }
      ).sort({ "dailyMessageCount.lastResetDate": -1 });

      const dailyCount = latestChat?.dailyMessageCount?.count || 0;
      const remainingMessages = Math.max(
        0,
        MessageLimitService.FREE_DAILY_LIMIT - dailyCount
      );

      socket.emit("ai:limit:info", {
        dailyLimit: MessageLimitService.FREE_DAILY_LIMIT,
        remainingMessages: remainingMessages,
        messagesUsedToday: dailyCount,
        resetsAt: new Date(new Date().setHours(24, 0, 0, 0)),
      });
    } catch (error) {
      console.error("Error sending message limit info:", error);
    }
  }

  setupAIMessageHandlers(socket) {
    socket.on("ai:message:send", async (data) => {
      try {
        const { chatId, message, preferredLanguage, location, weather } = data;

        // Check message limits
        const limitStatus =
          await MessageLimitService.checkAndUpdateMessageCount(socket.userId);

        // If user has reached their limit
        if (!limitStatus.canSendMessage) {
          socket.emit("ai:limit:reached", {
            dailyLimit: MessageLimitService.FREE_DAILY_LIMIT,
            remainingMessages: 0,
            resetsAt: new Date(new Date().setHours(24, 0, 0, 0)),
          });
          return;
        }

        let chat = await AIChat.findById(chatId);
        if (!chat) {
          socket.emit("error", { message: "Chat not found" });
          return;
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

        // Add user message to history
        const userMessage = {
          role: "user",
          content: message,
          timestamp: new Date(),
        };
        chat.messages.push(userMessage);

        // Emit typing indicator
        this.io.to(`ai-chat-${chatId}`).emit("ai:typing", {
          chatId,
          isTyping: true,
        });

        // Format messages for AI context
        const formattedMessages = chat.messages.map((msg) => ({
          role: msg.role,
          content: msg.content,
        }));

        // Get AI response using complete chat history
        const { response, context } = await AIService.getChatResponse(
          formattedMessages,
          preferredLanguage,
          location,
          weather,
          chat.context
        );

        // Update chat context
        chat.context = context;

        // Add AI response to history
        const assistantMessage = {
          role: "assistant",
          content: response,
          timestamp: new Date(),
        };
        chat.messages.push(assistantMessage);

        await chat.save();

        // Stop typing indicator
        this.io.to(`ai-chat-${chatId}`).emit("ai:typing", {
          chatId,
          isTyping: false,
        });

        // Emit the message to all users in the chat room
        this.io.to(`ai-chat-${chatId}`).emit("ai:message:received", {
          chatId,
          messages: [userMessage, assistantMessage],
          timestamp: new Date(),
          limitInfo: limitStatus.isLimited
            ? {
                dailyLimit: MessageLimitService.FREE_DAILY_LIMIT,
                remainingMessages: limitStatus.remainingMessages,
                resetsAt: new Date(new Date().setHours(24, 0, 0, 0)),
              }
            : null,
        });

        // Update message limit info
        this.sendMessageLimitInfo(socket);
      } catch (error) {
        console.error("AI message send error:", error);
        socket.emit("error", { message: "Failed to process AI message" });
      }
    });
  }

  setupAIImageHandlers(socket) {
    socket.on("ai:image:analyze", async (data) => {
      try {
        const { chatId, imageBuffer, preferredLanguage, location, weather } =
          data;

        // Check message limits (image analysis counts as a message)
        const limitStatus =
          await MessageLimitService.checkAndUpdateMessageCount(socket.userId);

        // If user has reached their limit
        if (!limitStatus.canSendMessage) {
          socket.emit("ai:limit:reached", {
            dailyLimit: MessageLimitService.FREE_DAILY_LIMIT,
            remainingMessages: 0,
            resetsAt: new Date(new Date().setHours(24, 0, 0, 0)),
          });
          return;
        }

        let chat = await AIChat.findById(chatId);
        if (!chat) {
          socket.emit("error", { message: "Chat not found" });
          return;
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

        // Emit analyzing status
        this.io.to(`ai-chat-${chatId}`).emit("ai:analyzing", {
          chatId,
          isAnalyzing: true,
        });

        // Process image
        const analysis = await AIService.processImageForCropDisease(
          imageBuffer,
          preferredLanguage,
          location,
          weather,
          chat.context
        );

        // Add messages to history
        const userMessage = {
          role: "user",
          content: "Uploaded crop image for analysis",
          imageUrl: "image_processed",
          timestamp: new Date(),
        };

        const assistantMessage = {
          role: "assistant",
          content: analysis,
          timestamp: new Date(),
        };

        chat.messages.push(userMessage, assistantMessage);

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

        // Stop analyzing status
        this.io.to(`ai-chat-${chatId}`).emit("ai:analyzing", {
          chatId,
          isAnalyzing: false,
        });

        // Emit the analysis result
        this.io.to(`ai-chat-${chatId}`).emit("ai:image:analyzed", {
          chatId,
          messages: [userMessage, assistantMessage],
          timestamp: new Date(),
          limitInfo: limitStatus.isLimited
            ? {
                dailyLimit: MessageLimitService.FREE_DAILY_LIMIT,
                remainingMessages: limitStatus.remainingMessages,
                resetsAt: new Date(new Date().setHours(24, 0, 0, 0)),
              }
            : null,
        });

        // Update message limit info
        this.sendMessageLimitInfo(socket);
      } catch (error) {
        console.error("AI image analysis error:", error);
        socket.emit("error", { message: "Failed to analyze image" });
      }
    });
  }

  setupAITypingHandlers(socket) {
    socket.on("ai:typing:start", async (data) => {
      const { chatId } = data;
      this.io.to(`ai-chat-${chatId}`).emit("ai:typing", {
        chatId,
        isTyping: true,
      });
    });

    socket.on("ai:typing:stop", async (data) => {
      const { chatId } = data;
      this.io.to(`ai-chat-${chatId}`).emit("ai:typing", {
        chatId,
        isTyping: false,
      });
    });
  }

  setupNewChatHandler(socket) {
    socket.on("ai:chat:new", async (data) => {
      try {
        const { userName, userProfilePhoto, preferredLanguage } = data;

        // Create a new chat
        const chat = new AIChat({
          userId: socket.userId,
          userName: userName,
          userProfilePhoto: userProfilePhoto,
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

        // Join the new chat room
        socket.join(`ai-chat-${chat._id.toString()}`);

        // Notify client about new chat
        socket.emit("ai:chat:created", {
          chatId: chat._id,
          chat: chat,
        });
      } catch (error) {
        console.error("Error creating new chat:", error);
        socket.emit("error", { message: "Failed to create new chat" });
      }
    });
  }
}

module.exports = AISocketService;
