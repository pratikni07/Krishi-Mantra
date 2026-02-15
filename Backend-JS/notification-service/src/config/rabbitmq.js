const amqp = require('amqplib');
const config = require('./index');
const logger = require('../utils/logger');

let connection = null;
let channel = null;

const connect = async () => {
  try {
    connection = await amqp.connect(config.rabbitmq.url);
    channel = await connection.createChannel();

    await channel.assertQueue(config.rabbitmq.queues.notification, { durable: true });
    await channel.assertQueue(config.rabbitmq.queues.batch, { durable: true });
    await channel.assertQueue(config.rabbitmq.queues.event, { durable: true });

    await channel.assertExchange(config.rabbitmq.exchange, 'topic', { durable: true });
    await channel.bindQueue(config.rabbitmq.queues.event, config.rabbitmq.exchange, 'notification.event.*');

    logger.info('RabbitMQ connected successfully');
    return { connection, channel };
  } catch (error) {
    logger.error('RabbitMQ connection error:', error);
    throw error;
  }
};

const getChannel = () => {
  if (!channel) throw new Error('RabbitMQ channel not initialized');
  return channel;
};

const disconnect = async () => {
  if (channel) await channel.close();
  if (connection) await connection.close();
  logger.info('RabbitMQ disconnected');
};

module.exports = {
  connect,
  getChannel,
  disconnect,
};
