import 'package:dio/dio.dart';
import '../services/UserService.dart';
import '../services/api_service.dart';
import '../models/reel_model.dart';
import '../../core/constants/api_constants.dart';

class ReelRepository {
  final ApiService _apiService;
  final UserService _userService;

  ReelRepository(this._apiService, this._userService);

  Future<Map<String, dynamic>> getReels({int page = 1, int limit = 10}) async {
    final response = await _apiService.get(
      "/api/reels/reels",
      queryParameters: {'page': page, 'limit': limit},
    );
    return response.data;
  }

  Future<List<Map<String, dynamic>>> getTrendingTags() async {
    final response = await _apiService.get('/api/reels/reels/tags/trending');
    return List<Map<String, dynamic>>.from(response.data['data']);
  }

  Future<List<ReelModel>> getReelsByTag(String tagName) async {
    final response = await _apiService.get('/api/reels/reels/tags/$tagName');
    return (response.data['data'] as List)
        .map((reel) => ReelModel.fromJson(reel))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getComments(String reelId) async {
    try {
      final response =
          await _apiService.get('/api/reels/reels/$reelId/comments');

      if (response.data['status'] == 'success' &&
          response.data['data'] is List) {
        return List<Map<String, dynamic>>.from(response.data['data']);
      }
      return [];
    } catch (e) {
      // Debug log
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getTrendingReels() async {
    final response = await _apiService.get('/api/reels/reels/trending');
    return response.data;
  }

  Future<Map<String, dynamic>> addComment(String reelId, String content,
      {String? parentCommentId}) async {
    try {
      final userId = await _userService.getUserId();
      final firstName = await _userService.getFirstName();
      final lastName = await _userService.getLastName();
      final profilePhoto = await _userService.getImage();

      final data = {
        'userId': userId,
        'userName': '$firstName $lastName',
        'profilePhoto': profilePhoto,
        'content': content,
        'parentComment': parentCommentId,
        'depth': parentCommentId != null ? 1 : 0,
      };

      final response = await _apiService.post(
        '/api/reels/reels/$reelId/comments',
        data: data,
      );

      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> likeReel(String reelId) async {
    try {
      final userId = await _userService.getUserId();
      final firstName = await _userService.getFirstName();
      final lastName = await _userService.getLastName();
      final profilePhoto = await _userService.getImage();

      final data = {
        'userId': userId,
        'userName': '$firstName $lastName',
        'profilePhoto': profilePhoto ?? '',
      };

      final response = await _apiService.post(
        '/api/reels/reels/$reelId/like',
        data: data,
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to like reel: ${response.statusMessage}');
      }

      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> unlikeReel(String reelId) async {
    try {
      final userId = await _userService.getUserId();
      final data = {'userId': userId};

      final response = await _apiService.delete(
        '/api/reels/reels/$reelId/like',
        data: data,
      );

      return response.data;
    } catch (e) {
      rethrow;
    }
  }
}
