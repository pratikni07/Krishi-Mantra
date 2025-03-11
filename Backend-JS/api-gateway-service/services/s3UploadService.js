const { S3Client, PutObjectCommand } = require("@aws-sdk/client-s3");
const { getSignedUrl } = require("@aws-sdk/s3-request-presigner");
const { v4: uuidv4 } = require("uuid");
require("dotenv").config();

// Initialize S3 client
const s3Client = new S3Client({
  region: process.env.AWS_REGION,
  credentials: {
    accessKeyId: process.env.AWS_ACCESS_KEY_ID,
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
  },
});

// Validate content type to ensure it's one of the allowed folders
const validateContentType = (contentType) => {
  const allowedContentTypes = [
    "profile",
    "feeds",
    "reels",
    "services",
    "ads",
    "users",
    "videostuts",
    "chat_image", // Add chat content types
    "chat_video",
    "chat_document",
    "chat_audio",
  ];

  if (!contentType || !allowedContentTypes.includes(contentType)) {
    throw new Error(
      `Invalid content type. Must be one of: ${allowedContentTypes.join(", ")}`
    );
  }

  return contentType;
};

/**
 * Generate a pre-signed URL for S3 upload
 * @param {Object} options - Options for generating the URL
 * @param {string} options.fileName - Original file name
 * @param {string} options.fileType - MIME type of the file
 * @param {string} options.contentType - Type of content (feeds, reels, services, ads, users, videostuts)
 * @param {string} [options.userId] - Optional user ID to include in the path
 * @param {number} [options.expiresIn=900] - URL expiration time in seconds (default: 15 minutes)
 * @returns {Promise<Object>} - Object containing presignedUrl, fileKey, and fileUrl
 */
const generatePresignedUrl = async (options) => {
  const {
    fileName,
    fileType,
    contentType,
    userId = "",
    expiresIn = 900,
  } = options;

  if (!fileName || !fileType) {
    throw new Error(
      "Missing required parameters: fileName and fileType are required"
    );
  }

  // Validate and get the content type folder
  const folder = validateContentType(contentType);

  // Generate a unique file key
  const fileExtension = fileName.split(".").pop().toLowerCase();
  const timestamp = Date.now();
  const uniqueId = uuidv4().substring(0, 8);

  // Create the file path based on content type and user ID if provided
  const userPath = userId ? `${userId}/` : "";
  // const filePath = `${folder}/${userPath}${timestamp}-${uniqueId}.${fileExtension}`;
  const filePath = `${folder}/${timestamp}-${uniqueId}.${fileExtension}`;

  // Create the command for S3
  const command = new PutObjectCommand({
    Bucket: process.env.AWS_BUCKET_NAME,
    Key: filePath,
    ContentType: fileType,
  });

  try {
    // Generate pre-signed URL
    const presignedUrl = await getSignedUrl(s3Client, command, {
      expiresIn,
    });

    // Return the URL data
    return {
      presignedUrl,
      fileKey: filePath,
      fileUrl: `${process.env.AWS_CLOUDFRONT_DOMAIN}/${filePath}`,
      contentType: folder,
      expiresAt: new Date(Date.now() + expiresIn * 1000).toISOString(),
    };
  } catch (error) {
    console.error("Error generating pre-signed URL:", error);
    throw error;
  }
};

module.exports = {
  generatePresignedUrl,
};
