const { Server } = require("socket.io");
const Redis = require("../config/redis");
const Chat = require("../models/chat.model");
const Group = require("../models/group.model");
const User = require("../models/user.model");
const MessageService = require("../services/message.service");
const AISocketService = require("./ai-socket.service");
const { SOCKET_CONFIG, RATE_LIMITS } = require('../utils/constants');

/**
 * Socket.IO service optimized for 10k concurrent connections
 */
class SocketService {
  constructor(server) {
    this.io = new Server(server, {
      pingTimeout: SOCKET_CONFIG.PING_TIMEOUT,
      pingInterval: SOCKET_CONFIG.PING_INTERVAL,
      cors: {
        origin: process.env.ALLOWED_ORIGINS?.split(",") || "*",
        methods: ["GET", "POST"],
        credentials: true,
      },
      maxHttpBufferSize: SOCKET_CONFIG.MAX_HTTP_BUFFER_SIZE,
      // Performance optimizations for 10k connections
      perMessageDeflate: {
        threshold: 1024, // Only compress messages > 1KB
      },
      transports: ['websocket', 'polling'],
      allowUpgrades: true,
    });

    // Map of userId -> Set of socketIds (allow multiple connections per user)
    this.userSocketMap = new Map();
    // Rate limiting map: socketId -> { eventCount, lastReset }
    this.rateLimitMap = new Map();
    // Connection count per user
    this.userConnectionCount = new Map();

    this.initialize();
    this.aiSocketService = new AISocketService(this.io, this.userSocketMap);

    // Cleanup interval for stale rate limit entries
    this.cleanupInterval = setInterval(() => this.cleanupRateLimits(), 60000);
  }

  /**
   * Get service statistics for health check
   */
  getStats() {
    return {
      connections: this.io.engine?.clientsCount || 0,
      uniqueUsers: this.userSocketMap.size,
      rooms: this.io.sockets?.adapter?.rooms?.size || 0,
    };
  }

  initialize() {
    this.io.use(async (socket, next) => {
      try {
        const userId = socket.handshake.auth.userId;
        if (!userId) {
          return next(new Error("Authentication required"));
        }

        // Check connection limit per user
        const currentConnections = this.userConnectionCount.get(userId) || 0;
        if (currentConnections >= SOCKET_CONFIG.MAX_CONNECTIONS_PER_USER) {
          return next(new Error("Maximum connections exceeded"));
        }

        socket.userId = userId;
        next();
      } catch (error) {
        next(new Error("Authentication failed"));
      }
    });

    this.io.on("connection", (socket) => {
      console.log(`User connected: ${socket.userId}, socket: ${socket.id}`);
      this.handleConnection(socket);
    });
  }

  /**
   * Check and enforce rate limiting for socket events
   */
  checkRateLimit(socketId) {
    const now = Date.now();
    let limitData = this.rateLimitMap.get(socketId);

    if (!limitData || now - limitData.lastReset > 1000) {
      // Reset every second
      limitData = { eventCount: 0, lastReset: now };
    }

    limitData.eventCount++;
    this.rateLimitMap.set(socketId, limitData);

    return limitData.eventCount <= RATE_LIMITS.SOCKET_EVENTS_PER_SECOND;
  }

  /**
   * Cleanup stale rate limit entries
   */
  cleanupRateLimits() {
    const now = Date.now();
    for (const [socketId, data] of this.rateLimitMap.entries()) {
      if (now - data.lastReset > 60000) {
        this.rateLimitMap.delete(socketId);
      }
    }
  }

