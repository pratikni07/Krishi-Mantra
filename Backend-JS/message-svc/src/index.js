// index.js
require("dotenv").config();
const express = require("express");
const http = require("http");
const helmet = require("helmet");
const compression = require("compression");
const cors = require("cors");
const SocketService = require("./services/socket.service");
const MessageQueueService = require("./services/message-queue.service");
const Database = require("./config/database");
const Redis = require("./config/redis");

class App {
  constructor() {
    this.app = express();
    this.server = http.createServer(this.app);
    this.PORT = process.env.PORT || 3000;
    this.setupMiddlewares();
    this.setupRoutes();
    this.setupErrorHandlers();
  }

  setupMiddlewares() {
    this.app.use(
      helmet({
        contentSecurityPolicy: false,
        crossOriginEmbedderPolicy: false,
      })
    );
    const corsOptions = {
      origin: process.env.ALLOWED_ORIGINS?.split(",") || "*",
      methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
      allowedHeaders: ["Content-Type", "Authorization", "x-user-id"],
      credentials: true,
      maxAge: 86400,
    };
    this.app.use(cors(corsOptions));
    this.app.use(express.json({ limit: "20mb" }));
    this.app.use(express.urlencoded({ extended: true, limit: "20mb" }));
    this.app.use(compression());
    this.app.use((req, res, next) => {
      console.log(`${new Date().toISOString()} - ${req.method} ${req.url}`);
      next();
    });
  }

  setupRoutes() {
    this.app.get("/health", (req, res) => {
      res.json({ status: "OK", timestamp: new Date().toISOString() });
    });
    this.app.use("/api/chat", require("./routes/chat.routes"));
    this.app.use("/api/group", require("./routes/group.routes"));
    this.app.use("/api/message", require("./routes/message.routes"));
    this.app.use("/api/ai", require("./routes/ai.routes"));
    this.app.use((req, res) => {
      res.status(404).json({ error: "Not found" });
    });
  }

  setupErrorHandlers() {
    this.app.use((err, req, res, next) => {
      console.error("Unhandled error:", err);

      if (err.type === "entity.parse.failed") {
        return res.status(400).json({ error: "Invalid JSON" });
      }

      res.status(err.status || 500).json({
        error:
          process.env.NODE_ENV === "production"
            ? "Internal server error"
            : err.message,
      });
    });
    process.on("uncaughtException", (err) => {
      console.error("Uncaught Exception:", err);
      process.exit(1);
    });
    process.on("unhandledRejection", (reason, promise) => {
      console.error("Unhandled Rejection at:", promise, "reason:", reason);
    });
  }

  async start() {
    try {
      await Database.connect();
      const socketService = new SocketService(this.server);
      await MessageQueueService.initialize();
      this.server.listen(this.PORT, () => {
        console.log(`Server running on port ${this.PORT}`);
      });
    } catch (error) {
      console.error("Failed to start server:", error);
      process.exit(1);
    }
  }
}

// Start the application
const app = new App();
app.start();
