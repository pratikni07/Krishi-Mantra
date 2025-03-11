const VideoTutorial = require("../models/VideoTutorial");
const redis = require("../config/redis");
const PaginationUtils = require("../utils/pagination");
const VideoComment = require("../models/VideoComment");

const CACHE_TTL = 3600; // 1 hour

class VideoTutorialService {
  static async createVideo(videoData) {
    try {
      const video = new VideoTutorial(videoData);
      await video.save();

      // Clear relevant cache
      await redis.del(`videos:category:${videoData.category}`);
      await redis.del(`videos:user:${videoData.userId}`);

      return video;
    } catch (error) {
      throw error;
    }
  }

  static async getVideos({ page = 1, limit = 12, category, sort = "recent" }) {
    const cacheKey = `videos:${category || "all"}:${sort}:${page}:${limit}`;
    const cachedData = await redis.get(cacheKey);

    if (cachedData) {
      return JSON.parse(cachedData);
    }

    const query = category ? { category } : {};
    const sortOptions = {
      recent: { createdAt: -1 },
      popular: { "views.count": -1 },
      trending: { "likes.count": -1 },
    };

    const [videos, total] = await Promise.all([
      VideoTutorial.find(query)
        .sort(sortOptions[sort])
        .skip((page - 1) * limit)
        .limit(limit)
        .lean(),
      VideoTutorial.countDocuments(query),
    ]);

    const result = PaginationUtils.formatPaginationResponse(
      videos,
      page,
      limit,
      total
    );

    await redis.setex(cacheKey, CACHE_TTL, JSON.stringify(result));
    return result;
  }

  static async getVideo(videoId, userId = null) {
    const video = await VideoTutorial.findById(videoId);
    
    if (!video) return null;

    if (userId && !video.views.unique.includes(userId)) {
      video.views.count += 1;
      video.views.unique.push(userId);
      await video.save();
    }

    return video;
  }

  static async updateVideo(videoId, userId, updateData) {
    const video = await VideoTutorial.findOne({ _id: videoId, userId });

    if (!video) {
      throw new Error("Video not found or unauthorized");
    }

    Object.assign(video, updateData);
    await video.save();

    // Clear relevant cache
    await redis.del(`videos:category:${video.category}`);
    await redis.del(`videos:user:${userId}`);

    return video;
  }

  static async deleteVideo(videoId, userId) {
    const video = await VideoTutorial.findOneAndDelete({ _id: videoId, userId });

    if (!video) {
      throw new Error("Video not found or unauthorized");
    }

    // Clear relevant cache
    await redis.del(`videos:category:${video.category}`);
    await redis.del(`videos:user:${userId}`);

    return true;
  }

  static async reportVideo(videoId, reportData) {
    const video = await VideoTutorial.findById(videoId);

    if (!video) {
      throw new Error("Video not found");
    }

    video.reports.push(reportData);
    await video.save();

    return true;
  }

  static async toggleLike(videoId, userId) {
    const video = await VideoTutorial.findById(videoId);

    if (!video) {
      throw new Error("Video not found");
    }

    const userLiked = video.likes.users.includes(userId);

    if (userLiked) {
      video.likes.count -= 1;
      video.likes.users = video.likes.users.filter(id => id !== userId);
    } else {
      video.likes.count += 1;
      video.likes.users.push(userId);
    }

    await video.save();

    // Clear relevant cache
    await redis.del(`videos:category:${video.category}`);

    return {
      liked: !userLiked,
      likesCount: video.likes.count,
    };
  }

  static async getRelatedVideos(videoId, limit = 8) {
    const video = await VideoTutorial.findById(videoId);

    if (!video) {
      throw new Error("Video not found");
    }

    const relatedVideos = await VideoTutorial.find({
      _id: { $ne: videoId },
      $or: [
        { category: video.category },
        { tags: { $in: video.tags } },
      ],
    })
      .sort({ "views.count": -1 })
      .limit(limit)
      .lean();

    return relatedVideos;
  }