  async handleConnection(socket) {
    try {
      // Track user's sockets (allow multiple connections)
      if (!this.userSocketMap.has(socket.userId)) {
        this.userSocketMap.set(socket.userId, new Set());
      }
      this.userSocketMap.get(socket.userId).add(socket.id);

      // Update connection count
      const currentCount = this.userConnectionCount.get(socket.userId) || 0;
      this.userConnectionCount.set(socket.userId, currentCount + 1);

      // Store in Redis for distributed tracking
      await Redis.hset("online_users", socket.userId, socket.id);

      // Update user status in database (rate-limited to prevent excessive writes)
      await User.touchLastActive(socket.userId);

      // Broadcast user online status
      this.broadcastUserStatus(socket.userId, true);

      // Join user's chat rooms efficiently
      const chats = await Chat.find({
        "participants.userId": socket.userId,
      }).select('_id').lean();

      const roomIds = chats.map(chat => chat._id.toString());
      if (roomIds.length > 0) {
        socket.join(roomIds);
      }

      // Event Handlers with rate limiting wrapper
      this.setupChatHandlers(socket);
      this.setupMessageHandlers(socket);
      this.setupTypingHandlers(socket);
      this.setupPresenceHandlers(socket);
      this.setupGroupHandlers(socket);

      // Handle disconnection
      socket.on("disconnect", (reason) => this.handleDisconnection(socket, reason));

      // Handle errors
      socket.on("error", (error) => {
        console.error(`Socket error for user ${socket.userId}:`, error.message);
      });
    } catch (error) {
      console.error("Socket connection error:", error);
      socket.disconnect(true);
    }
  }

  /**
   * Wrap event handler with rate limiting
   */
  withRateLimit(socket, handler) {
    return async (...args) => {
      if (!this.checkRateLimit(socket.id)) {
        socket.emit("error", { message: "Rate limit exceeded. Please slow down." });
        return;
      }
      try {
        await handler(...args);
      } catch (error) {
        console.error(`Handler error for ${socket.userId}:`, error.message);
        socket.emit("error", { message: error.message || "Operation failed" });
      }
    };
  }

  setupChatHandlers(socket) {
    // Create new direct chat
    socket.on("chat:create:direct", this.withRateLimit(socket, async (data) => {
      const { participantId, userId } = data;

      // Use static method for efficient lookup
      const existingChat = await Chat.findDirectChat(userId, participantId);
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
      this.emitToUser(participantId, "chat:new", chat);
      socket.emit("chat:create:response", chat);

      // Join the new chat room
      socket.join(chat._id.toString());
    }));
  }

