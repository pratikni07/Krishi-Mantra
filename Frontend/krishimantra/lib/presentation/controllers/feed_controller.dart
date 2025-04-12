import 'package:get/get.dart';
import '../../data/models/comment_modal.dart';
import '../../data/repositories/feed_repository.dart';
import '../../data/models/feed_model.dart';
import '../../data/services/UserService.dart';
import 'base_controller.dart';

class FeedController extends BaseController {
  final FeedRepository _feedRepository;
  final UserService _userService;

  final RxList<FeedModel> feeds = <FeedModel>[].obs;
  final RxList<CommentModel> comments = <CommentModel>[].obs;
  final RxInt currentPage = 1.obs;
  final RxInt commentCurrentPage = 1.obs;
  final RxBool hasMore = true.obs;
  final RxBool hasMoreComments = true.obs;
  final RxInt totalComments = 0.obs;
  final int limit = 10;

  final RxList<FeedModel> randomFeeds = <FeedModel>[].obs;
  final RxList<FeedModel> recommendedFeeds = <FeedModel>[].obs;
  final RxBool isRandomLoading = false.obs;
  final RxBool isRecommendedLoading = false.obs;
  final RxInt randomCurrentPage = 1.obs;
  final RxInt recommendedCurrentPage = 1.obs;
  final RxBool hasMoreRandomFeeds = true.obs;
  final RxBool hasMoreRecommendedFeeds = true.obs;

  final RxList<FeedModel> topFeeds = <FeedModel>[].obs;
  final RxBool isLoadingTopFeeds = false.obs;
  final RxBool isLoadingComments = false.obs;
  
  final RxList<Map<String, dynamic>> trendingHashtags =
      <Map<String, dynamic>>[].obs;
  final RxBool isLoadingHashtags = false.obs;
  final RxString selectedTag = ''.obs;

  FeedController(this._feedRepository, this._userService);

  @override
  void onInit() {
    super.onInit();
    // getFeeds();
  }

  // Future<void> getFeeds({bool refresh = false}) async {
  //   try {
  //     if (refresh) {
  //       currentPage.value = 1;
  //       hasMore.value = true;
  //       feeds.clear();
  //     }

  //     if (!hasMore.value) return;
  //     isLoading.value = true;

  //     final result = await _feedRepository.getFeeds(
  //       page: currentPage.value,
  //       limit: limit,
  //     );

  //     final newFeeds = (result['feeds'] as List<FeedModel>);

  //     // Get current user ID to check if posts are liked
  //     final userData = await _userService.getUser();
  //     if (userData != null) {
  //       for (var feed in newFeeds) {
  //         final likesList = feed.like['users'] as List? ?? [];
  //         feed.isLiked = likesList.contains(userData.id);
  //       }
  //     }

  //     feeds.addAll(newFeeds);

  //     final pagination = result['pagination'];
  //     hasMore.value = pagination['hasMore'] ?? false;
  //     if (hasMore.value) currentPage.value++;
  //   } catch (e) {
  //     Get.snackbar(
  //       'Error',
  //       e.toString(),
  //       snackPosition: SnackPosition.BOTTOM,
  //     );
  //   } finally {
  //     isLoading.value = false;
  //   }
  // }

  // Get comments for a feed
  Future<void> getComments(String feedId, {bool refresh = false}) async {
    try {
      if (refresh) {
        commentCurrentPage.value = 1;
        hasMoreComments.value = true;
        comments.clear();
      }

      if (!hasMoreComments.value) return;
      
      isLoadingComments.value = true;
      print('⭐️ Starting to fetch comments for feed: $feedId, page: ${commentCurrentPage.value}');
      
      await handleAsync<void>(
        () async {
          try {
            final result = await _feedRepository.getComments(
              feedId,
              page: commentCurrentPage.value,
              limit: limit,
            );
            
            print('📄 Received comment response: $result');
            
            // Parse the comments from the result
            if (result.containsKey('comments') && result['comments'] is List) {
              final newComments = result['comments'] as List<CommentModel>;
              print('✅ Found ${newComments.length} comments');
              comments.addAll(newComments);
            } else {
              print('⚠️ No comments found in result or invalid format');
            }
            
            totalComments.value = result['totalDocs'] as int? ?? 0;
            hasMoreComments.value = result['hasNextPage'] as bool? ?? false;
            
            print('📊 Total comments: ${totalComments.value}, hasMore: ${hasMoreComments.value}');
            
            if (hasMoreComments.value) {
              commentCurrentPage.value++;
            }
          } catch (e) {
            print('🚨 Inner error processing comments: $e');
            rethrow;
          }
        },
        showLoading: false,
      );
    } catch (e) {
      print('❌ Error loading comments: $e');
      // Error is already handled by the handleAsync method
    } finally {
      isLoadingComments.value = false;
      print('🏁 Finished loading comments attempt');
    }
  }

  Future<void> addComment(
    String feedId,
    String content, {
    String? parentCommentId,
  }) async {
    return await handleAsync<void>(
      () async {
        final userData = await _userService.getUser();
        if (userData == null) throw Exception('User not found');

        final Map<String, dynamic> commentData = {
          'userId': userData.id,
          'userName': userData.firstName + " " + userData.lastName,
          'profilePhoto': userData.image,
          'content': content.trim(),
        };
        if (parentCommentId != null && parentCommentId.isNotEmpty) {
          commentData['parentCommentId'] = parentCommentId;
        }

        await _feedRepository.addComment(feedId, commentData);

        // Update the comments list and total count
        await getComments(feedId, refresh: true);
      },
      showLoading: true,
    );
  }

