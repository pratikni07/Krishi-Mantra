const amqp = require('amqplib');

let connection = null;
let channel = null;

const RABBITMQ_CONFIG = {
  url: process.env.RABBITMQ_URL || 'amqp://localhost:5672',
  queues: {
    notification: process.env.RABBITMQ_NOTIFICATION_QUEUE || 'notifications',
    feedEvents: process.env.RABBITMQ_FEED_EVENTS_QUEUE || 'feed_events',
  },
};

// Dead-letter exchange: rejected messages land in a DLQ for triage rather
// than being silently dropped or requeued forever.
const DLX_NAME = 'feed.dlx';

/**
 * Connect to RabbitMQ
 * @returns {Promise<{connection, channel}>}
 */
const connect = async () => {
  try {
    if (connection && channel) {
      return { connection, channel };
    }

    connection = await amqp.connect(RABBITMQ_CONFIG.url);
    channel = await connection.createChannel();

    await channel.assertExchange(DLX_NAME, 'direct', { durable: true });

    const mainQueues = [
      RABBITMQ_CONFIG.queues.feedEvents,
    ];
    for (const q of mainQueues) {
      const dlq = `${q}.dlq`;
      await channel.assertQueue(dlq, { durable: true });
      await channel.bindQueue(dlq, DLX_NAME, q);
      await channel.assertQueue(q, {
        durable: true,
        arguments: {
          'x-dead-letter-exchange': DLX_NAME,
          'x-dead-letter-routing-key': q,
        },
      });
    }

    console.log('[RabbitMQ] Connected successfully');

    // Handle connection errors
    connection.on('error', (err) => {
      console.error('[RabbitMQ] Connection error:', err.message);
      connection = null;
      channel = null;
    });

    connection.on('close', () => {
      console.log('[RabbitMQ] Connection closed');
      connection = null;
      channel = null;
    });

    return { connection, channel };
  } catch (error) {
    console.error('[RabbitMQ] Connection error:', error.message);
    // Don't throw - allow service to continue without RabbitMQ
    return { connection: null, channel: null };
  }
};

/**
 * Get the RabbitMQ channel
 * @returns {Object|null}
 */
const getChannel = () => {
  return channel;
};

/**
 * Check if RabbitMQ is connected
 * @returns {boolean}
 */
const isConnected = () => {
  return connection !== null && channel !== null;
};

/**
 * Disconnect from RabbitMQ
 */
const disconnect = async () => {
  try {
    if (channel) {
      await channel.close();
      channel = null;
    }
    if (connection) {
      await connection.close();
      connection = null;
    }
    console.log('[RabbitMQ] Disconnected');
  } catch (error) {
    console.error('[RabbitMQ] Disconnect error:', error.message);
  }
};

module.exports = {
  connect,
  getChannel,
  isConnected,
  disconnect,
  RABBITMQ_CONFIG,
};