  static async searchVideos({ query, page = 1, limit = 12, sort = "relevance" }) {
    const cacheKey = `videos:search:${query}:${sort}:${page}:${limit}`;
    const cachedData = await redis.get(cacheKey);

    if (cachedData) {
      return JSON.parse(cachedData);
    }

    const searchQuery = {
      $text: { $search: query },
    };

    const sortOptions = {
      relevance: { score: { $meta: "textScore" } },
      recent: { createdAt: -1 },
      views: { "views.count": -1 },
    };

    const [videos, total] = await Promise.all([
      VideoTutorial.find(searchQuery)
        .sort(sortOptions[sort])
        .skip((page - 1) * limit)
        .limit(limit)
        .lean(),
      VideoTutorial.countDocuments(searchQuery),
    ]);

    const result = PaginationUtils.formatPaginationResponse(
      videos,
      page,
      limit,
      total
    );

    await redis.setex(cacheKey, CACHE_TTL, JSON.stringify(result));
    return result;
  }

  static async addComment(videoId, commentData) {
    const video = await VideoTutorial.findById(videoId);
    if (!video) {
      throw new Error("Video not found");
    }

    const comment = new VideoComment({
      videoId,
      ...commentData,
    });

    if (commentData.parentComment) {
      const parentComment = await VideoComment.findById(commentData.parentComment);
      if (!parentComment) {
        throw new Error("Parent comment not found");
      }

      // Verify parent comment belongs to the same video
      if (parentComment.videoId.toString() !== videoId) {
        throw new Error("Parent comment does not belong to this video");
      }

      if (parentComment.depth >= 5) {
        throw new Error("Maximum comment depth reached");
      }

      comment.depth = parentComment.depth + 1;
      await comment.save();

      await VideoComment.findByIdAndUpdate(parentComment._id, {
        $push: { replies: comment._id }
      });
    } else {
      await comment.save();
      // Update video comment count
      await VideoTutorial.findByIdAndUpdate(videoId, {
        $inc: { "comments.count": 1 }
      });
    }

    // Clear cache
    await redis.del(`video:${videoId}:comments:*`);

    return VideoComment.findById(comment._id)
      .populate({
        path: "replies",
        match: { isDeleted: false },
        options: { sort: { createdAt: -1 } }
      });
  }

  static async getComments(videoId, { page, limit, parentComment }) {
    const query = {
      videoId,
      isDeleted: false,
      parentComment: parentComment || null
    };
    const [comments, total] = await Promise.all([
      VideoComment.find(query)
        .sort({ createdAt: -1 })
        .skip((page - 1) * limit)
        .limit(limit)
        .populate({
          path: "replies",
          match: { isDeleted: false },
          options: { sort: { createdAt: -1 } },
          populate: {
            path: "replies",
            match: { isDeleted: false },
            options: { sort: { createdAt: -1 } }
          }
        })
        .lean(),
      VideoComment.countDocuments(query)
    ]);

    const result = PaginationUtils.formatPaginationResponse(
      comments,
      page,
      limit,
      total
    );

    // await redis.setex(cacheKey, 1800, JSON.stringify(result)); // 30 minutes cache
    return result;
  }

  static async deleteComment(commentId, userId) {
    const comment = await VideoComment.findOne({
      _id: commentId,
      userId,
      isDeleted: false
    });

    if (!comment) {
      throw new Error("Comment not found or unauthorized");
    }

    // Soft delete
    comment.isDeleted = true;
    comment.content = "[deleted]";
    await comment.save();

    // If it's a top-level comment, update video comment count
    if (!comment.parentComment) {
      await VideoTutorial.findByIdAndUpdate(comment.videoId, {
        $inc: { "comments.count": -1 }
      });
    }

    // Clear cache
    await redis.del(`video:${comment.videoId}:comments:*`);

    return true;
  }

  static async toggleCommentLike(commentId, userId) {
    const comment = await VideoComment.findById(commentId);

    if (!comment || comment.isDeleted) {
      throw new Error("Comment not found");
    }

    const userLiked = comment.likes.users.includes(userId);

    if (userLiked) {
      comment.likes.count -= 1;
      comment.likes.users = comment.likes.users.filter(id => id !== userId);
    } else {
      comment.likes.count += 1;
      comment.likes.users.push(userId);
    }

    await comment.save();

    // Clear cache
    await redis.del(`video:${comment.videoId}:comments:*`);

    return {
      liked: !userLiked,
      likesCount: comment.likes.count
    };
  }
}

module.exports = VideoTutorialService; 