  Future<void> likeFeed(String feedId) async {
    try {
      final userData = await _userService.getUser();
      if (userData == null) throw Exception('User not found');

      final index = recommendedFeeds.indexWhere((feed) => feed.id == feedId);
      if (index == -1) return;

      final feed = recommendedFeeds[index];

      // Optimistically update UI
      feed.toggleLike();
      recommendedFeeds[index] = feed.copyWith();

      final likeData = {
        'userId': userData.id,
        'userName': userData.name,
        'profilePhoto': userData.image,
      };

      final success = await _feedRepository.addLike(feedId, likeData);

      if (!success) {
        // Revert if the API call failed
        feed.toggleLike();
        recommendedFeeds[index] = feed.copyWith();
        throw Exception('Failed to like post');
      }
    } catch (e) {
      // Silent fail for likes, don't show error screen
      // Just log the error or show a minimal indicator
      setError(e);
    }
  }

  Future<void> createFeed(String description, String content,
      {Map<String, dynamic>? location}) async {
    return await handleAsync<void>(
      () async {
        final userData = await _userService.getUser();
        if (userData == null) throw Exception('User not found');

        final feedData = {
          'userId': userData.id,
          'userName': userData.name,
          'profilePhoto': userData.image,
          'description': description,
          'content': content,
          if (location != null) 'location': location,
        };

        final newFeed = await _feedRepository.createFeed(feedData);
        feeds.insert(0, newFeed);
      },
      showLoading: true,
    );
  }

  Future<void> fetchRecommendedFeeds({bool refresh = false}) async {
    try {
      if (refresh) {
        recommendedCurrentPage.value = 1;
        hasMoreRecommendedFeeds.value = true;
        recommendedFeeds.clear();
      }

      if (!hasMoreRecommendedFeeds.value) return;
      isRecommendedLoading.value = true;

      await handleAsync<void>(
        () async {
          // Get user data and check if it exists
          final userData = await _userService.getUser();
          if (userData == null) throw Exception('User not found');

          final result = await _feedRepository.getRecommendedFeeds(
            userData.id,
            page: recommendedCurrentPage.value,
            limit: limit,
          );

          // Safely handle the feeds list which might be null
          final feedsList = result['feeds'];
          if (feedsList != null) {
            final newFeeds = (feedsList as List<FeedModel>);
            recommendedFeeds.addAll(newFeeds);
          }

          // Update pagination
          final pagination = result['pagination'];
          hasMoreRecommendedFeeds.value = pagination['hasMore'] ?? false;
          if (hasMoreRecommendedFeeds.value) recommendedCurrentPage.value++;
        },
        showLoading: recommendedFeeds.isEmpty,
        isRefresh: refresh,
      );
    } catch (e) {
      // Error is already handled by handleAsync
    } finally {
      isRecommendedLoading.value = false;
    }
  }

  Future<void> refreshComments(String feedId) async {
    await getComments(feedId, refresh: true);
  }

  // Future<void> refreshFeeds() async {
  //   await getFeeds(refresh: true);
  // }

  Future<void> fetchTopFeeds() async {
    try {
      isLoadingTopFeeds.value = true;
      await handleAsync<void>(
        () async {
          final userData = await _userService.getUser();
          if (userData == null) throw Exception('User not found');
          
          final result = await _feedRepository.getTopFeeds();
          topFeeds.value = result;
        },
        showLoading: false,
      );
    } catch (e) {
      // Error handled silently for home screen components
    } finally {
      isLoadingTopFeeds.value = false;
    }
  }

  Future<void> fetchTrendingHashtags() async {
    try {
      await handleAsync<void>(
        () async {
          final tags = await _feedRepository.getTrendingHashtags();
          if (tags != null) {
            trendingHashtags.value = tags;
          }
        },
        showLoading: false,
      );
    } catch (e) {
      // Silent error - don't crash the UI if tags can't be loaded
    }
  }

  Future<void> fetchFeedsByTag(String tagName, {bool refresh = false}) async {
    try {
      if (refresh) {
        recommendedCurrentPage.value = 1;
        hasMoreRecommendedFeeds.value = true;
        recommendedFeeds.clear();
      }

      if (!hasMoreRecommendedFeeds.value) return;
      isRecommendedLoading.value = true;
      selectedTag.value = tagName;

      final result = await _feedRepository.getFeedsByTag(
        tagName,
        page: recommendedCurrentPage.value,
        limit: limit,
      );

      // Safely handle data that might be null
      final feedsList = result['feeds'];
      if (feedsList != null) {
        final newFeeds = (feedsList as List<FeedModel>);

        // Get current user ID to check if posts are liked
        final userData = await _userService.getUser();
        if (userData != null) {
          for (var feed in newFeeds) {
            // Instead of trying to access like['users'] which might not exist,
            // just use the isLiked property already provided or default to false
            // No need to set isLiked based on like['users'] because it's not reliable in this API
          }
        }

        recommendedFeeds.addAll(newFeeds);

        final pagination = result['pagination'];
        hasMoreRecommendedFeeds.value = pagination['hasMore'] ?? false;
        if (hasMoreRecommendedFeeds.value) recommendedCurrentPage.value++;
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to fetch feeds by tag: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isRecommendedLoading.value = false;
    }
  }

  void clearSelectedTag() {
    selectedTag.value = '';
    fetchRecommendedFeeds(refresh: true);
  }
}
