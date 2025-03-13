const express = require("express");
const { generatePresignedUrl } = require("../services/s3UploadService");
const multer = require("multer");
const fetch = require("node-fetch");

const router = express.Router();
const upload = multer({ storage: multer.memoryStorage() });

const ALLOWED_CONTENT_TYPES = [
  "profile",
  "feeds",
  "reels",
  "services",
  "ads",
  "users",
  "videostuts",
  "chat_image",
  "chat_video",
  "chat_document",
  "chat_audio",
  "notification",
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

// Add a new route to upload files via proxy
router.post("/proxy-upload", upload.single("file"), async (req, res) => {
  try {
    const { presignedUrl } = req.query;
    if (!presignedUrl) {
      return res.status(400).json({
        status: "error",
        message: "Missing presignedUrl parameter",
      });
    }

    if (!req.file) {
      return res.status(400).json({
        status: "error",
        message: "No file provided",
      });
    }

    console.log(`Uploading file to ${presignedUrl}`);

    // Forward the file to S3 using the presigned URL
    const response = await fetch(presignedUrl, {
      method: "PUT",
      headers: {
        "Content-Type": req.file.mimetype,
      },
      body: req.file.buffer,
    });

    if (!response.ok) {
      console.error(`S3 upload failed with status: ${response.status}`);
      return res.status(response.status).json({
        status: "error",
        message: `S3 upload failed with status: ${response.status}`,
      });
    }

    res.status(200).json({
      status: "success",
      message: "File uploaded successfully",
    });
  } catch (error) {
    console.error("Proxy upload error:", error);
    res.status(500).json({
      status: "error",
      message: "Failed to upload file",
      error: process.env.NODE_ENV === "development" ? error.message : undefined,
    });
  }
});

module.exports = router;
