const cloudinary = require('cloudinary').v2;

// Configure Cloudinary
cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET,
  secure: true,
});

/**
 * Validate Cloudinary configuration
 */
const validateConfig = () => {
  const required = ['CLOUDINARY_CLOUD_NAME', 'CLOUDINARY_API_KEY', 'CLOUDINARY_API_SECRET'];
  const missing = required.filter(key => !process.env[key]);

  if (missing.length > 0) {
    console.warn(`Cloudinary config missing: ${missing.join(', ')}`);
    return false;
  }
  return true;
};

/**
 * Video upload presets for different quality levels
 * Optimized for Instagram-like streaming experience
 */
const VIDEO_PRESETS = {
  // For reels - short videos optimized for mobile with adaptive bitrate
  reel: {
    resource_type: 'video',
    folder: 'krishimantra/reels',
    // Enable HLS streaming with multiple quality levels (adaptive bitrate)
    // This creates m3u8 playlist with different quality segments
    eager: [
      // HD streaming (720p) - default for most devices
      { streaming_profile: 'hd', format: 'm3u8' },
    ],
    eager_async: true, // Process in background for faster upload response
    eager_notification_url: process.env.CLOUDINARY_WEBHOOK_URL || null,
    // Video transformations for optimization
    transformation: [
      // Auto quality optimization - Cloudinary selects best quality/size ratio
      { quality: 'auto:good', fetch_format: 'auto' },
      // Max resolution for reels (9:16 portrait)
      { width: 1080, height: 1920, crop: 'limit' },
      // Video codec optimization for mobile compatibility
      { video_codec: 'h264:main:3.1' },
      // Audio optimization
      { audio_codec: 'aac', audio_frequency: 44100 },
    ],
    // Additional options
    use_filename: true,
    unique_filename: true,
    overwrite: false,
    // Video-specific settings
    chunk_size: 6000000, // 6MB chunks for large uploads
  },

  // For thumbnails
  thumbnail: {
    resource_type: 'image',
    folder: 'krishimantra/thumbnails',
    transformation: [
      { width: 540, height: 960, crop: 'fill', gravity: 'auto' },
      { quality: 'auto:good', fetch_format: 'auto' },
    ],
    use_filename: true,
    unique_filename: true,
  },

  // For longer video tutorials
  tutorial: {
    resource_type: 'video',
    folder: 'krishimantra/tutorials',
    eager: [
      { streaming_profile: 'full_hd', format: 'm3u8' },
    ],
    eager_async: true,
    transformation: [
      { quality: 'auto:good', fetch_format: 'auto' },
      { width: 1920, height: 1080, crop: 'limit' },
    ],
    chunk_size: 10000000, // 10MB chunks
  },
};

/**
 * Generate HLS streaming URL from a Cloudinary video
 * @param {string} publicId - The video's public ID in Cloudinary
 * @param {object} options - Additional options
 * @returns {object} - URLs for different streaming formats
 */
const getStreamingUrls = (publicId, options = {}) => {
  const { quality = 'auto' } = options;

  return {
    // HLS streaming URL (adaptive bitrate)
    hls: cloudinary.url(publicId, {
      resource_type: 'video',
      format: 'm3u8',
      streaming_profile: 'hd',
    }),

    // Direct MP4 URL (fallback)
    mp4: cloudinary.url(publicId, {
      resource_type: 'video',
      format: 'mp4',
      quality: quality,
    }),

    // WebM format (better compression)
    webm: cloudinary.url(publicId, {
      resource_type: 'video',
      format: 'webm',
      quality: quality,
    }),

    // Thumbnail/poster image
    thumbnail: cloudinary.url(publicId, {
      resource_type: 'video',
      format: 'jpg',
      transformation: [
        { width: 540, height: 960, crop: 'fill', gravity: 'auto' },
        { quality: 'auto:good' },
        { start_offset: '0' }, // First frame
      ],
    }),

    // Animated preview (like Instagram)
    preview: cloudinary.url(publicId, {
      resource_type: 'video',
      format: 'gif',
      transformation: [
        { width: 270, height: 480, crop: 'fill' },
        { quality: 'auto:low' },
        { duration: 3, start_offset: '0' }, // 3 second preview
      ],
    }),
  };
};

/**
 * Generate optimized video URL with transformations
 * @param {string} publicId - The video's public ID
 * @param {object} options - Transformation options
 */
const getOptimizedVideoUrl = (publicId, options = {}) => {
  const {
    width = 1080,
    height = 1920,
    quality = 'auto:good',
    format = 'mp4',
  } = options;

  return cloudinary.url(publicId, {
    resource_type: 'video',
    format: format,
    transformation: [
      { width, height, crop: 'limit' },
      { quality },
      { fetch_format: 'auto' },
    ],
  });
};

/**
 * Delete a video from Cloudinary
 * @param {string} publicId - The video's public ID
 */
const deleteVideo = async (publicId) => {
  try {
    const result = await cloudinary.uploader.destroy(publicId, {
      resource_type: 'video',
    });
    return result;
  } catch (error) {
    console.error('Cloudinary delete error:', error);
    throw error;
  }
};

/**
 * Get video metadata/info
 * @param {string} publicId - The video's public ID
 */
const getVideoInfo = async (publicId) => {
  try {
    const result = await cloudinary.api.resource(publicId, {
      resource_type: 'video',
      image_metadata: true,
    });
    return {
      duration: result.duration,
      width: result.width,
      height: result.height,
      format: result.format,
      size: result.bytes,
      createdAt: result.created_at,
      url: result.secure_url,
    };
  } catch (error) {
    console.error('Cloudinary info error:', error);
    throw error;
  }
};

module.exports = {
  cloudinary,
  validateConfig,
  VIDEO_PRESETS,
  getStreamingUrls,
  getOptimizedVideoUrl,
  deleteVideo,
  getVideoInfo,
};
