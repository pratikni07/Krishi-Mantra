const express = require("express");
const { generatePresignedUrl } = require("../services/s3UploadService");

const router = express.Router();

/**
 * Generate a pre-signed URL for uploading files to S3
 * @route POST /api/upload/getPresignedUrl
 * @param {string} fileName - Original file name
 * @param {string} fileType - MIME type of the file (e.g., image/jpeg, video/mp4)
 * @param {string} contentType - Category folder (feeds, reels, services, ads, users, videostuts)
 * @param {string} [userId] - Optional user ID for organizing files by user
 * @returns {Object} Pre-signed URL and file information
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
 * @returns {Object} List of allowed content types
 */
router.get("/contentTypes", (req, res) => {
  res.status(200).json({
    status: "success",
    data: {
      contentTypes: [
        "feeds",
        "reels",
        "services",
        "ads",
        "users",
        "videostuts",
      ],
    },
  });
});

module.exports = router;
