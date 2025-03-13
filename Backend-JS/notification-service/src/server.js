const http = require('http');
const app = require('./app');
const config = require('./config');
const { connectDB } = require('./config/mongodb');
const rabbitmq = require('./config/rabbitmq');
const batchProcessor = require('./workers/batch-processor');
const websocketService = require('./services/websocket.service');
const logger = require('./utils/logger');

async function startServer() {
  try {
    // Connect to MongoDB
    await connectDB();
    
    await rabbitmq.connect();
    
    const httpServer = http.createServer(app);
    
    websocketService.initialize(httpServer);

    await batchProcessor.startConsumer();

    await batchProcessor.scheduleBatchProcessing();
    
    httpServer.listen(config.port, () => {
      logger.info(`Notification service listening on port ${config.port}`);
    });
    
    // Handle graceful shutdown
    process.on('SIGTERM', gracefulShutdown(httpServer));
    process.on('SIGINT', gracefulShutdown(httpServer));
  } catch (error) {
    logger.error('Failed to start server:', error);
    process.exit(1);
  }
}

function gracefulShutdown(server) {
  return async () => {
    logger.info('Shutting down server...');
    
    // Close server
    server.close(async () => {
      logger.info('HTTP server closed');
      
      try {
        // Disconnect from RabbitMQ
        await rabbitmq.disconnect();
        logger.info('Disconnected from RabbitMQ');
        
        // Disconnect from MongoDB
        await mongoose.connection.close();
        logger.info('Disconnected from MongoDB');
        
        logger.info('Graceful shutdown completed');
        process.exit(0);
      } catch (error) {
        logger.error('Error during graceful shutdown:', error);
        process.exit(1);
      }
    });
  };
}

// Start the server
startServer(); 