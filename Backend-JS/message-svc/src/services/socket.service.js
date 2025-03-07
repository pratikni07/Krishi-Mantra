const { Server } = require("socket.io");
const Redis = require("../config/redis");
const Chat = require("../models/chat.model");
const Group = require("../models/group.model");
const User = require("../models/user.model");
const MessageService = require("../services/message.service");
const AISocketService = require("./ai-socket.service");
const { DataExchange } = require("aws-sdk");

class SocketService {
  constructor(server) {
    this.io = new Server(server, {
      pingTimeout: parseInt(process.env.SOCKET_PING_TIMEOUT) || 60000,
      pingInterval: parseInt(process.env.SOCKET_PING_INTERVAL) || 25000,
      cors: {
        origin: process.env.ALLOWED_ORIGINS?.split(",") || "*",
        methods: ["GET", "POST"],
        credentials: true,
      },
      maxHttpBufferSize: 1e7,
    });

    this.userSocketMap = new Map();
    this.initialize();

    // Initialize AI Socket Service
    this.aiSocketService = new AISocketService(this.io, this.userSocketMap);
  }

  initialize() {
    this.io.use(async (socket, next) => {
      try {
        const userId = socket.handshake.auth.userId;
        if (!userId) {
          return next(new Error("Authentication required"));
        }

        socket.userId = userId;
        next();
      } catch (error) {
        next(new Error("Authentication failed"));
      }
    });

    this.io.on("connection", (socket) => {
      console.log(`User connected: ${socket.userId}`);
      this.handleConnection(socket);
    });
  }

  async handleConnection(socket) {
    try {
      // Store socket mapping
      this.userSocketMap.set(socket.userId, socket.id);
      await Redis.hset("online_users", socket.userId, socket.id);

      // Update user status
      await User.findOneAndUpdate(
        { userId: socket.userId },
        {
          isOnline: true,
          lastSeen: new Date(),
        }
      );

      // Broadcast user online status
      this.broadcastUserStatus(socket.userId, true);

      // Join user's chat rooms
      const chats = await Chat.find({
        "participants.userId": socket.userId,
      });

      chats.forEach((chat) => {
        socket.join(chat._id.toString());
      });

      // Event Handlers
      this.setupChatHandlers(socket);
      this.setupMessageHandlers(socket);
      this.setupTypingHandlers(socket);
      this.setupPresenceHandlers(socket);
      this.setupGroupHandlers(socket);

      // Handle disconnection
      socket.on("disconnect", () => this.handleDisconnection(socket));
    } catch (error) {
      console.error("Socket connection error:", error);
    }
  }

  setupChatHandlers(socket) {
    // Create new direct chat
    socket.on("chat:create:direct", async (data) => {
      try {
        const { participantId, userId } = data;
        const existingChat = await Chat.findOne({
          type: "direct",
          "participants.userId": { $all: [userId, participantId] },
        });

        if (existingChat) {
          socket.emit("chat:create:response", existingChat);
          return;
        }

        const chat = await Chat.create({
          type: "direct",
          participants: [
            {
              userId,
              userName: data.userName,
              profilePhoto: data.profilePhoto,
            },
            {
              userId: participantId,
              userName: data.participantName,
              profilePhoto: data.participantProfilePhoto,
            },
          ],
        });

        // Notify participants about new chat
        const participantSocket = this.userSocketMap.get(participantId);
        if (participantSocket) {
          this.io.to(participantSocket).emit("chat:new", chat);
        }

        socket.emit("chat:create:response", chat);
      } catch (error) {
        console.error("Direct chat creation error:", error);
        socket.emit("error", { message: "Failed to create chat" });
      }
    });
  }

