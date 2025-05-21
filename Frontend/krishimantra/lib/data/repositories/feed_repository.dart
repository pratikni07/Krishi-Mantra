import '../models/feed_model.dart';
import '../models/comment_modal.dart';
import '../services/api_service.dart';
import '../../core/utils/api_helper.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../../core/constants/api_constants.dart';
import '../services/UserService.dart';

class FeedRepository {
  final ApiService _apiService;

  FeedRepository(this._apiService);

  Future<List<FeedModel>> getFeeds(
      {required int page,
      required int limit,
      String? searchTerm,
      String? category,
      CancelToken? cancelToken}) async {
    try {
      final params = {
        'page': page,
        'limit': limit,
        if (searchTerm != null && searchTerm.isNotEmpty) 'search': searchTerm,
        if (category != null && category.isNotEmpty) 'category': category,
      };

      // Use caching with maxAge and a long maxStale to serve stale content when offline
      final response = await _apiService.get(
        '/api/feed/feeds',
        queryParameters: params,
        options: Options(extra: {'cancelToken': cancelToken}),
        cacheDuration: const Duration(minutes: 15),
      );

      final List<dynamic> feedsData = response.data['feeds'] ?? [];
      return feedsData.map((json) => FeedModel.fromJson(json)).toList();
    } catch (e) {
      // Log the error but don't re-throw it at this level
      print('Error fetching feeds: $e');

      // Try to get cached data directly if the request fails
      try {
        final cacheResponse = await _apiService
            .getCachedResponse(ApiConstants.FEEDS, queryParameters: {
          'page': page,
          'limit': limit,
          if (searchTerm != null && searchTerm.isNotEmpty) 'search': searchTerm,
          if (category != null && category.isNotEmpty) 'category': category,
        });

        if (cacheResponse != null) {
          final List<dynamic> feedsData = cacheResponse.data['feeds'] ?? [];
          return feedsData.map((json) => FeedModel.fromJson(json)).toList();
        }
      } catch (cacheError) {
        print('Error fetching from cache: $cacheError');
      }

      // If no cached data available, return empty list instead of throwing error
      return [];
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
      print(
          '🔍 Repository: Fetching comments for feedId: $feedId, page: $page, limit: $limit');

      final response = await _apiService.get(
        '/api/feed/comments/getComment',
        queryParameters: {
          'feedId': feedId,
          'page': page,
          'limit': limit,
        },
      );

      print('📊 Repository: Raw API response: ${response.data}');
      final data = ApiHelper.handleResponse(response);
      print('📄 Repository: Parsed response data: $data');

      // Verify the response structure
      if (data == null) {
        print('⚠️ Repository: Received null data from API');
        throw Exception('Invalid response: null data');
      }

      // Check for the "No comments found" response format
      if (data.containsKey('message') && data.containsKey('comments')) {
        print(
            'ℹ️ Repository: Using alternate response format (message + comments)');
        final List<CommentModel> comments = [];

        // Only try to parse comments if they exist and are not empty
        if (data['comments'] is List && (data['comments'] as List).isNotEmpty) {
          comments.addAll((data['comments'] as List)
              .map((comment) => CommentModel.fromJson(comment))
              .toList());
        }

        return {
          'comments': comments,
          'totalDocs': 0,
          'limit': limit,
          'totalPages': 1,
          'page': page,
          'pagingCounter': 1,
          'hasPrevPage': false,
          'hasNextPage': false,
          'prevPage': null,
          'nextPage': null,
        };
      }

      // Original format check for "docs" field
      if (!data.containsKey('docs')) {
        print('⚠️ Repository: Response missing "docs" field: ${data.keys}');
        throw Exception('Invalid response format: missing docs');
      }

      if (!(data['docs'] is List)) {
        print(
            '⚠️ Repository: "docs" is not a list: ${data['docs'].runtimeType}');
        throw Exception('Invalid response format: docs is not a list');
      }

      final List<CommentModel> comments = (data['docs'] as List)
          .map((comment) => CommentModel.fromJson(comment))
          .toList();

      print('✅ Repository: Successfully parsed ${comments.length} comments');

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
      print('❌ Repository: Error fetching comments: $e');
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

      // Handle the nested structure: the feeds are inside data.feeds
      final feedsData =
          data['data'] != null ? data['data']['feeds'] : data['feeds'];

      if (feedsData == null) {
        // Return empty result if no feeds are found
        return {
          'feeds': <FeedModel>[],
          'pagination': {'hasMore': false},
          'recommendationType': null
        };
      }

      final List<FeedModel> feeds =
          (feedsData as List).map((feed) => FeedModel.fromJson(feed)).toList();

      final pagination = data['data'] != null
          ? data['data']['pagination']
          : data['pagination'];
      final recommendationType = data['data'] != null
          ? data['data']['recommendationType']
          : data['recommendationType'];

      return {
        'feeds': feeds,
        'pagination': pagination ?? {'hasMore': false},
        'recommendationType': recommendationType,
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

  Future<List<Map<String, dynamic>>> getTrendingHashtags() async {
    try {
      final response =
          await _apiService.get('/api/feed/feeds/trending/hashtags');
      final data = ApiHelper.handleResponse(response);
      return (data['data']['trendingTags'] as List)
          .cast<Map<String, dynamic>>();
    } catch (e) {
      throw ApiHelper.handleError(e);
    }
  }

  Future<Map<String, dynamic>> getFeedsByTag(String tagName,
      {int page = 1, int limit = 10}) async {
    try {
      final response = await _apiService.get(
        '/api/feed/feeds/tag/$tagName/feeds',
        queryParameters: {'page': page, 'limit': limit},
      );

      final data = ApiHelper.handleResponse(response);

      // Check if data exists and handle different response structures
      final feedsData = data['data'] != null && data['data']['feeds'] != null
          ? data['data']['feeds']
          : (data['feeds'] ?? []);

      final List<FeedModel> feeds =
          (feedsData as List).map((feed) => FeedModel.fromJson(feed)).toList();

      final pagination =
          data['data'] != null && data['data']['pagination'] != null
              ? data['data']['pagination']
              : (data['pagination'] ?? {'hasMore': false});

      final tag = data['data'] != null && data['data']['tag'] != null
          ? data['data']['tag']
          : data['tag'];

      return {
        'feeds': feeds,
        'pagination': pagination,
        'tag': tag,
      };
    } catch (e) {
      throw ApiHelper.handleError(e);
    }
  }
}
