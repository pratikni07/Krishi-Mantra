const express = require("express");
const router = express.Router();
const AIController = require("../controllers/ai.controller");
const createRateLimiter = require("../middleware/rate-limit.middleware");
const multer = require("multer");

// Create specific rate limiters for different endpoints
const messageLimiter = createRateLimiter({
  windowMs: 60 * 1000, // 1 minute
  max: 200, // 200 requests per minute (increased significantly for development)
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

// Configure multer for memory storage (for image processing)
const storage = multer.memoryStorage();
const upload = multer({
  storage: storage,
  limits: {
    fileSize: process.env.MAX_FILE_SIZE || 10 * 1024 * 1024, // 10MB limit
  },
});

// Apply rate limiters to routes
// Bind methods to preserve 'this' context
router.post("/chat", messageLimiter, AIController.sendMessage.bind(AIController));

// Single image upload route
router.post(
  "/analyze-image",
  imageLimiter,
  upload.single("image"), // Field name must be "image"
  AIController.analyzeCropImage.bind(AIController)
);

// Multiple image upload route
router.post(
  "/analyze-multi-images",
  imageLimiter,
  upload.array("images", 5), // Field name must be "images", max 5 files
  AIController.analyzeMultipleImages.bind(AIController)
);

router.get("/history", defaultLimiter, AIController.getChatHistory.bind(AIController));
router.get("/chat/:chatId", defaultLimiter, AIController.getChatById.bind(AIController));
router.patch(
  "/chat/:chatId/title",
  defaultLimiter,
  AIController.updateChatTitle.bind(AIController)
);
router.delete("/chat/:chatId", defaultLimiter, AIController.deleteChat.bind(AIController));

// New endpoints for ChatGPT-like functionality
router.get("/limit-info", defaultLimiter, AIController.getMessageLimitInfo.bind(AIController));
router.post("/new-chat", defaultLimiter, AIController.createNewChat.bind(AIController));

module.exports = router;
