const amqp = require('amqplib');
const config = require('./index');
const logger = require('../utils/logger');

let connection = null;
let channel = null;
let isConnected = false;
// Track consumer tags so graceful shutdown can stop pulling new messages
// *before* the buffer flush and the MongoDB/Redis teardown. Without this,
// consumers kept running until channel.close, and in-flight handlers raced
// the database disconnect.
const consumerTags = [];
let inFlightMessages = 0;

// Dead-letter topology. A poison message (parse error, schema mismatch, code
// bug) would previously nack+requeue forever — one bad payload could pin a
// consumer CPU indefinitely. We cap retries in the consumer below and route
// exhausted messages to a DLQ for operator inspection.
const DLX_NAME = 'engagement.dlx';
const DLQ_EVENTS = `${config.rabbitmq.queues.events}.dlq`;
const DLQ_BATCH = `${config.rabbitmq.queues.batch}.dlq`;

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

      // Dead-letter exchange: messages that exceed the retry budget (or expire)
      // are routed here. DLQs are durable so operators can triage offline.
      await channel.assertExchange(DLX_NAME, 'direct', { durable: true });

      await channel.assertQueue(DLQ_EVENTS, { durable: true });
      await channel.bindQueue(DLQ_EVENTS, DLX_NAME, config.rabbitmq.queues.events);

      await channel.assertQueue(DLQ_BATCH, { durable: true });
      await channel.bindQueue(DLQ_BATCH, DLX_NAME, config.rabbitmq.queues.batch);

      // Ensure queues exist with proper configuration
      await channel.assertQueue(config.rabbitmq.queues.events, {
        durable: true,
        arguments: {
          'x-message-ttl': 86400000, // 24 hours
          'x-max-length': 1000000, // Max 1M messages
          'x-dead-letter-exchange': DLX_NAME,
          'x-dead-letter-routing-key': config.rabbitmq.queues.events,
        },
      });

      await channel.assertQueue(config.rabbitmq.queues.batch, {
        durable: true,
        arguments: {
          'x-message-ttl': 86400000,
          'x-max-length': 100000,
          'x-dead-letter-exchange': DLX_NAME,
          'x-dead-letter-routing-key': config.rabbitmq.queues.batch,
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

      const { consumerTag } = await channel.consume(queue, async (msg) => {
        if (!msg) return;

        inFlightMessages += 1;
        try {
          const data = JSON.parse(msg.content.toString());
          await handler(data);
          channel.ack(msg);
        } catch (error) {
          // Previously: nack with requeue=true → broker puts it straight back
          // on the queue → same handler pulls it → same crash. A poison
          // payload pinned a consumer CPU forever. Now: nack without requeue
          // so the broker routes the message through the DLX to the DLQ for
          // operator inspection. Transient failures (MongoDB, Redis) are
          // already retried by their own drivers; at this layer, a failure
          // almost always means a schema/bug problem that requeueing can't
          // fix.
          logger.error(
            `Message processing failed on ${queue}, routing to DLQ: ${error.message}`
          );
          channel.nack(msg, false, false);
        } finally {
          inFlightMessages -= 1;
        }
      });

      consumerTags.push(consumerTag);
      logger.info(`Started consuming from queue: ${queue} (tag: ${consumerTag})`);
      return true;
    } catch (error) {
      logger.error('Error starting consumer:', error.message);
      return false;
    }
  }

  /**
   * Cancel all registered consumers and wait for in-flight handlers to
   * finish. Call this BEFORE closing MongoDB/Redis — otherwise a message in
   * flight would race the database teardown.
   *
   * @param {number} drainTimeoutMs - Max time to wait for in-flight messages
   */
  static async stopConsumers(drainTimeoutMs = 10000) {
    if (!channel) return;

    for (const tag of consumerTags.splice(0)) {
      try {
        await channel.cancel(tag);
        logger.info(`Canceled consumer ${tag}`);
      } catch (err) {
        logger.warn(`Failed to cancel consumer ${tag}: ${err.message}`);
      }
    }

    const start = Date.now();
    while (inFlightMessages > 0 && Date.now() - start < drainTimeoutMs) {
      await new Promise((r) => setTimeout(r, 100));
    }
    if (inFlightMessages > 0) {
      logger.warn(`Drain timeout with ${inFlightMessages} in-flight messages`);
    } else {
      logger.info('All in-flight messages drained');
    }
  }
}

module.exports = RabbitMQ;
