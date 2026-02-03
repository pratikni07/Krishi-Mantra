import 'package:dio/dio.dart' as dio;
import '../services/UserService.dart';
import '../services/api_service.dart';
import '../models/reel_model.dart';

/// Enum for interaction types
enum InteractionType { view, like, comment, share, save }

class ReelRepository {
  final ApiService _apiService;
  final UserService _userService;

  ReelRepository(this._apiService, this._userService);

  Future<Map<String, dynamic>> getReels({
    int page = 1,
    int limit = 10,
  }) async {
    try {
      // Add cache-control header to bypass cache and get fresh data
      final options = dio.Options(
        headers: {
          'Cache-Control': 'no-cache',
        },
      );

      final response = await _apiService.get(
        '/api/reels',
        queryParameters: {
          'page': page,
          'limit': limit,
        },
        options: options,
      );

      return response.data;
    } catch (error) {
      rethrow; // ApiService already handles error classification
    }
  }

  Future<List<Map<String, dynamic>>> getTrendingTags() async {
    final response = await _apiService.get('/api/reels/tags/trending');
    return List<Map<String, dynamic>>.from(response.data['data']);
  }

  Future<List<ReelModel>> getReelsByTag(String tagName) async {
    final userId = await _userService.getUserId();
    final response = await _apiService.get('/api/reels/tags/$tagName',
        queryParameters: {'userId': userId});
    return (response.data['data'] as List)
        .map((reel) => ReelModel.fromJson(reel))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getComments(String reelId) async {
    try {
      final response =
          await _apiService.get('/api/reels/$reelId/comments');

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
    final userId = await _userService.getUserId();
    // Add cache-control header to bypass cache and get fresh data
    final options = dio.Options(
      headers: {
        'Cache-Control': 'no-cache',
      },
    );
    final response = await _apiService.get(
      '/api/reels/trending',
      queryParameters: {'userId': userId},
      options: options,
    );
    return response.data;
  }

  /// Get recommended reels based on user interests
  Future<Map<String, dynamic>> getRecommendedReels({
    int page = 1,
    int limit = 10,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final userId = await _userService.getUserId();
      if (userId == null || userId.isEmpty) {
        // Fallback to trending if no user ID
        return await getTrendingReels();
      }

      final options = dio.Options(
        headers: {
          'Cache-Control': 'no-cache',
        },
      );

      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };

      if (latitude != null && longitude != null) {
        queryParams['latitude'] = latitude;
        queryParams['longitude'] = longitude;
      }

      final response = await _apiService.get(
        '/api/reels/recommended/$userId',
        queryParameters: queryParams,
        options: options,
      );

      return response.data;
    } catch (e) {
      // Fallback to trending reels on error
      return await getTrendingReels();
    }
  }

  /// Record user interaction with a reel
  Future<Map<String, dynamic>> recordInteraction(
    String reelId,
    InteractionType interactionType,
  ) async {
    try {
      final userId = await _userService.getUserId();
      if (userId == null || userId.isEmpty) {
        return {'success': false, 'message': 'User not logged in'};
      }

      final data = {
        'userId': userId,
        'reelId': reelId,
        'interactionType': interactionType.name,
      };

      final response = await _apiService.post(
        '/api/reels/interaction',
        data: data,
      );

      return response.data;
    } catch (e) {
      // Silent fail for interaction recording
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get user's interest profile
  Future<UserInterestModel?> getUserInterests() async {
    try {
      final userId = await _userService.getUserId();
      if (userId == null || userId.isEmpty) {
        return null;
      }

      final response = await _apiService.get('/api/reels/interests/$userId');

      if (response.data['status'] == 'success') {
        return UserInterestModel.fromJson(response.data['data']);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Initialize user interests from activity history
  Future<UserInterestModel?> initializeUserInterests() async {
    try {
      final userId = await _userService.getUserId();
      if (userId == null || userId.isEmpty) {
        return null;
      }

      final response = await _apiService.post(
        '/api/reels/interests/$userId/initialize',
        data: {},
      );

      if (response.data['status'] == 'success') {
        return UserInterestModel.fromJson(response.data['data']);
      }
      return null;
    } catch (e) {
      return null;
    }
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
        '/api/reels/$reelId/comments',
        data: data,
      );

      // Record comment interaction
      await recordInteraction(reelId, InteractionType.comment);

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
        '/api/reels/$reelId/like',
        data: data,
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to like reel: ${response.statusMessage}');
      }

      // Record like interaction (fire and forget - don't block response)
      recordInteraction(reelId, InteractionType.like);

      return response.data;
    } on dio.DioException catch (e) {
      // Handle timeout/connection errors - assume success since we can't know for sure
      // The optimistic UI update will be kept
      if (e.type == dio.DioExceptionType.receiveTimeout ||
          e.type == dio.DioExceptionType.connectionTimeout ||
          e.type == dio.DioExceptionType.sendTimeout ||
          e.type == dio.DioExceptionType.connectionError) {
        // Return success - the operation might have succeeded on the server
        // Better UX to keep the optimistic update than to revert
        return {
          'status': 'success',
          'message': 'Request sent (timeout)',
          'data': {'like': {'isLiked': true}},
        };
      }
      // Handle "already liked" error gracefully
      if (e.response?.statusCode == 400) {
        final errorMessage = e.response?.data?['message']?.toString() ?? '';
        if (errorMessage.toLowerCase().contains('already liked')) {
          // Return success since the reel is already liked
          return {
            'status': 'success',
            'message': 'Already liked',
            'data': {'like': {'isLiked': true}},
          };
        }
      }
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> unlikeReel(String reelId) async {
    try {
      final userId = await _userService.getUserId();
      final data = {'userId': userId};

      final response = await _apiService.delete(
        '/api/reels/$reelId/like',
        data: data,
      );

      return response.data;
    } on dio.DioException catch (e) {
      // Handle timeout/connection errors - assume success since we can't know for sure
      // The optimistic UI update will be kept
      if (e.type == dio.DioExceptionType.receiveTimeout ||
          e.type == dio.DioExceptionType.connectionTimeout ||
          e.type == dio.DioExceptionType.sendTimeout ||
          e.type == dio.DioExceptionType.connectionError) {
        // Return success - the operation might have succeeded on the server
        // Better UX to keep the optimistic update than to revert
        return {
          'status': 'success',
          'message': 'Request sent (timeout)',
          'data': {'like': {'isLiked': false}},
        };
      }
      // Handle "like not found" error gracefully (user already unliked)
      if (e.response?.statusCode == 404) {
        final errorMessage = e.response?.data?['message']?.toString() ?? '';
        if (errorMessage.toLowerCase().contains('like not found') ||
            errorMessage.toLowerCase().contains('not found')) {
          // Return success since the reel is already unliked
          return {
            'status': 'success',
            'message': 'Already unliked',
            'data': {'like': {'isLiked': false}},
          };
        }
      }
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  /// Upload a new reel video with HLS streaming support
  /// Returns the created reel with streaming URLs
  Future<Map<String, dynamic>> uploadReel({
    required String filePath,
    required String description,
    Map<String, double>? location,
  }) async {
    try {
      final userId = await _userService.getUserId();
      final firstName = await _userService.getFirstName();
      final lastName = await _userService.getLastName();
      final profilePhoto = await _userService.getImage();

      // Create multipart form data
      final formData = dio.FormData.fromMap({
        'video': await dio.MultipartFile.fromFile(
          filePath,
          filename: 'reel_${DateTime.now().millisecondsSinceEpoch}.mp4',
        ),
        'userId': userId,
        'userName': '$firstName $lastName',
        'profilePhoto': profilePhoto ?? '',
        'description': description,
        if (location != null)
          'location': '{"latitude": ${location['latitude']}, "longitude": ${location['longitude']}}',
      });

      final response = await _apiService.post(
        '/api/reels/upload',
        data: formData,
        options: dio.Options(
          contentType: 'multipart/form-data',
          // Longer timeout for video uploads
          sendTimeout: const Duration(minutes: 5),
          receiveTimeout: const Duration(minutes: 5),
        ),
      );

      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  /// Check video upload service status
  Future<bool> isUploadServiceAvailable() async {
    try {
      final response = await _apiService.get('/api/reels/upload/status');
      return response.data['data']?['configured'] == true;
    } catch (e) {
      return false;
    }
  }

  /// Get signed upload URL for direct client-side upload to Cloudinary
  Future<Map<String, dynamic>?> getUploadSignature() async {
    try {
      final response = await _apiService.get('/api/reels/upload/signature');
      if (response.data['status'] == 'success') {
        return response.data['data'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
