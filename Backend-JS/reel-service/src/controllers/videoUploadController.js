const videoUploadService = require('../services/videoUploadService');
const ReelService = require('../services/reelService');
const catchAsync = require('../utils/catchAsync');

class VideoUploadController {
  /**
   * Upload a new reel video
   * POST /api/reels/upload
   */
  static uploadReel = catchAsync(async (req, res) => {
    if (!req.file) {
      return res.status(400).json({
        status: 'error',
        message: 'No video file provided',
      });
    }

    const { userId, userName, profilePhoto, description, location } = req.body;

    if (!userId || !userName) {
      return res.status(400).json({
        status: 'error',
        message: 'userId and userName are required',
      });
    }

    // Check if Cloudinary is available
    if (!videoUploadService.isAvailable()) {
      return res.status(503).json({
        status: 'error',
        message: 'Video upload service is not configured',
      });
    }

    // Extract tags from description
    const tags = (description || '').match(/#\w+/g)?.map(tag => tag.slice(1).toLowerCase()) || [];

    // Upload video to Cloudinary
    const uploadResult = await videoUploadService.uploadReel(req.file.path, {
      userId,
      description,
      tags,
    });

    // Parse location if provided
    let locationData = undefined;
    if (location) {
      try {
        const loc = typeof location === 'string' ? JSON.parse(location) : location;
        if (loc.latitude && loc.longitude) {
          locationData = {
            type: 'Point',
            coordinates: [loc.longitude, loc.latitude],
          };
        }
      } catch (e) {
        console.warn('Invalid location data:', e.message);
      }
    }

    // Create reel in database
    const reel = await ReelService.createReel({
      userId,
      userName,
      profilePhoto: profilePhoto || '',
      description: description || '',
      mediaUrl: uploadResult.mediaUrl, // HLS streaming URL
      videoUrls: uploadResult.urls,
      cloudinaryId: uploadResult.publicId,
      thumbnail: uploadResult.thumbnail,
      preview: uploadResult.preview,
      videoMeta: {
        duration: uploadResult.duration,
        width: uploadResult.width,
        height: uploadResult.height,
        size: uploadResult.size,
        format: uploadResult.format,
      },
      location: locationData,
      tags,
    });

    res.status(201).json({
      status: 'success',
      message: 'Reel uploaded successfully',
      data: {
        reel,
        streaming: {
          hls: uploadResult.urls.hls,
          mp4: uploadResult.urls.mp4,
        },
      },
    });
  });

  /**
   * Finalize a direct-to-Cloudinary upload. Client uploads bytes straight
   * to Cloudinary using a signed upload, then calls this with the public
   * ID. We look the video up, verify it's in the expected folder, and
   * create the DB record — no video bytes flow through this service.
   * POST /api/reels/upload/complete
   */
  static completeUpload = catchAsync(async (req, res) => {
    const { publicId, userId, userName, profilePhoto, description, location } = req.body;

    if (!publicId) {
      return res.status(400).json({ status: 'error', message: 'publicId is required' });
    }
    if (!userId || !userName) {
      return res.status(400).json({ status: 'error', message: 'userId and userName are required' });
    }
    if (!videoUploadService.isAvailable()) {
      return res.status(503).json({ status: 'error', message: 'Video upload service is not configured' });
    }

    let meta;
    try {
      meta = await videoUploadService.verifyAndGetMetadata(publicId);
    } catch (err) {
      return res
        .status(err.statusCode || 500)
        .json({ status: 'error', message: err.message });
    }

    const tags = (description || '').match(/#\w+/g)?.map(t => t.slice(1).toLowerCase()) || [];

    let locationData;
    if (location) {
      try {
        const loc = typeof location === 'string' ? JSON.parse(location) : location;
        if (loc.latitude && loc.longitude) {
          locationData = { type: 'Point', coordinates: [loc.longitude, loc.latitude] };
        }
      } catch (e) {
        console.warn('Invalid location data:', e.message);
      }
    }

    const reel = await ReelService.createReel({
      userId,
      userName,
      profilePhoto: profilePhoto || '',
      description: description || '',
      mediaUrl: meta.mediaUrl,
      videoUrls: meta.urls,
      cloudinaryId: meta.publicId,
      thumbnail: meta.thumbnail,
      preview: meta.preview,
      videoMeta: {
        duration: meta.duration,
        width: meta.width,
        height: meta.height,
        size: meta.size,
        format: meta.format,
      },
      location: locationData,
      tags,
    });

    res.status(201).json({
      status: 'success',
      message: 'Reel created from direct upload',
      data: {
        reel,
        streaming: { hls: meta.urls.hls, mp4: meta.urls.mp4 },
      },
    });
  });

  /**
   * Get signed upload URL for direct client upload
   * GET /api/reels/upload/signature
   */
  static getUploadSignature = catchAsync(async (req, res) => {
    if (!videoUploadService.isAvailable()) {
      return res.status(503).json({
        status: 'error',
        message: 'Video upload service is not configured',
      });
    }

    const signature = videoUploadService.generateUploadSignature();

    res.json({
      status: 'success',
      data: signature,
    });
  });

  /**
   * Migrate existing video to streaming format
   * POST /api/reels/:id/migrate
   */
  static migrateVideo = catchAsync(async (req, res) => {
    const { id } = req.params;

    if (!videoUploadService.isAvailable()) {
      return res.status(503).json({
        status: 'error',
        message: 'Video upload service is not configured',
      });
    }

    // Get current reel
    const Reel = require('../models/Reel');
    const reel = await Reel.findById(id);

    if (!reel) {
      return res.status(404).json({
        status: 'error',
        message: 'Reel not found',
      });
    }

    // Check if already migrated
    if (reel.cloudinaryId) {
      return res.json({
        status: 'success',
        message: 'Reel already migrated to streaming',
        data: {
          mediaUrl: reel.mediaUrl,
          videoUrls: reel.videoUrls,
        },
      });
    }

    // Migrate to Cloudinary
    const result = await videoUploadService.migrateToStreaming(reel.mediaUrl);

    // Update reel
    reel.mediaUrl = result.hls || result.mediaUrl;
    reel.videoUrls = {
      hls: result.hls,
      mp4: result.mp4,
      webm: result.webm,
    };
    reel.cloudinaryId = result.publicId;
    reel.thumbnail = result.thumbnail || reel.thumbnail;
    reel.preview = result.preview;

    await reel.save();

    res.json({
      status: 'success',
      message: 'Video migrated to streaming format',
      data: {
        mediaUrl: reel.mediaUrl,
        videoUrls: reel.videoUrls,
        thumbnail: reel.thumbnail,
      },
    });
  });

  /**
   * Batch migrate all reels to streaming format
   * POST /api/reels/migrate-all
   */
  static migrateAllVideos = catchAsync(async (req, res) => {
    if (!videoUploadService.isAvailable()) {
      return res.status(503).json({
        status: 'error',
        message: 'Video upload service is not configured',
      });
    }

    const Reel = require('../models/Reel');
    const { limit = 10 } = req.query;

    // Find reels that haven't been migrated
    const reels = await Reel.find({
      cloudinaryId: { $exists: false },
      isActive: true,
    }).limit(parseInt(limit));

    const results = {
      total: reels.length,
      success: 0,
      failed: 0,
      errors: [],
    };

    for (const reel of reels) {
      try {
        const result = await videoUploadService.migrateToStreaming(reel.mediaUrl);

        reel.mediaUrl = result.hls || result.mediaUrl;
        reel.videoUrls = {
          hls: result.hls,
          mp4: result.mp4,
          webm: result.webm,
        };
        reel.cloudinaryId = result.publicId;
        reel.thumbnail = result.thumbnail || reel.thumbnail;
        reel.preview = result.preview;

        await reel.save();
        results.success++;
      } catch (error) {
        results.failed++;
        results.errors.push({
          reelId: reel._id,
          error: error.message,
        });
      }
    }

    res.json({
      status: 'success',
      message: 'Migration complete',
      data: results,
    });
  });

  /**
   * Delete a reel and its video from Cloudinary
   * DELETE /api/reels/:id/video
   */
  static deleteReelVideo = catchAsync(async (req, res) => {
    const { id } = req.params;
    const { userId } = req.body;

    const Reel = require('../models/Reel');
    const reel = await Reel.findById(id);

    if (!reel) {
      return res.status(404).json({
        status: 'error',
        message: 'Reel not found',
      });
    }

    // Verify ownership
    if (reel.userId !== userId) {
      return res.status(403).json({
        status: 'error',
        message: 'Not authorized to delete this reel',
      });
    }

    // Delete from Cloudinary if exists
    if (reel.cloudinaryId && videoUploadService.isAvailable()) {
      try {
        await videoUploadService.deleteReel(reel.cloudinaryId);
      } catch (error) {
        console.warn('Cloudinary delete error:', error.message);
      }
    }

    // Delete reel from database
    await Reel.findByIdAndDelete(id);

    res.json({
      status: 'success',
      message: 'Reel deleted successfully',
    });
  });

  /**
   * Check video upload service status
   * GET /api/reels/upload/status
   */
  static checkStatus = catchAsync(async (req, res) => {
    res.json({
      status: 'success',
      data: {
        configured: videoUploadService.isAvailable(),
        cloudName: process.env.CLOUDINARY_CLOUD_NAME ? '***configured***' : null,
      },
    });
  });
}

module.exports = VideoUploadController;
