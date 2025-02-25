const VideoTutorialService = require("../services/videoTutorialService");
const catchAsync = require("../utils/catchAsync");

class VideoTutorialController {
  static createVideo = catchAsync(async (req, res) => {
    const {
      userId,
      userName,
      profilePhoto,
      title,
      description,
      thumbnail,
      videoUrl,
      videoType,
      duration,
      tags,
      category,
      visibility,
    } = req.body;

    const video = await VideoTutorialService.createVideo({
      userId,
      userName,
      profilePhoto,
      title,
      description,
      thumbnail,
      videoUrl,
      videoType,
      duration,
      tags,
      category,
      visibility,
    });

    res.status(201).json({
      status: "success",
      data: video,
    });
  });

  static getVideos = catchAsync(async (req, res) => {
    const { page = 1, limit = 12, category, sort = "recent" } = req.query;
    
    const videos = await VideoTutorialService.getVideos({
      page: parseInt(page),
      limit: parseInt(limit),
      category,
      sort,
    });

    res.json({
      status: "success",
      data: videos,
    });
  });

  static getVideo = catchAsync(async (req, res) => {
    const { id } = req.params;
    const { userId } = req.query; // Optional: for tracking unique views

    const video = await VideoTutorialService.getVideo(id, userId);

    if (!video) {
      return res.status(404).json({
        status: "error",
        message: "Video not found",
      });
    }

    res.json({
      status: "success",
      data: video,
    });
  });

  static updateVideo = catchAsync(async (req, res) => {
    const { id } = req.params;
    const { userId } = req.body;
    const updateData = req.body;

    const video = await VideoTutorialService.updateVideo(id, userId, updateData);

    res.json({
      status: "success",
      data: video,
    });
  });

  static deleteVideo = catchAsync(async (req, res) => {
    const { id } = req.params;
    const { userId } = req.body;

    await VideoTutorialService.deleteVideo(id, userId);

    res.json({
      status: "success",
      message: "Video deleted successfully",
    });
  });

  static reportVideo = catchAsync(async (req, res) => {
    const { id } = req.params;
    const { userId, reason, description } = req.body;

    await VideoTutorialService.reportVideo(id, {
      userId,
      reason,
      description,
    });

    res.json({
      status: "success",
      message: "Video reported successfully",
    });
  });

  static toggleLike = catchAsync(async (req, res) => {
    const { id } = req.params;
    const { userId } = req.body;

    const result = await VideoTutorialService.toggleLike(id, userId);

    res.json({
      status: "success",
      data: result,
    });
  });

  static getRelatedVideos = catchAsync(async (req, res) => {
    const { id } = req.params;
    const { limit = 8 } = req.query;

    const videos = await VideoTutorialService.getRelatedVideos(id, parseInt(limit));

    res.json({
      status: "success",
      data: videos,
    });
  });

  static searchVideos = catchAsync(async (req, res) => {
    const { q, page = 1, limit = 12, sort = "relevance" } = req.query;

    if (!q) {
      return res.status(400).json({
        status: "error",
        message: "Search query is required",
      });
    }

    const videos = await VideoTutorialService.searchVideos({
      query: q,
      page: parseInt(page),
      limit: parseInt(limit),
      sort,
    });

    res.json({
      status: "success",
      data: videos,
    });
  });

  static addComment = catchAsync(async (req, res) => {
    const { videoId } = req.params;
    const { userId, userName, profilePhoto, content, parentComment } = req.body;

    const comment = await VideoTutorialService.addComment(videoId, {
      userId,
      userName,
      profilePhoto,
      content,
      parentComment,
    });

    res.status(201).json({
      status: "success",
      data: comment,
    });
  });

  static getComments = catchAsync(async (req, res) => {
    const { videoId } = req.params;
    const { page = 1, limit = 10, parentComment = null } = req.query;

    const comments = await VideoTutorialService.getComments(videoId, {
      page: parseInt(page),
      limit: parseInt(limit),
      parentComment,
    });

    res.json({
      status: "success",
      data: comments,
    });
  });

  static deleteComment = catchAsync(async (req, res) => {
    const { commentId } = req.params;
    const { userId } = req.body;

    await VideoTutorialService.deleteComment(commentId, userId);

    res.json({
      status: "success",
      message: "Comment deleted successfully",
    });
  });

  static toggleCommentLike = catchAsync(async (req, res) => {
    const { commentId } = req.params;
    const { userId } = req.body;

    const result = await VideoTutorialService.toggleCommentLike(commentId, userId);

    res.json({
      status: "success",
      data: result,
    });
  });
}

module.exports = VideoTutorialController; 