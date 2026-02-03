const {
  cloudinary,
  validateConfig,
  VIDEO_PRESETS,
  getStreamingUrls,
  deleteVideo,
  getVideoInfo,
} = require('../config/cloudinary');
const fs = require('fs');
const path = require('path');

class VideoUploadService {
  constructor() {
    this.isConfigured = validateConfig();
    if (!this.isConfigured) {
      console.warn('VideoUploadService: Cloudinary not configured, uploads will fail');
    }
  }

  /**
   * Upload a video file and get streaming URLs
   * @param {string} filePath - Path to the video file
   * @param {object} options - Upload options
   * @returns {Promise<object>} - Upload result with streaming URLs
   */
  async uploadReel(filePath, options = {}) {
    if (!this.isConfigured) {
      throw new Error('Cloudinary is not configured');
    }

    const {
      userId,
      description = '',
      tags = [],
    } = options;

    try {
      console.log(`Uploading reel video: ${filePath}`);

      // Upload with reel preset
      const uploadResult = await cloudinary.uploader.upload(filePath, {
        ...VIDEO_PRESETS.reel,
        tags: ['reel', ...tags],
        context: {
          userId: userId,
          description: description.substring(0, 100),
        },
      });

      console.log(`Upload complete: ${uploadResult.public_id}`);

      // Generate streaming URLs
      const streamingUrls = getStreamingUrls(uploadResult.public_id);

      // Clean up local file if it exists
      if (fs.existsSync(filePath)) {
        fs.unlinkSync(filePath);
      }

      return {
        success: true,
        publicId: uploadResult.public_id,
        // Primary streaming URL (HLS for adaptive bitrate)
        mediaUrl: streamingUrls.hls,
        // Fallback URLs
        urls: {
          hls: streamingUrls.hls,
          mp4: streamingUrls.mp4,
          webm: streamingUrls.webm,
        },
        // Thumbnail and preview
        thumbnail: streamingUrls.thumbnail,
        preview: streamingUrls.preview,
        // Video metadata
        duration: uploadResult.duration,
        width: uploadResult.width,
        height: uploadResult.height,
        format: uploadResult.format,
        size: uploadResult.bytes,
        // Original URL (for compatibility)
        originalUrl: uploadResult.secure_url,
      };
    } catch (error) {
      console.error('Video upload error:', error);

      // Clean up local file on error
      if (fs.existsSync(filePath)) {
        fs.unlinkSync(filePath);
      }

      throw error;
    }
  }

  /**
   * Upload video from a URL (for migrating existing videos)
   * @param {string} videoUrl - URL of the video to upload
   * @param {object} options - Upload options
   */
  async uploadFromUrl(videoUrl, options = {}) {
    if (!this.isConfigured) {
      throw new Error('Cloudinary is not configured');
    }

    const { tags = [] } = options;

    try {
      console.log(`Uploading from URL: ${videoUrl}`);

      const uploadResult = await cloudinary.uploader.upload(videoUrl, {
        ...VIDEO_PRESETS.reel,
        tags: ['reel', 'migrated', ...tags],
      });

      const streamingUrls = getStreamingUrls(uploadResult.public_id);

      return {
        success: true,
        publicId: uploadResult.public_id,
        mediaUrl: streamingUrls.hls,
        urls: {
          hls: streamingUrls.hls,
          mp4: streamingUrls.mp4,
          webm: streamingUrls.webm,
        },
        thumbnail: streamingUrls.thumbnail,
        preview: streamingUrls.preview,
        duration: uploadResult.duration,
        width: uploadResult.width,
        height: uploadResult.height,
        originalUrl: uploadResult.secure_url,
      };
    } catch (error) {
      console.error('URL upload error:', error);
      throw error;
    }
  }

  /**
   * Upload a thumbnail image
   * @param {string} filePath - Path to the image file
   */
  async uploadThumbnail(filePath) {
    if (!this.isConfigured) {
      throw new Error('Cloudinary is not configured');
    }

    try {
      const uploadResult = await cloudinary.uploader.upload(filePath, {
        ...VIDEO_PRESETS.thumbnail,
      });

      // Clean up local file
      if (fs.existsSync(filePath)) {
        fs.unlinkSync(filePath);
      }

      return {
        success: true,
        publicId: uploadResult.public_id,
        url: uploadResult.secure_url,
        width: uploadResult.width,
        height: uploadResult.height,
      };
    } catch (error) {
      console.error('Thumbnail upload error:', error);
      if (fs.existsSync(filePath)) {
        fs.unlinkSync(filePath);
      }
      throw error;
    }
  }

  /**
   * Delete a video and its associated resources
   * @param {string} publicId - Cloudinary public ID
   */
  async deleteReel(publicId) {
    if (!this.isConfigured) {
      throw new Error('Cloudinary is not configured');
    }

    try {
      const result = await deleteVideo(publicId);
      return { success: true, result };
    } catch (error) {
      console.error('Delete error:', error);
      throw error;
    }
  }

  /**
   * Get video information
   * @param {string} publicId - Cloudinary public ID
   */
  async getVideoMetadata(publicId) {
    if (!this.isConfigured) {
      throw new Error('Cloudinary is not configured');
    }

    return await getVideoInfo(publicId);
  }

  /**
   * Generate signed upload URL for direct client uploads
   * @param {object} options - Upload options
   * @returns {object} - Signed upload parameters
   */
  generateUploadSignature(options = {}) {
    if (!this.isConfigured) {
      throw new Error('Cloudinary is not configured');
    }

    const timestamp = Math.round(new Date().getTime() / 1000);
    const folder = VIDEO_PRESETS.reel.folder;

    const params = {
      timestamp,
      folder,
      upload_preset: 'reel_upload', // You can create this in Cloudinary dashboard
      ...options,
    };

    const signature = cloudinary.utils.api_sign_request(
      params,
      process.env.CLOUDINARY_API_SECRET
    );

    return {
      signature,
      timestamp,
      cloudName: process.env.CLOUDINARY_CLOUD_NAME,
      apiKey: process.env.CLOUDINARY_API_KEY,
      folder,
    };
  }

  /**
   * Convert existing video URL to streaming format
   * This is useful for migrating old videos to HLS
   * @param {string} existingUrl - Current video URL
   */
  async migrateToStreaming(existingUrl) {
    if (!this.isConfigured) {
      throw new Error('Cloudinary is not configured');
    }

    // Check if already a Cloudinary URL
    if (existingUrl.includes('cloudinary.com')) {
      // Extract public ID and generate streaming URLs
      const publicIdMatch = existingUrl.match(/\/v\d+\/(.+?)(?:\.[^.]+)?$/);
      if (publicIdMatch) {
        const publicId = publicIdMatch[1];
        return {
          success: true,
          alreadyMigrated: true,
          ...getStreamingUrls(publicId),
        };
      }
    }

    // Upload from external URL
    return await this.uploadFromUrl(existingUrl);
  }

  /**
   * Check if Cloudinary is properly configured
   */
  isAvailable() {
    return this.isConfigured;
  }
}

// Export singleton instance
module.exports = new VideoUploadService();
