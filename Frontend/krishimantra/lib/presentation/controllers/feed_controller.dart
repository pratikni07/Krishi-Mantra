import 'package:get/get.dart';
import '../../data/models/comment_modal.dart';
import '../../data/repositories/feed_repository.dart';
import '../../data/models/feed_model.dart';
import '../../data/services/UserService.dart';

class FeedController extends GetxController {
  final FeedRepository _feedRepository;
  final UserService _userService;

  final RxList<FeedModel> feeds = <FeedModel>[].obs;
  final RxList<CommentModel> comments = <CommentModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isLoadingComments = false.obs;
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

      final result = await _feedRepository.getComments(
        feedId,
        page: commentCurrentPage.value,
        limit: limit,
      );

      comments.addAll(result['comments'] as List<CommentModel>);
      totalComments.value = result['totalDocs'] as int;

      hasMoreComments.value = result['hasNextPage'] as bool;
      if (hasMoreComments.value) commentCurrentPage.value++;
    } catch (e) {
      Get.snackbar(
        'Error',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoadingComments.value = false;
    }
  }

  Future<void> addComment(
    String feedId,
    String content, {
    String? parentCommentId,
  }) async {
    try {
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

      final result = await _feedRepository.addComment(feedId, commentData);

      // Update the comments list and total count
      await getComments(feedId, refresh: true);

      // Show success message
      Get.snackbar(
        'Success',
        parentCommentId == null ? 'Comment added' : 'Reply added',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to add comment: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> likeFeed(String feedId) async {
    try {
      final userData = await _userService.getUser();
      if (userData == null) throw Exception('User not found');

      final index = feeds.indexWhere((feed) => feed.id == feedId);
      if (index == -1) return;

      final feed = feeds[index];

      // Optimistically update UI
      feed.toggleLike();
      feeds[index] = feed.copyWith();

      final likeData = {
        'userId': userData.id,
        'userName': userData.name,
        'profilePhoto': userData.image,
      };

      final success = await _feedRepository.addLike(feedId, likeData);

      if (!success) {
        // Revert if the API call failed
        feed.toggleLike();
        feeds[index] = feed.copyWith();
        throw Exception('Failed to like post');
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> createFeed(String description, String content,
      {Map<String, dynamic>? location}) async {
    try {
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
    } catch (e) {
      Get.snackbar(
        'Error',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> fetchRecommendedFeeds({bool refresh = false}) async {
    try {
      if (refresh) {
        recommendedCurrentPage.value = 1;
        hasMoreRecommendedFeeds.value = true;
        recommendedFeeds.clear();
      }

      // Get user data and check if it exists
      final userData = await _userService.getUser();
      if (userData == null) throw Exception('User not found');

      if (!hasMoreRecommendedFeeds.value) return;
      isRecommendedLoading.value = true;

      final result = await _feedRepository.getRecommendedFeeds(
        userData.id, // Changed to positional parameter
        page: recommendedCurrentPage.value,
        limit: limit,
      );

      final newFeeds = (result['feeds'] as List<FeedModel>);
      recommendedFeeds.addAll(newFeeds);

      final pagination = result['pagination'];
      hasMoreRecommendedFeeds.value = pagination['hasMore'] ?? false;
      if (hasMoreRecommendedFeeds.value) recommendedCurrentPage.value++;

      // Optional: You can store the recommendation type if needed
      final recommendationType = result['recommendationType'];
    } catch (e) {
      Get.snackbar(
        'Error',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
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
      final userData = await _userService.getUser();

      final feeds = await _feedRepository.getTopFeeds();

      // Check if posts are liked by current user
      if (userData != null) {
        for (var feed in feeds) {
          final likesList = feed.like['users'] as List? ?? [];
          feed.isLiked = likesList.contains(userData.id);
        }
      }

      topFeeds.value = feeds;
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to fetch top feeds: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoadingTopFeeds.value = false;
    }
  }

  Future<void> fetchTrendingHashtags() async {
    try {
      isLoadingHashtags.value = true;
      final hashtags = await _feedRepository.getTrendingHashtags();
      trendingHashtags.value = hashtags;
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to fetch trending hashtags: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoadingHashtags.value = false;
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

      final newFeeds = (result['feeds'] as List<FeedModel>);

      // Get current user ID to check if posts are liked
      final userData = await _userService.getUser();
      if (userData != null) {
        for (var feed in newFeeds) {
          final likesList = feed.like['users'] as List? ?? [];
          feed.isLiked = likesList.contains(userData.id);
        }
      }

      recommendedFeeds.addAll(newFeeds);

      final pagination = result['pagination'];
      hasMoreRecommendedFeeds.value = pagination['hasMore'] ?? false;
      if (hasMoreRecommendedFeeds.value) recommendedCurrentPage.value++;
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