  setupMessageHandlers(socket) {
    socket.on("message:send", this.withRateLimit(socket, async (data) => {
      const { chatId, content, mediaType, mediaUrl, mediaMetadata } = data;

      const chat = await Chat.findById(chatId).lean();
      if (!chat) {
        socket.emit("error", { message: "Chat not found" });
        return;
      }

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
        mediaMetadata,
      });

      // Emit to all users in chat room
      this.io.to(chatId).emit("message:received", {
        ...newMessage.toObject(),
        timestamp: newMessage.createdAt,
      });

      // Update last message in chat
      await Chat.updateLastMessage(chatId, newMessage._id);

      // Handle delivery status for online participants
      const onlineParticipants = chat.participants
        .filter(
          (p) =>
            p.userId !== socket.userId && this.userSocketMap.has(p.userId)
        )
        .map((p) => p.userId);

      // Send delivery status to online participants
      onlineParticipants.forEach((userId) => {
        this.emitToUser(userId, "message:delivered", {
          messageId: newMessage._id,
          chatId,
          timestamp: new Date(),
        });
      });
    }));

    // Message read receipt
    socket.on("message:read", this.withRateLimit(socket, async (data) => {
      const { chatId, messageIds } = data;

      const result = await MessageService.markMultipleMessagesAsRead(
        chatId,
        messageIds,
        socket.userId
      );

      this.io.to(chatId).emit("message:read:update", {
        userId: socket.userId,
        messageIds: result.messageIds,
        timestamp: new Date(),
      });
    }));
  }

  setupTypingHandlers(socket) {
    // Debounce typing events per chat
    const typingDebounce = new Map();

    socket.on("typing:start", (data) => {
      const { chatId } = data;
      const key = `${socket.userId}:${chatId}`;

      // Debounce: only emit if not already typing in this chat
      if (!typingDebounce.has(key)) {
        socket.to(chatId).emit("typing:update", {
          userId: socket.userId,
          isTyping: true,
        });
        typingDebounce.set(key, true);

        // Auto-clear typing status after 5 seconds
        setTimeout(() => {
          typingDebounce.delete(key);
        }, 5000);
      }
    });

    socket.on("typing:stop", (data) => {
      const { chatId } = data;
      const key = `${socket.userId}:${chatId}`;
      typingDebounce.delete(key);

      socket.to(chatId).emit("typing:update", {
        userId: socket.userId,
        isTyping: false,
      });
    });
  }

  setupGroupHandlers(socket) {
    // Create group chat
    socket.on("group:create", this.withRateLimit(socket, async (data) => {
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

      // Notify all participants
      participants.forEach((participant) => {
        this.emitToUser(participant.userId, "group:new", { group, chat });
      });

      // Creator joins the chat room
      socket.join(chat._id.toString());
    }));

    // Add group participants
    socket.on("group:add_participants", this.withRateLimit(socket, async (data) => {
      const { groupId, participants } = data;
      const group = await Group.findById(groupId);
      if (!group) {
        socket.emit("error", { message: "Group not found" });
        return;
      }

      const chat = await Chat.findById(group.chatId);
      if (!chat) {
        socket.emit("error", { message: "Chat not found" });
        return;
      }

      participants.forEach((participant) => {
        chat.participants.push({
          userId: participant.userId,
          userName: participant.userName,
          profilePhoto: participant.profilePhoto,
        });

        this.emitToUser(participant.userId, "group:added", { group: group.toObject(), chat: chat.toObject() });
      });

      await chat.save();
      group.memberCount = (group.memberCount || 0) + participants.length;
      await group.save();

      this.io.to(chat._id.toString()).emit("group:participants_updated", {
        groupId,
        participants,
      });
    }));
  }

  setupPresenceHandlers(socket) {
    socket.on("presence:update", this.withRateLimit(socket, async (data) => {
      const { status } = data;

      // Rate-limited update
      await User.findOneAndUpdate(
        { userId: socket.userId },
        {
          status,
          lastSeen: new Date(),
        }
      );

      this.broadcastUserStatus(socket.userId, status === "online");
    }));
  }

  async handleDisconnection(socket, reason) {
    try {
      console.log(`User disconnected: ${socket.userId}, reason: ${reason}`);

      // Remove this socket from user's socket set
      const userSockets = this.userSocketMap.get(socket.userId);
      if (userSockets) {
        userSockets.delete(socket.id);
        if (userSockets.size === 0) {
          this.userSocketMap.delete(socket.userId);
          // Only update offline status if no more connections
          await User.findOneAndUpdate(
            { userId: socket.userId },
            {
              isOnline: false,
              lastSeen: new Date(),
            }
          );
          await Redis.hDel("online_users", socket.userId);
          this.broadcastUserStatus(socket.userId, false);
        }
      }

      // Update connection count
      const currentCount = this.userConnectionCount.get(socket.userId) || 1;
      if (currentCount <= 1) {
        this.userConnectionCount.delete(socket.userId);
      } else {
        this.userConnectionCount.set(socket.userId, currentCount - 1);
      }

      // Cleanup rate limit entry
      this.rateLimitMap.delete(socket.id);
    } catch (error) {
      console.error("Disconnection handler error:", error);
    }
  }

  /**
   * Emit to all sockets of a specific user
   */
  emitToUser(userId, event, data) {
    const userSockets = this.userSocketMap.get(userId);
    if (userSockets && userSockets.size > 0) {
      userSockets.forEach(socketId => {
        this.io.to(socketId).emit(event, data);
      });
    }
  }

  async broadcastUserStatus(userId, isOnline) {
    try {
      // Get user's chats efficiently
      const chats = await Chat.find({
        "participants.userId": userId,
      }).select('_id').lean();

      if (chats.length === 0) return;

      const statusUpdate = {
        userId,
        isOnline,
        lastSeen: new Date(),
      };

      // Broadcast to all chat rooms
      chats.forEach((chat) => {
        this.io.to(chat._id.toString()).emit("user:status", statusUpdate);
      });
    } catch (error) {
      console.error("Broadcast user status error:", error);
    }
  }

  /**
   * Cleanup on service shutdown
   */
  async shutdown() {
    clearInterval(this.cleanupInterval);
    this.io.disconnectSockets(true);
  }
}

module.exports = SocketService;
