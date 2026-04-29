const { Server } = require("socket.io");
const jwt = require("jsonwebtoken");
const Redis = require("../config/redis");
const Chat = require("../models/chat.model");
const Group = require("../models/group.model");
const User = require("../models/user.model");
const MessageService = require("../services/message.service");
const AISocketService = require("./ai-socket.service");
const { SOCKET_CONFIG, RATE_LIMITS } = require('../utils/constants');
const chatRoomCache = require("../utils/chatRoomCache");

const extractHandshakeToken = (handshake) => {
  if (handshake?.auth?.token) return handshake.auth.token;
  const authHeader = handshake?.headers?.authorization;
  if (authHeader && authHeader.startsWith("Bearer ")) {
    return authHeader.substring(7);
  }
  if (handshake?.query?.token) return handshake.query.token;
  return null;
};

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
        const token = extractHandshakeToken(socket.handshake);
        if (!token) {
          return next(new Error("Authentication required"));
        }

        const secret = process.env.JWT_SECRET;
        if (!secret) {
          console.error("JWT_SECRET not configured in message-svc");
          return next(new Error("Server auth not configured"));
        }

        let decoded;
        try {
          decoded = jwt.verify(token, secret);
        } catch (err) {
          return next(
            new Error(
              err.name === "TokenExpiredError"
                ? "Token expired"
                : "Invalid token"
            )
          );
        }

        const userId = decoded._id || decoded.id || decoded.userId;
        if (!userId) {
          return next(new Error("Token missing user identifier"));
        }

        // If the client sent an auth.userId, it must match the verified
        // JWT claim — otherwise reject to surface client bugs loudly
        // rather than silently trusting the token.
        const claimed = socket.handshake.auth?.userId;
        if (claimed && String(claimed) !== String(userId)) {
          return next(new Error("Token does not match userId"));
        }

        const currentConnections = this.userConnectionCount.get(userId) || 0;
        if (currentConnections >= SOCKET_CONFIG.MAX_CONNECTIONS_PER_USER) {
          return next(new Error("Maximum connections exceeded"));
        }

        socket.userId = String(userId);
        socket.accountType = decoded.accountType;
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

      // Join user's chat rooms. Cached in Redis with a short TTL so a burst
      // of reconnects (app resume, flaky network) doesn't hit Mongo per
      // connection. Mutating flows (new chat, group add) invalidate the
      // cache for the affected users.
      const roomIds = await chatRoomCache.loadUserChatIds(socket.userId);
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
    // Create new direct chat. Race-free upsert keyed on the canonical
    // participant pair — two simultaneous `chat:create:direct` calls
    // (e.g. user A and user B both tapping "message" at the same time)
    // converge on a single Chat document instead of producing two.
    socket.on("chat:create:direct", this.withRateLimit(socket, async (data) => {
      const { participantId, userId } = data;
      const directChatKey = Chat.buildDirectKey(userId, participantId);

      // findOneAndUpdate with upsert is the atomic primitive: if a chat
      // with this directChatKey already exists, return it; otherwise
      // insert and return the new one. The unique partial index is the
      // safety net — a concurrent insert that loses the race surfaces
      // here as a duplicate-key error and we just refetch.
      let chat;
      let isNew = false;
      try {
        const result = await Chat.findOneAndUpdate(
          { type: 'direct', directChatKey },
          {
            $setOnInsert: {
              type: 'direct',
              directChatKey,
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
            },
          },
          { new: true, upsert: true, setDefaultsOnInsert: true, rawResult: true }
        );
        chat = result.value;
        isNew = !result.lastErrorObject?.updatedExisting;
      } catch (err) {
        if (err && err.code === 11000) {
          chat = await Chat.findOne({ type: 'direct', directChatKey });
        } else {
          throw err;
        }
      }

      socket.emit("chat:create:response", chat);

      // Backfill directChatKey for legacy rows that pre-date this field —
      // protects the unique index from a future second-write doubling up.
      if (chat && !chat.directChatKey) {
        await Chat.updateOne({ _id: chat._id }, { $set: { directChatKey } }).catch(() => {});
      }

      if (isNew) {
        // Drop cached chat-room lists for both sides so their next reconnect
        // picks up this chat without waiting for the TTL.
        await chatRoomCache.invalidate([userId, participantId]);
        // Notify the other participant about the new chat
        this.emitToUser(participantId, "chat:new", chat);
        // Join the new chat room
        socket.join(chat._id.toString());
      }
    }));
  }

  setupMessageHandlers(socket) {
    socket.on("message:send", this.withRateLimit(socket, async (data) => {
      const { chatId, content, mediaType, mediaUrl, mediaMetadata, clientMessageId } = data;

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
        clientMessageId,
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

      // Per-message read receipts to the chat room — peers' bubbles flip
      // to "read", and the user's own other devices that have the chat
      // open get the message-level update too.
      this.io.to(chatId).emit("message:read:update", {
        userId: socket.userId,
        messageIds: result.messageIds,
        timestamp: new Date(),
      });

      // Cross-device chat-list sync. The chat-list screen on a sibling
      // device is unlikely to have the chat room open, so the room
      // broadcast above doesn't reach it. Push a separate user-scoped
      // event so the unread-badge on every device for *this* user
      // converges to the new count without a list refetch. Refetch the
      // current per-user count after the increment so the value is the
      // server's truth, not a guess.
      try {
        const fresh = await Chat.findById(chatId).lean();
        const newUnread = fresh?.unreadCount?.[socket.userId]
          ?? fresh?.unreadCount?.get?.(socket.userId)
          ?? 0;
        this.emitToUser(socket.userId, "chat:unread:update", {
          chatId,
          unreadCount: newUnread,
          timestamp: new Date(),
        });
      } catch (err) {
        // Non-fatal — receipts already sent to the room above.
        console.warn("chat:unread:update emit failed:", err.message);
      }
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

      await chatRoomCache.invalidate(participants.map((p) => p.userId));

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

      await chatRoomCache.invalidate(participants.map((p) => p.userId));

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
