import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:krishimantra/data/services/api_service.dart';
import 'package:krishimantra/data/models/video_tutorial.dart';
import 'package:krishimantra/core/constants/api_constants.dart';
import '../../presentation/controllers/auth_controller.dart';

class VideoTutorialRepository {
  final ApiService _apiService;
  final AuthController _authController = Get.find<AuthController>();

  VideoTutorialRepository(this._apiService);

  Future<List<VideoTutorial>> getVideos({
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final response = await _apiService.get(
        '/api/reels/videos',
        queryParameters: {
          'page': page,
          'limit': limit,
        },
      );
      return (response.data['data']['data'] as List)
          .map((video) => VideoTutorial.fromJson(video))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch videos: $e');
    }
  }

  Future<VideoTutorial> getVideoById(String id) async {
    try {
      final response = await _apiService.get('/api/reels/videos/$id');

      if (response.data is Map &&
          response.data['status'] == 'success' &&
          response.data['data'] != null) {
        final videoData = response.data['data'];
        // Convert the data to Map<String, dynamic> to ensure type safety
        final Map<String, dynamic> videoMap = {
          ...Map<String, dynamic>.from(videoData),
          // Ensure nested objects are properly structured
          'likes': videoData['likes'] ?? {'count': 0, 'users': []},
          'views': videoData['views'] ?? {'count': 0, 'unique': []},
          'comments': videoData['comments'] ?? {'count': 0},
          // Convert tags to List<String> if it's a single string
          'tags': videoData['tags'] is String
              ? videoData['tags'].split(',').map((tag) => tag.trim()).toList()
              : List<String>.from(videoData['tags'] ?? []),
        };

        return VideoTutorial.fromJson(videoMap);
      }

      throw Exception('Invalid video data structure');
    } catch (e) {
      throw Exception('Failed to fetch video: $e');
    }
  }

  Future<List<VideoTutorial>> getRelatedVideos(String videoId,
      {int limit = 8}) async {
    try {
      final response = await _apiService.get(
        ApiConstants.VIDEO_TUTORIAL_RELATED.replaceAll(':id', videoId),
        queryParameters: {'limit': limit},
      );
      return (response.data['data'] as List)
          .map((video) => VideoTutorial.fromJson(video))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch related videos: $e');
    }
  }

  Future<void> toggleLike(String videoId) async {
    try {
      await _apiService
          .post(ApiConstants.VIDEO_TUTORIAL_LIKE.replaceAll(':id', videoId));
    } catch (e) {
      throw Exception('Failed to toggle like: $e');
    }
  }

  Future<Map<String, dynamic>> getComments(String videoId) async {
    try {
      final response =
          await _apiService.get('/api/reels/videos/$videoId/comments');
      return response.data;
    } catch (e) {
      throw Exception('Failed to fetch comments: $e');
    }
  }

  Future<Map<String, dynamic>> addComment(
    String videoId, {
    required String content,
    String? parentComment,
  }) async {
    try {
      final response = await _apiService.post(
        '/reels/videos/$videoId/comments',
        data: {
          'userId': _authController.user.value?.id,
          'userName': _authController.user.value?.name,
          'profilePhoto': _authController.user.value?.image,
          'content': content,
          if (parentComment != null) 'parentComment': parentComment,
        },
      );
      return response.data;
    } catch (e) {
      throw Exception('Failed to add comment: $e');
    }
  }

  Future<void> deleteComment(String commentId) async {
    try {
      await _apiService.delete('/reels/videos/comments/$commentId');
    } catch (e) {
      throw Exception('Failed to delete comment: $e');
    }
  }

  Future<void> toggleCommentLike(String commentId) async {
    try {
      await _apiService.post('/reels/videos/comments/$commentId/like');
    } catch (e) {
      throw Exception('Failed to toggle comment like: $e');
    }
  }

  Future<List<VideoTutorial>> searchVideos(
    String query, {
    int page = 1,
    int limit = 12,
    String sort = 'relevance',
  }) async {
    try {
      final response = await _apiService.get(
        '/api/reels/videos/search',
        queryParameters: {
          'q': query,
          'page': page,
          'limit': limit,
          'sort': sort,
        },
      );
      return (response.data['data'] as List)
          .map((video) => VideoTutorial.fromJson(video))
          .toList();
    } catch (e) {
      throw Exception('Failed to search videos: $e');
    }
  }
}
