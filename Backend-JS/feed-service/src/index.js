const path = require("path");
const dotenv = require("dotenv");

// Load environment variables based on NODE_ENV
const envFile = process.env.NODE_ENV === 'production' 
  ? path.resolve(process.cwd(), '.env.production')
  : path.resolve(process.cwd(), '.env.development');

dotenv.config({ path: envFile });
console.log(`Using environment: ${process.env.NODE_ENV}, loaded from: ${envFile}`);

const express = require("express");
const mongoose = require("mongoose");
const cors = require("cors");
const helmet = require("helmet");
const rateLimit = require("express-rate-limit");
const { redisClient } = require("./config/redis");
const analyticsRoutes = require("./routes/analytics");

const app = express();

// Security Middleware
app.use(helmet());

// Rate Limiting
// const limiter = rateLimit({
//   windowMs: 15 * 60 * 1000, // 15 minutes
//   max: 100, // limit each IP to 100 requests per windowMs
// });
// app.use(limiter);

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Database Connection
mongoose
  .connect(process.env.MONGODB_URI, {
    useNewUrlParser: true,
    useUnifiedTopology: true,
    serverSelectionTimeoutMS: 5000,
  })
  .then(() => console.log("MongoDB Connected"))
  .catch((err) => console.error("MongoDB Connection Error:", err));

mongoose.connection.on("connected", () => {
  console.log("Mongoose connected to database");
});

mongoose.connection.on("error", (err) => {
  console.error("Mongoose connection error:", err);
});

// Routes
app.use("/feeds", require("./routes/feed"));
app.use("/comments", require("./routes/comment"));
app.use("/likes", require("./routes/like"));
app.use("/analytics", analyticsRoutes);

// Global Error Handler
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({
    message: "Something went wrong!",
    error: process.env.NODE_ENV === "production" ? {} : err.stack,
  });
});

// Start Server
const PORT = process.env.PORT || 3000;
const server = app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});

// Graceful Shutdown
process.on("SIGTERM", () => {
  console.log("SIGTERM received. Closing HTTP server.");
  server.close(() => {
    console.log("HTTP server closed.");
    mongoose.connection.close(false, () => {
      console.log("MongoDB connection closed.");
      process.exit(0);
    });
  });
});

module.exports = app;
