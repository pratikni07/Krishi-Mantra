const amqp = require('amqplib');
const config = require('./index');
const logger = require('../utils/logger');

let connection = null;
let channel = null;

// Consumer-drain state for graceful shutdown. Batch-processor handlers write
// to MongoDB; if the DB is closed while a handler is in flight, the write
// throws and the notification is lost. stopConsumers() cancels subscriptions
// and waits for in-flight handlers before we close Mongo/Redis.
const consumerTags = [];
let inFlightMessages = 0;

const trackConsumerTag = (tag) => {
  if (tag) consumerTags.push(tag);
};

const onHandlerStart = () => {
  inFlightMessages += 1;
};

const onHandlerEnd = () => {
  inFlightMessages = Math.max(0, inFlightMessages - 1);
};

const stopConsumers = async (drainTimeoutMs = 15000) => {
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
};

// Dead-letter topology. Previously a broken notification payload could pin a
// consumer in an infinite nack/requeue loop. We route rejected messages to
// per-queue DLQs for operator triage.
const DLX_NAME = 'notification.dlx';
const dlqName = (q) => `${q}.dlq`;

const connect = async () => {
  try {
    connection = await amqp.connect(config.rabbitmq.url);
    channel = await connection.createChannel();

    await channel.assertExchange(DLX_NAME, 'direct', { durable: true });

    const mainQueues = [
      config.rabbitmq.queues.notification,
      config.rabbitmq.queues.batch,
      config.rabbitmq.queues.event,
    ];
    for (const q of mainQueues) {
      const dlq = dlqName(q);
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
  stopConsumers,
  trackConsumerTag,
  onHandlerStart,
  onHandlerEnd,
};
