const WebSocket = require('ws');
const logger = require('../utils/logger');
const { WEBSOCKET_CONFIG, RATE_LIMITS } = require('../utils/constants');

/**
 * WebSocket Notification Service
 * Optimized for 10k concurrent connections
 */
class WebSocketService {
  constructor() {
    this.clients = new Map(); // Map of userId -> Set of WebSocket connections
    this.server = null;
    this.wss = null;
    this.rateLimitMap = new Map(); // Map of socketId -> { eventCount, lastReset }
    this.userConnectionCount = new Map(); // Map of userId -> connection count
    this.cleanupInterval = null;
  }

  /**
   * Initialize WebSocket server
   * @param {http.Server} httpServer - HTTP server to attach WebSocket server to
   */
  initialize(httpServer) {
    this.wss = new WebSocket.Server({
      server: httpServer,
      maxPayload: WEBSOCKET_CONFIG.MAX_PAYLOAD,
      perMessageDeflate: {
        zlibDeflateOptions: {
          chunkSize: 1024,
          memLevel: 7,
          level: 3,
        },
        zlibInflateOptions: {
          chunkSize: 10 * 1024,
        },
        clientNoContextTakeover: true,
        serverNoContextTakeover: true,
        serverMaxWindowBits: 10,
        concurrencyLimit: 10,
        threshold: 1024, // Only compress messages > 1KB
      },
    });

    this.server = httpServer;

    // Handle connections
    this.wss.on('connection', (ws, req) => {
      this._handleConnection(ws, req);
    });

    // Cleanup stale connections and rate limits periodically
    this.cleanupInterval = setInterval(() => {
      this._cleanupStaleConnections();
      this._cleanupRateLimits();
    }, 60000);

    // Heartbeat to detect dead connections
    this._startHeartbeat();

    logger.info('WebSocket server initialized for 10k connections');
  }

