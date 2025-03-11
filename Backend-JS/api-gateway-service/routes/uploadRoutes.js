const express = require("express");
const { generatePresignedUrl } = require("../services/s3UploadService");

const router = express.Router();

// Update the allowed content types to include chat-related types
const ALLOWED_CONTENT_TYPES = [
  "profile",
  "feeds",
  "reels",
  "services",
  "ads",
  "users",
  "videostuts",
  "chat_image", // Add this
  "chat_video", // Add this
  "chat_document", // Add this
  "chat_audio", // Add this
];

/**
 * Generate a pre-signed URL for uploading files to S3
 * @route POST /api/upload/getPresignedUrl
 */
router.post("/getPresignedUrl", async (req, res) => {
  try {
    const { fileName, fileType, contentType, userId } = req.body;

    // Input validation
    if (!fileName || !fileType || !contentType) {
      return res.status(400).json({
        status: "error",
        message:
          "Missing required parameters: fileName, fileType, and contentType are required",
      });
    }

    // Validate content type
    if (!ALLOWED_CONTENT_TYPES.includes(contentType)) {
      return res.status(400).json({
        status: "error",
        message: `Invalid content type. Must be one of: ${ALLOWED_CONTENT_TYPES.join(
          ", "
        )}`,
      });
    }

    // Generate the pre-signed URL
    const uploadData = await generatePresignedUrl({
      fileName,
      fileType,
      contentType,
      userId,
    });

    // Return success response
    res.status(200).json({
      status: "success",
      data: uploadData,
    });
  } catch (error) {
    console.error("Upload error:", error);

    // Handle specific validation errors
    if (error.message.includes("Invalid content type")) {
      return res.status(400).json({
        status: "error",
        message: error.message,
      });
    }

    // General error response
    res.status(500).json({
      status: "error",
      message: "Failed to generate pre-signed URL",
      error: process.env.NODE_ENV === "development" ? error.message : undefined,
    });
  }
});

/**
 * API endpoint to list allowed content types
 * @route GET /api/upload/contentTypes
 */
router.get("/contentTypes", (req, res) => {
  res.status(200).json({
    status: "success",
    data: {
      contentTypes: ALLOWED_CONTENT_TYPES,
    },
  });
});

module.exports = router;
