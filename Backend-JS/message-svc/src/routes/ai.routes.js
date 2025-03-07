const express = require("express");
const router = express.Router();
const AIController = require("../controllers/ai.controller");
const createRateLimiter = require("../middleware/rate-limit.middleware");

// Create specific rate limiters for different endpoints
const messageLimiter = createRateLimiter({
  windowMs: 60 * 1000, // 1 minute
  max: 20, // 20 requests per minute
  message: {
    error:
      "Message rate limit exceeded. Please wait before sending more messages.",
    retryAfter: 60, // 1 minute
  },
});

const imageLimiter = createRateLimiter({
  windowMs: 5 * 60 * 1000, // 5 minutes
  max: 10, // 10 image analyses per 5 minutes
  message: {
    error:
      "Image analysis rate limit exceeded. Please wait before analyzing more images.",
    retryAfter: 300, // 5 minutes
  },
});

// General rate limiter for other endpoints
const defaultLimiter = createRateLimiter({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // 100 requests per 15 minutes
});

// Apply rate limiters to routes
router.post("/chat", messageLimiter, AIController.sendMessage);
router.post("/analyze-image", imageLimiter, AIController.analyzeCropImage);
router.get("/history", defaultLimiter, AIController.getChatHistory);
router.get("/chat/:chatId", defaultLimiter, AIController.getChatById);
router.patch(
  "/chat/:chatId/title",
  defaultLimiter,
  AIController.updateChatTitle
);
router.delete("/chat/:chatId", defaultLimiter, AIController.deleteChat);

// New endpoints for ChatGPT-like functionality
router.get("/limit-info", defaultLimiter, AIController.getMessageLimitInfo);
router.post("/new-chat", defaultLimiter, AIController.createNewChat);

module.exports = router;