  setupMessageHandlers(socket) {
    socket.on("message:send", async (data) => {
      try {
        const { chatId, content, mediaType, mediaUrl } = data;
        console.log(data);

        // Get chat to access sender info
        const chat = await Chat.findById(chatId);
        if (!chat) {
          socket.emit("error", { message: "Chat not found" });
          return;
        }

        // Get sender info from chat participants
        const senderInfo = chat.participants.find(
          (p) => p.userId === socket.userId
        );
        if (!senderInfo) {
          socket.emit("error", { message: "Not a chat participant" });
          return;
        }
        const newMessage = await MessageService.createMessage({
          chatId,
          sender: socket.userId,
          senderName: senderInfo.userName,
          senderPhoto: senderInfo.profilePhoto,
          content,
          mediaType,
          mediaUrl,
        });

        // Emit to all users in chat room
        this.io.to(chatId).emit("message:received", {
          ...newMessage.toObject(),
          timestamp: newMessage.createdAt,
        });

        // Handle delivery status for online participants
        const onlineParticipants = chat.participants
          .filter(
            (p) =>
              p.userId !== socket.userId && this.userSocketMap.has(p.userId)
          )
          .map((p) => p.userId);

        // Send delivery status to online participants
        onlineParticipants.forEach((userId) => {
          const recipientSocket = this.userSocketMap.get(userId);
          if (recipientSocket) {
            this.io.to(recipientSocket).emit("message:delivered", {
              messageId: newMessage._id,
              chatId,
              timestamp: new Date(),
            });
          }
        });
      } catch (error) {
        console.error("Message send error:", error);
        socket.emit("error", {
          message: error.message || "Failed to send message",
        });
      }
    });

    // Message read receipt
    socket.on("message:read", async (data) => {
      try {
        const { chatId, messageIds } = data;
        console.log(DataExchange);

        const result = await MessageService.markMultipleMessagesAsRead(
          chatId,
          messageIds,
          socket.userId
        );

        this.io.to(chatId).emit("message:read:update", {
          userId: socket.userId,
          messageIds: result.messageIds, // Array of IDs
          timestamp: new Date(),
        });
      } catch (error) {
        console.error("Message read error:", error);
        socket.emit("error", {
          message: error.message || "Failed to mark messages as read",
        });
      }
    });
  }

  setupTypingHandlers(socket) {
    socket.on("typing:start", async (data) => {
      const { chatId } = data;
      socket.to(chatId).emit("typing:update", {
        userId: socket.userId,
        isTyping: true,
      });
    });

    socket.on("typing:stop", async (data) => {
      const { chatId } = data;
      socket.to(chatId).emit("typing:update", {
        userId: socket.userId,
        isTyping: false,
      });
    });
  }

  setupGroupHandlers(socket) {
    // Create group chat
    socket.on("group:create", async (data) => {
      try {
        const { name, description, participants, adminId } = data;
        const group = await Group.create({
          name,
          description,
          admin: [adminId],
          memberCount: participants.length,
        });

        const chat = await Chat.create({
          type: "group",
          participants: participants.map((p) => ({
            userId: p.userId,
            userName: p.userName,
            profilePhoto: p.profilePhoto,
          })),
        });

        group.chatId = chat._id;
        await group.save();

        // Notify group participants
        participants.forEach((participant) => {
          const participantSocket = this.userSocketMap.get(participant.userId);
          if (participantSocket) {
            this.io.to(participantSocket).emit("group:new", { group, chat });
          }
        });
      } catch (error) {
        console.error("Group creation error:", error);
        socket.emit("error", { message: "Failed to create group" });
      }
    });

    // Add group participants
    socket.on("group:add_participants", async (data) => {
      try {
        const { groupId, participants } = data;
        const group = await Group.findById(groupId);
        const chat = await Chat.findById(group.chatId);

        participants.forEach((participant) => {
          chat.participants.push({
            userId: participant.userId,
            userName: participant.userName,
            profilePhoto: participant.profilePhoto,
          });

          const participantSocket = this.userSocketMap.get(participant.userId);
          if (participantSocket) {
            this.io.to(participantSocket).emit("group:added", { group, chat });
          }
        });

        await chat.save();
        group.memberCount += participants.length;
        await group.save();

        this.io.to(chat._id.toString()).emit("group:participants_updated", {
          groupId,
          participants,
        });
      } catch (error) {
        console.error("Add participants error:", error);
        socket.emit("error", { message: "Failed to add participants" });
      }
    });
  }

  setupPresenceHandlers(socket) {
    socket.on("presence:update", async (data) => {
      try {
        const { status } = data;
        await User.findOneAndUpdate(
          { userId: socket.userId },
          {
            status,
            lastSeen: new Date(),
          }
        );

        this.broadcastUserStatus(socket.userId, status === "online");
      } catch (error) {
        console.error("Presence update error:", error);
      }
    });
  }

  async handleDisconnection(socket) {
    try {
      console.log(`User disconnected: ${socket.userId}`);

      await User.findOneAndUpdate(
        { userId: socket.userId },
        {
          isOnline: false,
          lastSeen: new Date(),
        }
      );

      this.userSocketMap.delete(socket.userId);
      await Redis.hDel("online_users", socket.userId);

      this.broadcastUserStatus(socket.userId, false);
    } catch (error) {
      console.error("Disconnection handler error:", error);
    }
  }

  async broadcastUserStatus(userId, isOnline) {
    try {
      const user = await User.findOne({ userId });
      if (!user) return;

      const chats = await Chat.find({
        "participants.userId": userId,
      });

      chats.forEach((chat) => {
        this.io.to(chat._id.toString()).emit("user:status", {
          userId,
          isOnline,
          lastSeen: new Date(),
        });
      });
    } catch (error) {
      console.error("Broadcast user status error:", error);
    }
  }
}

module.exports = SocketService;
