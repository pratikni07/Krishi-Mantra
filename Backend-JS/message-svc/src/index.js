// index.js
require("dotenv").config();
const express = require("express");
const http = require("http");
const helmet = require("helmet");
const compression = require("compression");
const cors = require("cors");
const SocketService = require("./services/socket.service");
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
    this.setupGlobalErrorHandling();
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

      // Capture response for logging
      const originalSend = res.send;
      res.send = function (data) {
        if (res.statusCode >= 400) {
          console.error(
            `Error response (${res.statusCode}): ${JSON.stringify(
              data
            ).substring(0, 200)}...`
          );
        }
        originalSend.apply(res, arguments);
      };

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

      // Special handling for connection reset errors
      if (
        err.code === "ECONNRESET" ||
        err.message?.includes("ECONNRESET") ||
        err.message?.includes("socket hang up") ||
        err.message?.includes("connection reset")
      ) {
        console.error("Connection reset error in request handling:", {
          url: req.url,
          method: req.method,
          error: err.message,
          stack: err.stack?.split("\n")[0],
        });

        return res.status(502).json({
          error: "Message Service unavailable",
          message:
            "The AI service connection was reset. Please try again later.",
          status: "error",
        });
      }

      // For timeout errors
      if (err.message?.includes("timeout")) {
        return res.status(504).json({
          error: "Request timed out",
          message:
            "The request took too long to complete. Please try again later.",
          status: "error",
        });
      }

      res.status(err.status || 500).json({
        error:
          process.env.NODE_ENV === "production"
            ? "Internal server error"
            : err.message,
      });
    });
  }

  setupGlobalErrorHandling() {
    // Handle uncaught exceptions with detailed logging and graceful shutdown
    process.on("uncaughtException", (err) => {
      console.error("CRITICAL - Uncaught Exception:", {
        message: err.message,
        stack: err.stack,
        time: new Date().toISOString(),
      });

      // Force process exit after logging - prevents hanging in undefined state
      console.log("Process will exit due to uncaught exception");

      // Give time for logs to be written
      setTimeout(() => process.exit(1), 500);
    });

    // Handle unhandled promise rejections with better logging
    process.on("unhandledRejection", (reason, promise) => {
      console.error("CRITICAL - Unhandled Promise Rejection:", {
        reason:
          reason instanceof Error
            ? {
                message: reason.message,
                stack: reason.stack,
                code: reason.code,
              }
            : reason,
        time: new Date().toISOString(),
      });

      // In production, we might want to exit on unhandled rejections as well
      if (process.env.NODE_ENV === "production") {
        console.log("Process will exit due to unhandled rejection");
        setTimeout(() => process.exit(1), 500);
      }
    });
  }

  async start() {
    try {
      await Database.connect();
      const socketService = new SocketService(this.server);

      this.server.listen(this.PORT, () => {
        console.log(`Server running on port ${this.PORT}`);
      });

      // Set server timeout to handle hanging connections
      this.server.timeout = 60000; // 60 seconds
      this.server.keepAliveTimeout = 30000; // 30 seconds
    } catch (error) {
      console.error("Failed to start server:", error);
      process.exit(1);
    }
  }
}

// Start the application
const app = new App();
app.start();
