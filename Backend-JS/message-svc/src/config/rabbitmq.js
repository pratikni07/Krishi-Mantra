const amqp = require('amqplib');

let connection = null;
let channel = null;

const RABBITMQ_CONFIG = {
  url: process.env.RABBITMQ_URL || 'amqp://localhost:5672',
  queues: {
    notification: process.env.RABBITMQ_NOTIFICATION_QUEUE || 'notifications',
    messageEvents: process.env.RABBITMQ_MESSAGE_EVENTS_QUEUE || 'message_events',
  },
};

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

    // Ensure queues exist
    await channel.assertQueue(RABBITMQ_CONFIG.queues.notification, {
      durable: true,
    });

    await channel.assertQueue(RABBITMQ_CONFIG.queues.messageEvents, {
      durable: true,
    });

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
