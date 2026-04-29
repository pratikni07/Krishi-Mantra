import 'dart:io';
import '../models/feed_model.dart';
import '../models/comment_model.dart';
import '../services/api_service.dart';
import '../../core/utils/api_helper.dart';
import 'package:dio/dio.dart' as dio;
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

  // Toggle a like on a feed and return the server's authoritative count
  // and isLiked state. Returning the full snapshot lets the controller
  // reconcile the optimistic update so client and server can't drift on
  // counts under concurrent likes from other devices.
  Future<Map<String, dynamic>> addLike(
    String feedId,
    Map<String, dynamic> userData,
  ) async {
    try {
      final response = await _apiService.post(
        '/api/feed/feeds/$feedId/like',
        data: userData,
      );

      final data = ApiHelper.handleResponse(response);
      return {
        'success': data['success'] ?? false,
        // Server returns either { likeCount, isLiked } or nests them under
        // `data` — accept both shapes.
        'likeCount': data['likeCount'] ??
            (data['data'] is Map ? data['data']['likeCount'] : null),
        'isLiked': data['isLiked'] ??
            (data['data'] is Map ? data['data']['isLiked'] : null),
      };
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

      // Drop any cached `getComments` page for this feed. Without this, the
      // dio cache interceptor would serve the previous (stale) page on the
      // next open of the comment sheet and the just-added comment wouldn't
      // appear until the cache TTL elapsed.
      try {
        await _apiService
            .clearCacheEntry('/api/feed/comments/getComment?feedId=$feedId');
      } catch (_) {}

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

      final data = ApiHelper.handleResponse(response);

      if (data == null) {
        throw Exception('Invalid response: null data');
      }

      // Alternate "no comments found" envelope shipped by the backend.
      if (data.containsKey('message') && data.containsKey('comments')) {
        final List<CommentModel> comments = [];
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

      // Standard mongoose-paginate envelope.
      if (!data.containsKey('docs')) {
        throw Exception('Invalid response format: missing docs');
      }
      if (data['docs'] is! List) {
        throw Exception('Invalid response format: docs is not a list');
      }

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
        '/api/feed/feeds/random',
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

  // Get recommended feeds for user.
  //
  // The backend has shipped two response shapes: a flat `{ feeds, pagination }`
  // and a nested `{ data: { feeds, pagination } }`. Older code switched
  // between them at the *envelope* level — if `data.data` existed, BOTH
  // feeds and pagination were read from there; otherwise both from root.
  // That coupling broke on transitional responses where one field was at
  // root and the other nested (or one was missing). This version resolves
  // each field independently with explicit fallbacks.
  Future<Map<String, dynamic>> getRecommendedFeeds(String userId,
      {int page = 1, int limit = 10}) async {
    try {
      final response = await _apiService.get(
        '/api/feed/feeds/user/$userId/recommended',
        queryParameters: {'page': page, 'limit': limit},
      );

      final data = ApiHelper.handleResponse(response);
      final inner = data['data'] is Map ? data['data'] as Map : null;

      dynamic readEither(String key) {
        if (data[key] != null) return data[key];
        return inner?[key];
      }

      final feedsData = readEither('feeds');
      if (feedsData == null) {
        return {
          'feeds': <FeedModel>[],
          'pagination': {'hasMore': false},
          'recommendationType': null,
        };
      }

      final List<FeedModel> feeds = (feedsData as List)
          .map((feed) => FeedModel.fromJson(feed))
          .toList();

      return {
        'feeds': feeds,
        'pagination': readEither('pagination') ?? {'hasMore': false},
        'recommendationType': readEither('recommendationType'),
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

  /// Fetch all feed IDs liked by a user.
  /// Used to restore `isLiked` UI state on app restart.
  ///
  /// The backend returns Like docs with the `feed` field either as a raw
  /// ObjectId string OR as a populated object. We pull the id from whichever
  /// shape arrives so backend-side populate changes don't silently drop
  /// liked entries from the restored set. Also tolerates `feedId` as an
  /// alternate field name used in some endpoints.
  Future<Set<String>> getUserLikedFeedIds(String userId) async {
    try {
      final likedFeedIds = <String>{};
      var page = 1;
      var hasNextPage = true;

      String? extractFeedId(dynamic doc) {
        if (doc is! Map) return null;
        for (final key in const ['feed', 'feedId']) {
          final field = doc[key];
          if (field is String && field.isNotEmpty) return field;
          if (field is Map) {
            final id = field['_id'] ?? field['id'];
            if (id != null) return id.toString();
          }
        }
        return null;
      }

      while (hasNextPage) {
        final response = await _apiService.get(
          '/api/feed/likes/user/$userId',
          queryParameters: {
            'page': page,
            'limit': 100,
          },
        );

        final data = ApiHelper.handleResponse(response);
        final docs = data['docs'];

        if (docs is! List || docs.isEmpty) {
          break;
        }

        for (final item in docs) {
          final id = extractFeedId(item);
          if (id != null) likedFeedIds.add(id);
        }

        hasNextPage = data['hasNextPage'] == true;
        page++;
      }

      return likedFeedIds;
    } catch (_) {
      // Silent fail: don't block feed loading if liked-feeds sync fails.
      return <String>{};
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

  /// Track user interaction with a feed (view, like, comment, share, save)
  /// This helps improve personalized recommendations
  Future<bool> trackInteraction({
    required String userId,
    required String feedId,
    required String interactionType,
  }) async {
    try {
      final response = await _apiService.post(
        ApiConstants.FEED_USER_INTERACTION,
        data: {
          'userId': userId,
          'feedId': feedId,
          'interactionType': interactionType,
        },
      );

      final data = ApiHelper.handleResponse(response);
      return data['success'] ?? false;
    } catch (e) {
      // Silently fail for tracking - don't interrupt user experience
      print('Error tracking interaction: $e');
      return false;
    }
  }

  /// Update user's location and interests for better recommendations
  Future<bool> updateUserInterest({
    required String userId,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final Map<String, dynamic> data = {
        'userId': userId,
      };

      if (latitude != null && longitude != null) {
        data['location'] = {
          'latitude': latitude,
          'longitude': longitude,
        };
      }

      final response = await _apiService.post(
        ApiConstants.FEED_USER_INTEREST,
        data: data,
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error updating user interest: $e');
      return false;
    }
  }

  /// Sync initial user interests from onboarding/profile
  /// This seeds the recommendation engine with user's declared interests
  Future<bool> syncInitialInterests({
    required String userId,
    List<String>? interests,
    List<String>? categories,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final Map<String, dynamic> data = {
        'userId': userId,
      };

      if (interests != null && interests.isNotEmpty) {
        data['interests'] = interests;
      }

      if (categories != null && categories.isNotEmpty) {
        data['categories'] = categories;
      }

      if (latitude != null && longitude != null) {
        data['location'] = {
          'latitude': latitude,
          'longitude': longitude,
        };
      }

      final response = await _apiService.post(
        ApiConstants.FEED_SYNC_INTERESTS,
        data: data,
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error syncing initial interests: $e');
      return false;
    }
  }

  /// Get presigned URL for upload
  Future<Map<String, dynamic>> getPresignedUrl({
    required String fileName,
    required String fileType,
    required String contentType,
    String? userId,
  }) async {
    try {
      final response = await _apiService.post(
        ApiConstants.GET_PRESIGNED_URL,
        data: {
          'fileName': fileName,
          'fileType': fileType,
          'contentType': contentType,
          if (userId != null) 'userId': userId,
        },
      );

      final data = ApiHelper.handleResponse(response);
      return data['data'];
    } catch (e) {
      throw ApiHelper.handleError(e);
    }
  }

  /// Upload file to S3 using presigned URL
  Future<void> uploadFileToS3({
    required String presignedUrl,
    required String filePath,
    required String contentType,
    Function(double)? onProgress,
  }) async {
    try {
      final file = File(filePath);
      final int fileLength = await file.length();
      
      // Use a fresh Dio instance to avoid any global interceptors (like Auth headers)
      final uploadDio = dio.Dio();
      
      await uploadDio.put(
        presignedUrl,
        data: file.openRead(),
        options: dio.Options(
          headers: {
            'Content-Type': contentType,
            'Content-Length': fileLength,
          },
        ),
        onSendProgress: (sent, total) {
          if (onProgress != null && total > 0) {
            onProgress(sent / total);
          }
        },
      );
    } catch (e) {
      print('S3 Upload Error: $e');
      if (e is dio.DioException) {
        print('S3 Upload Error Response: ${e.response?.data}');
        print('S3 Upload Error Headers: ${e.response?.headers}');
      }
      throw ApiHelper.handleError(e);
    }
  }
}
