const amqp = require("amqplib");

class MessageQueueService {
  constructor() {
    this.connection = null;
    this.channel = null;
    this.isConnected = false;
    this.retryAttempts = 0;
    this.maxRetries = 5;
    this.retryInterval = 5000; // 5 seconds
  }

  async initialize() {
    try {
      console.log(
        `Attempting to connect to RabbitMQ at ${process.env.RABBITMQ_URL}`
      );
      await this.connect();
      return true;
    } catch (error) {
      console.error("Failed to initialize message queue:", error);
      return false;
    }
  }

  async connect() {
    try {
      this.connection = await amqp.connect(process.env.RABBITMQ_URL);

      this.connection.on("error", (err) => {
        console.error("RabbitMQ connection error:", err);
        this.isConnected = false;
        this.retryConnection();
      });

      this.connection.on("close", () => {
        console.log("RabbitMQ connection closed");
        this.isConnected = false;
        this.retryConnection();
      });

      this.channel = await this.connection.createChannel();

      // Assert queues
      await this.channel.assertQueue("message_delivery", { durable: true });
      await this.channel.assertQueue("notification", { durable: true });

      console.log("Successfully connected to RabbitMQ");
      this.isConnected = true;
      this.retryAttempts = 0;

      this.startConsumers();
    } catch (error) {
      this.isConnected = false;
      throw error;
    }
  }

  async retryConnection() {
    if (this.retryAttempts >= this.maxRetries) {
      console.error(
        `Failed to reconnect to RabbitMQ after ${this.maxRetries} attempts`
      );
      return;
    }

    this.retryAttempts++;

    console.log(
      `Attempting to reconnect to RabbitMQ (${this.retryAttempts}/${
        this.maxRetries
      }) in ${this.retryInterval / 1000} seconds`
    );

    setTimeout(async () => {
      try {
        await this.connect();
      } catch (error) {
        console.error(
          `Reconnection attempt ${this.retryAttempts} failed:`,
          error.message
        );
      }
    }, this.retryInterval);
  }

  async startConsumers() {
    if (!this.channel || !this.isConnected) {
      console.error("Cannot start consumers: no channel available");
      return;
    }

    // Handle message delivery
    this.channel.consume("message_delivery", async (msg) => {
      try {
        const data = JSON.parse(msg.content.toString());
        await this.processMessageDelivery(data);
        this.channel.ack(msg);
      } catch (error) {
        console.error("Error processing message delivery:", error);
        this.channel.nack(msg);
      }
    });
  }

  async processMessageDelivery(data) {
    // message delivery logic
  }

  // Method to safely publish messages with connection check
  async publishMessage(queue, message) {
    if (!this.isConnected) {
      throw new Error("Not connected to RabbitMQ");
    }

    try {
      this.channel.sendToQueue(queue, Buffer.from(JSON.stringify(message)), {
        persistent: true,
      });
      return true;
    } catch (error) {
      console.error("Error publishing message:", error);
      return false;
    }
  }
}

module.exports = new MessageQueueService();
