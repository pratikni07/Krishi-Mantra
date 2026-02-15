require('dotenv').config();

module.exports = {
  port: process.env.PORT || 3000,
  env: process.env.NODE_ENV || 'development',
  mongodb: {
    uri: process.env.MONGODB_URI || 'mongodb://localhost:27017/notification_service'
  },
  redis: {
    host: process.env.REDIS_HOST || 'localhost',
    port: parseInt(process.env.REDIS_PORT || '6379')
  },
  rabbitmq: {
    url: process.env.RABBITMQ_URL || 'amqp://localhost:5672',
    exchange: process.env.RABBITMQ_EVENT_EXCHANGE || 'notification.events',
    queues: {
      notification: process.env.RABBITMQ_NOTIFICATION_QUEUE || 'notifications',
      batch: process.env.RABBITMQ_BATCH_QUEUE || 'notification_batches',
      event: process.env.RABBITMQ_EVENT_QUEUE || 'notification_events'
    }
  },
  batch: {
    size: parseInt(process.env.BATCH_SIZE || '100'),
    intervalMs: parseInt(process.env.BATCH_INTERVAL_MS || '60000'),
    digestFlushIntervalMs: parseInt(process.env.DIGEST_FLUSH_INTERVAL_MS || '300000')
  }
}; 