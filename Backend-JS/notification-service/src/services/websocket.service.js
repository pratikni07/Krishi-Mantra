const WebSocket = require('ws');
const http = require('http');
const logger = require('../utils/logger');

/**
 * WebSocket Notification Service
 * This provides real-time communication for in-app notifications
 * and can be used as a free alternative to third-party push services
 */
class WebSocketService {
  constructor() {
    this.clients = new Map(); // Map of userId -> websocket connection
    this.server = null;
    this.wss = null;
  }

  /**
   * Initialize WebSocket server
   * @param {http.Server} httpServer - HTTP server to attach WebSocket server to
   */
  initialize(httpServer) {
    // Create WebSocket server
    this.wss = new WebSocket.Server({ server: httpServer });
    this.server = httpServer;
    
    // Handle connections
    this.wss.on('connection', (ws, req) => {
      this._handleConnection(ws, req);
    });
    
    logger.info('WebSocket server initialized');
  }

  /**
   * Handle new WebSocket connection
   * @param {WebSocket} ws - WebSocket connection
   * @param {http.IncomingMessage} req - HTTP request
   */
  _handleConnection(ws, req) {
    // Extract URL parameters (e.g., /ws?userId=123&token=abc)
    const url = new URL(req.url, `http://${req.headers.host}`);
    const userId = url.searchParams.get('userId');
    const token = url.searchParams.get('token');
    
    // Validate connection
    if (!userId || !this._validateToken(userId, token)) {
      ws.close(4000, 'Invalid authentication');
      return;
    }
    
    logger.info(`WebSocket client connected: ${userId}`);
    
    // Store client connection
    this.clients.set(userId, ws);
    
    // Handle messages
    ws.on('message', (message) => {
      try {
        const data = JSON.parse(message);
        logger.debug(`Received message from ${userId}:`, data);
        
        // Handle message types
        if (data.type === 'acknowledge') {
          this._handleAcknowledge(userId, data);
        }
      } catch (error) {
        logger.error(`Error handling message from ${userId}:`, error);
      }
    });
    
    // Handle disconnection
    ws.on('close', () => {
      logger.info(`WebSocket client disconnected: ${userId}`);
      this.clients.delete(userId);
    });
    
    // Send welcome message
    this._sendToClient(userId, {
      type: 'system',
      action: 'connected',
      timestamp: new Date().toISOString()
    });
  }

  /**
   * Validate connection token
   * Replace this with your actual authentication logic
   */
  _validateToken(userId, token) {
    // Simple validation for example purposes
    // In a real app, verify against your authentication system
    return token && token.length > 10;
  }

  /**
   * Handle notification acknowledgement
   */
  _handleAcknowledge(userId, data) {
    if (data.notificationId) {
      logger.debug(`User ${userId} acknowledged notification ${data.notificationId}`);
      // In a real app, update the notification status in the database
    }
  }

  /**
   * Send notification to a specific user
   * @param {string} userId - User ID to send notification to
   * @param {Object} notification - Notification data
   * @returns {boolean} - Whether notification was sent
   */
  sendNotification(userId, notification) {
    return this._sendToClient(userId, {
      type: 'notification',
      data: notification,
      timestamp: new Date().toISOString()
    });
  }

  /**
   * Send message to a specific client
   * @param {string} userId - User ID to send to
   * @param {Object} data - Data to send
   * @returns {boolean} - Whether message was sent
   */
  _sendToClient(userId, data) {
    const client = this.clients.get(userId);
    
    if (!client || client.readyState !== WebSocket.OPEN) {
      logger.debug(`Cannot send to client ${userId}: not connected`);
      return false;
    }
    
    try {
      client.send(JSON.stringify(data));
      return true;
    } catch (error) {
      logger.error(`Error sending to client ${userId}:`, error);
      return false;
    }
  }

  /**
   * Broadcast message to all connected clients
   * @param {Object} data - Data to broadcast
   * @param {Function} filter - Optional filter function to determine which clients receive the message
   */
  broadcast(data, filter = null) {
    this.clients.forEach((client, userId) => {
      if (client.readyState === WebSocket.OPEN) {
        if (!filter || filter(userId)) {
          try {
            client.send(JSON.stringify(data));
          } catch (error) {
            logger.error(`Error broadcasting to ${userId}:`, error);
          }
        }
      }
    });
  }
}

module.exports = new WebSocketService(); 