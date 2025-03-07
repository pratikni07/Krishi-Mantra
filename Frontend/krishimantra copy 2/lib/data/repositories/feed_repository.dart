import 'package:dio/dio.dart';
import '../models/feed_model.dart';
import '../models/comment_modal.dart';
import '../services/api_service.dart';
import '../../core/utils/api_helper.dart';

class FeedRepository {
  final ApiService _apiService;

  FeedRepository(this._apiService);

  Future<Map<String, dynamic>> getFeeds({int page = 1, int limit = 10}) async {
    try {
      final response = await _apiService.get(
        '/api/feed/feeds',
        queryParameters: {'page': page, 'limit': limit},
      );

      final data = ApiHelper.handleResponse(response);
      final List<FeedModel> feeds = (data['feeds'] as List)
          .map((feed) => FeedModel.fromJson(feed))
          .toList();

      return {
        'feeds': feeds,
        'pagination': data['pagination'],
      };
    } catch (e) {
      throw ApiHelper.handleError(e);
    }
  }

  // Get feed by ID with comments
  Future<FeedModel> getFeedById(String feedId,
      {int page = 1, int limit = 10}) async {
    try {
      final response = await _apiService.get(
        '/api/feed/feeds/$feedId',
        queryParameters: {'page': page, 'limit': limit},
      );

      final data = ApiHelper.handleResponse(response);
      return FeedModel.fromJson(data['feed']);
    } catch (e) {
      throw ApiHelper.handleError(e);
    }
  }

  // Add like to feed
  Future<bool> addLike(String feedId, Map<String, dynamic> userData) async {
    try {
      final response = await _apiService.post(
        '/api/feed/feeds/$feedId/like',
        data: userData,
      );

      final data = ApiHelper.handleResponse(response);
      return data['success'] ?? false;
    } catch (e) {
      throw ApiHelper.handleError(e);
    }
  }

  // Add comment to feed
  Future<Map<String, dynamic>> addComment(
      String feedId, Map<String, dynamic> commentData) async {
    try {
      // Validate required fields
      if (!commentData.containsKey('userId') ||
          !commentData.containsKey('userName') ||
          !commentData.containsKey('content')) {
        throw Exception('Missing required comment data');
      }

      final response = await _apiService.post(
        '/api/feed/feeds/$feedId/comment',
        data: commentData,
      );

      return ApiHelper.handleResponse(response);
    } catch (e) {
      throw ApiHelper.handleError(e);
    }
  }

  // Get comments for a feed
  Future<Map<String, dynamic>> getComments(String feedId,
      {int page = 1, int limit = 10}) async {
    try {
      final response = await _apiService.get(
        '/api/feed/comments/getComment',
        queryParameters: {
          'feedId': feedId,
          'page': page,
          'limit': limit,
        },
      );
      print(feedId);
      print(response);

      final data = ApiHelper.handleResponse(response);
      final List<CommentModel> comments = (data['docs'] as List)
          .map((comment) => CommentModel.fromJson(comment))
          .toList();

      return {
        'comments': comments,
        'totalDocs': data['totalDocs'] ?? 0,
        'limit': data['limit'] ?? 10,
        'totalPages': data['totalPages'] ?? 1,
        'page': data['page'] ?? 1,
        'pagingCounter': data['pagingCounter'] ?? 1,
        'hasPrevPage': data['hasPrevPage'] ?? false,
        'hasNextPage': data['hasNextPage'] ?? false,
        'prevPage': data['prevPage'],
        'nextPage': data['nextPage'],
      };
    } catch (e) {
      throw ApiHelper.handleError(e);
    }
  }

  // Get random feeds
  Future<Map<String, dynamic>> getRandomFeeds(
      {int page = 1, int limit = 10}) async {
    try {
      final response = await _apiService.get(
        '/api/feed/feeds/feeds/random',
        queryParameters: {'page': page, 'limit': limit},
      );

      final data = ApiHelper.handleResponse(response);
      final List<FeedModel> feeds = (data['feeds'] as List)
          .map((feed) => FeedModel.fromJson(feed))
          .toList();

      return {
        'feeds': feeds,
        'pagination': data['pagination'],
      };
    } catch (e) {
      throw ApiHelper.handleError(e);
    }
  }

  // Get recommended feeds for user
  Future<Map<String, dynamic>> getRecommendedFeeds(String userId,
      {int page = 1, int limit = 10}) async {
    try {
      final response = await _apiService.get(
        '/api/feed/feeds/user/$userId/recommended',
        queryParameters: {'page': page, 'limit': limit},
      );

      final data = ApiHelper.handleResponse(response);
      final List<FeedModel> feeds = (data['feeds'] as List)
          .map((feed) => FeedModel.fromJson(feed))
          .toList();

      return {
        'feeds': feeds,
        'pagination': data['pagination'],
        'recommendationType': data['recommendationType'],
      };
    } catch (e) {
      throw ApiHelper.handleError(e);
    }
  }

  // Create new feed
  Future<FeedModel> createFeed(Map<String, dynamic> feedData) async {
    try {
      final response = await _apiService.post(
        '/api/feed/feeds',
        data: feedData,
      );

      final data = ApiHelper.handleResponse(response);
      return FeedModel.fromJson(data);
    } catch (e) {
      throw ApiHelper.handleError(e);
    }
  }

  Future<List<FeedModel>> getTopFeeds() async {
    try {
      final response = await _apiService.get('/api/feed/feeds/getoptwo');
      final data = ApiHelper.handleResponse(response);
      
      final List<FeedModel> feeds = (data['data'] as List)
          .map((feed) => FeedModel.fromJson(feed))
          .toList();

      return feeds;
    } catch (e) {
      throw ApiHelper.handleError(e);
    }
  }
}