  /**
   * Handle new WebSocket connection
   * @param {WebSocket} ws - WebSocket connection
   * @param {http.IncomingMessage} req - HTTP request
   */
  _handleConnection(ws, req) {
    // Extract URL parameters
    const url = new URL(req.url, `http://${req.headers.host}`);
    const userId = url.searchParams.get('userId');
    const token = url.searchParams.get('token');

    // Validate connection
    if (!userId || !this._validateToken(userId, token)) {
      ws.close(4000, 'Invalid authentication');
      return;
    }

    // Check connection limit per user
    const currentConnections = this.userConnectionCount.get(userId) || 0;
    if (currentConnections >= WEBSOCKET_CONFIG.MAX_CONNECTIONS_PER_USER) {
      ws.close(4001, 'Maximum connections exceeded');
      return;
    }

    // Generate unique socket ID
    const socketId = `${userId}-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
    ws.socketId = socketId;
    ws.userId = userId;
    ws.isAlive = true;

    logger.info(`WebSocket client connected: ${userId} (${socketId})`);

    // Store client connection (support multiple connections per user)
    if (!this.clients.has(userId)) {
      this.clients.set(userId, new Set());
    }
    this.clients.get(userId).add(ws);

    // Update connection count
    this.userConnectionCount.set(userId, currentConnections + 1);

    // Handle pong for heartbeat
    ws.on('pong', () => {
      ws.isAlive = true;
    });

    // Handle messages with rate limiting
    ws.on('message', (message) => {
      if (!this._checkRateLimit(socketId)) {
        this._sendToSocket(ws, {
          type: 'error',
          message: 'Rate limit exceeded. Please slow down.',
        });
        return;
      }

      try {
        const data = JSON.parse(message);
        this._handleMessage(ws, data);
      } catch (error) {
        logger.error(`Error handling message from ${userId}:`, error.message);
      }
    });

    // Handle disconnection
    ws.on('close', (code, reason) => {
      this._handleDisconnection(ws, code, reason);
    });

    // Handle errors
    ws.on('error', (error) => {
      logger.error(`WebSocket error for ${userId}:`, error.message);
    });

    // Send welcome message
    this._sendToSocket(ws, {
      type: 'system',
      action: 'connected',
      socketId,
      timestamp: new Date().toISOString(),
    });
  }

  /**
   * Handle incoming WebSocket message
   */
  _handleMessage(ws, data) {
    switch (data.type) {
      case 'acknowledge':
        this._handleAcknowledge(ws.userId, data);
        break;
      case 'ping':
        this._sendToSocket(ws, { type: 'pong', timestamp: Date.now() });
        break;
      case 'subscribe':
        // Handle topic subscription (for future use)
        logger.debug(`User ${ws.userId} subscribed to ${data.topic}`);
        break;
      default:
        logger.debug(`Unknown message type from ${ws.userId}:`, data.type);
    }
  }

  /**
   * Validate connection token
   */
  _validateToken(userId, token) {
    // Simple validation - in production, verify against your auth system
    return token && token.length >= 10;
  }

  /**
   * Check and enforce rate limiting for socket events
   */
  _checkRateLimit(socketId) {
    const now = Date.now();
    let limitData = this.rateLimitMap.get(socketId);

    if (!limitData || now - limitData.lastReset > 1000) {
      limitData = { eventCount: 0, lastReset: now };
    }

    limitData.eventCount++;
    this.rateLimitMap.set(socketId, limitData);

    return limitData.eventCount <= RATE_LIMITS.WS_EVENTS_PER_SECOND;
  }

  /**
   * Cleanup stale rate limit entries
   */
  _cleanupRateLimits() {
    const now = Date.now();
    for (const [socketId, data] of this.rateLimitMap.entries()) {
      if (now - data.lastReset > 60000) {
        this.rateLimitMap.delete(socketId);
      }
    }
  }

  /**
   * Start heartbeat interval to detect dead connections
   */
  _startHeartbeat() {
    setInterval(() => {
      this.wss.clients.forEach((ws) => {
        if (ws.isAlive === false) {
          logger.debug(`Terminating dead connection: ${ws.userId}`);
          return ws.terminate();
        }
        ws.isAlive = false;
        ws.ping();
      });
    }, WEBSOCKET_CONFIG.PING_INTERVAL);
  }

  /**
   * Cleanup stale connections
   */
  _cleanupStaleConnections() {
    for (const [userId, sockets] of this.clients.entries()) {
      for (const ws of sockets) {
        if (ws.readyState === WebSocket.CLOSED || ws.readyState === WebSocket.CLOSING) {
          sockets.delete(ws);
        }
      }
      if (sockets.size === 0) {
        this.clients.delete(userId);
        this.userConnectionCount.delete(userId);
      }
    }
    logger.debug(`Active connections: ${this.getStats().connections}`);
  }

  /**
   * Handle notification acknowledgement
   */
  _handleAcknowledge(userId, data) {
    if (data.notificationId) {
      logger.debug(`User ${userId} acknowledged notification ${data.notificationId}`);
      // Emit event for notification service to mark as seen
    }
  }

  /**
   * Handle WebSocket disconnection
   */
  _handleDisconnection(ws, code, reason) {
    const userId = ws.userId;
    const socketId = ws.socketId;

    logger.info(`WebSocket client disconnected: ${userId} (${socketId}), code: ${code}`);

    // Remove from clients
    const userSockets = this.clients.get(userId);
    if (userSockets) {
      userSockets.delete(ws);
      if (userSockets.size === 0) {
        this.clients.delete(userId);
        this.userConnectionCount.delete(userId);
      } else {
        // Update connection count
        const currentCount = this.userConnectionCount.get(userId) || 1;
        this.userConnectionCount.set(userId, Math.max(0, currentCount - 1));
      }
    }

    // Cleanup rate limit entry
    this.rateLimitMap.delete(socketId);
  }

  /**
   * Send notification to a specific user (all their connections)
   * @param {string} userId - User ID to send notification to
   * @param {Object} notification - Notification data
   * @returns {boolean} - Whether notification was sent
   */
  sendNotification(userId, notification) {
    const userSockets = this.clients.get(userId);
    if (!userSockets || userSockets.size === 0) {
      logger.debug(`Cannot send to user ${userId}: not connected`);
      return false;
    }

    const message = {
      type: 'notification',
      data: notification,
      timestamp: new Date().toISOString(),
    };

    let sent = false;
    for (const ws of userSockets) {
      if (this._sendToSocket(ws, message)) {
        sent = true;
      }
    }

    return sent;
  }

  /**
   * Send message to a specific socket
   */
  _sendToSocket(ws, data) {
    if (!ws || ws.readyState !== WebSocket.OPEN) {
      return false;
    }

    try {
      ws.send(JSON.stringify(data));
      return true;
    } catch (error) {
      logger.error(`Error sending to socket:`, error.message);
      return false;
    }
  }

  /**
   * Broadcast message to all connected clients
   * @param {Object} data - Data to broadcast
   * @param {Function} filter - Optional filter function
   */
  broadcast(data, filter = null) {
    const message = JSON.stringify(data);

    this.clients.forEach((sockets, userId) => {
      if (!filter || filter(userId)) {
        for (const ws of sockets) {
          if (ws.readyState === WebSocket.OPEN) {
            try {
              ws.send(message);
            } catch (error) {
              logger.error(`Error broadcasting to ${userId}:`, error.message);
            }
          }
        }
      }
    });
  }

  /**
   * Check if user is connected
   * @param {string} userId - User ID to check
   * @returns {boolean}
   */
  isUserConnected(userId) {
    const userSockets = this.clients.get(userId);
    return userSockets && userSockets.size > 0;
  }

  /**
   * Get service statistics for health check
   */
  getStats() {
    let totalConnections = 0;
    for (const sockets of this.clients.values()) {
      totalConnections += sockets.size;
    }

    return {
      connections: totalConnections,
      uniqueUsers: this.clients.size,
    };
  }

  /**
   * Cleanup on service shutdown
   */
  shutdown() {
    if (this.cleanupInterval) {
      clearInterval(this.cleanupInterval);
    }

    // Close all connections gracefully
    this.clients.forEach((sockets, userId) => {
      for (const ws of sockets) {
        ws.close(1001, 'Server shutting down');
      }
    });

    this.clients.clear();
    this.userConnectionCount.clear();
    this.rateLimitMap.clear();

    logger.info('WebSocket service shut down');
  }
}

module.exports = new WebSocketService();
