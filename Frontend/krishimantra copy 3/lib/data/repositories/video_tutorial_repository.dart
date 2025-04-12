// ignore_for_file: unused_field

import 'package:get/get.dart';
import 'package:krishimantra/data/services/api_service.dart';
import 'package:krishimantra/data/models/video_tutorial.dart';
import 'package:krishimantra/core/constants/api_constants.dart';
import '../../presentation/controllers/auth_controller.dart';
import '../services/UserService.dart';

class VideoTutorialRepository {
  final ApiService _apiService;
  final AuthController _authController = Get.find<AuthController>();
  final UserService _userService = Get.find<UserService>();

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

  Future<Map<String, dynamic>> getVideoById(String videoId) async {
    try {
      final userId = await _userService.getUserId();

      final response = await _apiService.get(
        '/api/reels/videos/$videoId',
        queryParameters: userId != null ? {'userId': userId} : {},
      );

      if (response.data['status'] == 'success' &&
          response.data['data'] != null) {
        return response.data['data'];
      } else {
        throw Exception('Failed to get video details');
      }
    } catch (e) {
      print('Error getting video by ID: $e');
      rethrow;
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

  Future<Map<String, dynamic>> toggleLike(String videoId) async {
    try {
      final userId = await _userService.getUserId();
      if (userId == null) {
        throw Exception('User ID is null');
      }

      final response = await _apiService.post(
        '/api/reels/videos/$videoId/like',
        data: {
          'userId': userId,
          'userName':
              '${await _userService.getFirstName()} ${await _userService.getLastName() ?? ''}',
          'profilePhoto': await _userService.getImage(),
        },
      );
      return response.data;
    } catch (e) {
      print('Error in toggleLike: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getComments(
    String videoId, {
    int page = 1,
    int limit = 10,
    String? parentComment,
  }) async {
    try {
      final queryParams = {
        'page': page,
        'limit': limit,
      };

      if (parentComment != null) {
        queryParams['parentComment'] = parentComment as int;
      }

      final response = await _apiService.get(
        '/api/reels/videos/$videoId/comments',
        queryParameters: queryParams,
      );

      return response.data;
    } catch (e) {
      throw Exception('Failed to fetch comments: $e');
    }
  }

  Future<Map<String, dynamic>> addComment(
    String videoId,
    Map<String, dynamic> commentData,
  ) async {
    try {
      final response = await _apiService.post(
        '/api/reels/videos/$videoId/comments',
        data: commentData,
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
