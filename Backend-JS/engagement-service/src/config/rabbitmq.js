const amqp = require('amqplib');
const config = require('./index');
const logger = require('../utils/logger');

let connection = null;
let channel = null;
let isConnected = false;

/**
 * RabbitMQ Connection Manager
 * Handles async event processing for 100k+ users
 */
class RabbitMQ {
  static async connect() {
    try {
      if (connection && channel) {
        return { connection, channel };
      }

      connection = await amqp.connect(config.rabbitmq.url);
      channel = await connection.createChannel();

      // Set prefetch for controlled concurrency
      await channel.prefetch(config.rabbitmq.prefetch);

      // Ensure queues exist with proper configuration
      await channel.assertQueue(config.rabbitmq.queues.events, {
        durable: true,
        arguments: {
          'x-message-ttl': 86400000, // 24 hours
          'x-max-length': 1000000, // Max 1M messages
        },
      });

      await channel.assertQueue(config.rabbitmq.queues.batch, {
        durable: true,
        arguments: {
          'x-message-ttl': 86400000,
          'x-max-length': 100000,
        },
      });

      isConnected = true;
      logger.info('RabbitMQ connected successfully');

      // Handle connection errors
      connection.on('error', (err) => {
        logger.error('RabbitMQ connection error:', err.message);
        isConnected = false;
        this._reconnect();
      });

      connection.on('close', () => {
        logger.warn('RabbitMQ connection closed');
        isConnected = false;
        connection = null;
        channel = null;
      });

      return { connection, channel };
    } catch (error) {
      logger.error('RabbitMQ connection failed:', error.message);
      isConnected = false;
      // Don't throw - allow service to continue without RabbitMQ
      return { connection: null, channel: null };
    }
  }

  static async _reconnect() {
    logger.info('Attempting to reconnect to RabbitMQ...');
    setTimeout(async () => {
      try {
        await this.connect();
      } catch (error) {
        logger.error('RabbitMQ reconnection failed:', error.message);
        this._reconnect();
      }
    }, 5000);
  }

  static async disconnect() {
    try {
      if (channel) {
        await channel.close();
        channel = null;
      }
      if (connection) {
        await connection.close();
        connection = null;
      }
      isConnected = false;
      logger.info('RabbitMQ disconnected');
    } catch (error) {
      logger.error('RabbitMQ disconnect error:', error.message);
    }
  }

  static getChannel() {
    return channel;
  }

  static isConnected() {
    return isConnected;
  }

  /**
   * Send event to queue
   * @param {Object} event - Event data
   * @param {string} queue - Queue name (optional, defaults to events queue)
   */
  static async sendToQueue(event, queue = config.rabbitmq.queues.events) {
    try {
      if (!channel) {
        logger.warn('RabbitMQ not connected, buffering event locally');
        return false;
      }

      const message = JSON.stringify(event);
      await channel.sendToQueue(queue, Buffer.from(message), {
        persistent: true,
        priority: event.priority || 0,
      });

      return true;
    } catch (error) {
      logger.error('Error sending to queue:', error.message);
      return false;
    }
  }

  /**
   * Send batch of events to queue
   * @param {Array} events - Array of events
   */
  static async sendBatchToQueue(events) {
    try {
      if (!channel) {
        logger.warn('RabbitMQ not connected');
        return false;
      }

      const batch = {
        batchId: `batch-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
        count: events.length,
        events,
        timestamp: new Date().toISOString(),
      };

      await channel.sendToQueue(
        config.rabbitmq.queues.batch,
        Buffer.from(JSON.stringify(batch)),
        { persistent: true }
      );

      return true;
    } catch (error) {
      logger.error('Error sending batch to queue:', error.message);
      return false;
    }
  }

  /**
   * Start consuming from a queue
   * @param {string} queue - Queue name
   * @param {Function} handler - Message handler function
   */
  static async consume(queue, handler) {
    try {
      if (!channel) {
        logger.warn('RabbitMQ not connected, cannot consume');
        return false;
      }

      await channel.consume(queue, async (msg) => {
        if (!msg) return;

        try {
          const data = JSON.parse(msg.content.toString());
          await handler(data);
          channel.ack(msg);
        } catch (error) {
          logger.error('Error processing message:', error.message);
          // Negative acknowledge and requeue
          channel.nack(msg, false, true);
        }
      });

      logger.info(`Started consuming from queue: ${queue}`);
      return true;
    } catch (error) {
      logger.error('Error starting consumer:', error.message);
      return false;
    }
  }
}

module.exports = RabbitMQ;
