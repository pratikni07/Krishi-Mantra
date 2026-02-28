import 'package:get/get.dart';
import '../../data/models/comment_model.dart';
import '../../data/repositories/feed_repository.dart';
import '../../data/models/feed_model.dart';
import '../../data/services/UserService.dart';
import '../../data/services/engagement_service.dart';
import 'base_controller.dart';

class FeedController extends BaseController {
  final FeedRepository _feedRepository;
  final UserService _userService;
  final EngagementService _engagementService = EngagementService();

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

  // Track viewed feeds to avoid duplicate tracking
  final Set<String> _viewedFeedIds = {};
  final Set<String> _likedFeedIds = <String>{};
  bool _likedFeedIdsLoaded = false;

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
      print(
          '⭐️ Starting to fetch comments for feed: $feedId, page: ${commentCurrentPage.value}');

      await handleAsync<void>(
        () async {
          try {
            final result = await _feedRepository.getComments(
              feedId,
              page: commentCurrentPage.value,
              limit: limit,
            );

            print('📄 Received comment response: $result');

            // Clear any previous errors since we got a successful response
            if (hasError) {
              setLoaded();
            }

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

            print(
                '📊 Total comments: ${totalComments.value}, hasMore: ${hasMoreComments.value}');

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

        // Use name field, or construct from firstName/lastName if name is empty
        String userName = userData.name;
        if (userName.isEmpty) {
          userName = '${userData.firstName} ${userData.lastName}'.trim();
        }
        if (userName.isEmpty) {
          userName = 'User';
        }

        final Map<String, dynamic> commentData = {
          'userId': userData.id,
          'userName': userName,
          'profilePhoto': userData.image,
          'content': content.trim(),
        };
        if (parentCommentId != null && parentCommentId.isNotEmpty) {
          commentData['parentCommentId'] = parentCommentId;
        }

        print(
            'FeedController: Adding comment to feed $feedId with parentCommentId: $parentCommentId');
        await _feedRepository.addComment(feedId, commentData);

        // Track engagement
        _engagementService.trackFeedComment(feedId);

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

      final previousLikeStates = <String, bool>{};
      final touchedAnyList = _toggleLikeInAllFeedLists(
        feedId,
        previousLikeStates,
      );
      if (!touchedAnyList) return;

      final likeData = {
        'userId': userData.id,
        'userName': userData.name,
        'profilePhoto': userData.image,
      };

      final success = await _feedRepository.addLike(feedId, likeData);

      if (!success) {
        _revertLikeInAllFeedLists(feedId, previousLikeStates);
        throw Exception('Failed to like post');
      }

      // Track engagement
      final trackedFeed = _findFeedInAllLists(feedId);
      if (trackedFeed != null) {
        if (trackedFeed.isLiked) {
          _likedFeedIds.add(feedId);
        } else {
          _likedFeedIds.remove(feedId);
        }
        _engagementService.trackFeedLike(feedId, isLike: trackedFeed.isLiked);
      }
    } catch (e) {
      // Silent fail for likes, don't show error screen
      // Just log the error or show a minimal indicator
      setError(e);
    }
  }

  FeedModel? _findFeedInAllLists(String feedId) {
    final fromTop = topFeeds.firstWhereOrNull((feed) => feed.id == feedId);
    if (fromTop != null) return fromTop;

    final fromRecommended =
        recommendedFeeds.firstWhereOrNull((feed) => feed.id == feedId);
    if (fromRecommended != null) return fromRecommended;

    final fromFeeds = feeds.firstWhereOrNull((feed) => feed.id == feedId);
    if (fromFeeds != null) return fromFeeds;

    return randomFeeds.firstWhereOrNull((feed) => feed.id == feedId);
  }

  bool _toggleLikeInAllFeedLists(
    String feedId,
    Map<String, bool> previousLikeStates,
  ) {
    var touched = false;

    void toggleInList(RxList<FeedModel> list, String listKey) {
      final index = list.indexWhere((feed) => feed.id == feedId);
      if (index == -1) return;

      final feed = list[index];
      previousLikeStates[listKey] = feed.isLiked;
      feed.toggleLike();
      list[index] = feed.copyWith();
      touched = true;
    }

    toggleInList(topFeeds, 'topFeeds');
    toggleInList(recommendedFeeds, 'recommendedFeeds');
    toggleInList(feeds, 'feeds');
    toggleInList(randomFeeds, 'randomFeeds');

    update(); // Needed for GetBuilder screens like Home
    return touched;
  }

  void _revertLikeInAllFeedLists(
    String feedId,
    Map<String, bool> previousLikeStates,
  ) {
    void revertInList(RxList<FeedModel> list, String listKey) {
      final index = list.indexWhere((feed) => feed.id == feedId);
      if (index == -1) return;
      if (!previousLikeStates.containsKey(listKey)) return;

      final shouldBeLiked = previousLikeStates[listKey]!;
      final feed = list[index];
      if (feed.isLiked != shouldBeLiked) {
        feed.toggleLike();
        list[index] = feed.copyWith();
      }
    }

    revertInList(topFeeds, 'topFeeds');
    revertInList(recommendedFeeds, 'recommendedFeeds');
    revertInList(feeds, 'feeds');
    revertInList(randomFeeds, 'randomFeeds');

    update();
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
          await _ensureLikedFeedIdsLoaded(forceRefresh: refresh);

          // Get user data and check if it exists
          final userData = await _userService.getUser();
          if (userData == null) {
            print(
                'FeedController: User not found, cannot fetch recommended feeds');
            throw Exception('User not found');
          }

          print(
              'FeedController: Fetching recommended feeds for user: ${userData.id}');

          final result = await _feedRepository.getRecommendedFeeds(
            userData.id,
            page: recommendedCurrentPage.value,
            limit: limit,
          );

          print(
              'FeedController: Got result with ${result['feeds']?.length ?? 0} feeds');

          // Safely handle the feeds list which might be null
          final feedsList = result['feeds'];
          if (feedsList != null) {
            final newFeeds = (feedsList as List<FeedModel>);
            _applyLikedState(newFeeds);
            recommendedFeeds.addAll(newFeeds);
            print(
                'FeedController: Added ${newFeeds.length} feeds, total: ${recommendedFeeds.length}');
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
      print('FeedController: Error fetching recommended feeds: $e');
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
          await _ensureLikedFeedIdsLoaded();

          final result = await _feedRepository.getTopFeeds();
          _applyLikedState(result);
          topFeeds.value = result;
          update(); // Notify GetBuilder listeners
        },
        showLoading: false,
      );
    } catch (e) {
      // Error handled silently for home screen components
    } finally {
      isLoadingTopFeeds.value = false;
      update(); // Notify GetBuilder listeners
    }
  }

  Future<void> fetchTrendingHashtags() async {
    try {
      await handleAsync<void>(
        () async {
          final tags = await _feedRepository.getTrendingHashtags();
          if (tags != null) {
            trendingHashtags.value = tags;
            update(); // Notify GetBuilder listeners
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
      await _ensureLikedFeedIdsLoaded(forceRefresh: refresh);

      final result = await _feedRepository.getFeedsByTag(
        tagName,
        page: recommendedCurrentPage.value,
        limit: limit,
      );

      // Safely handle data that might be null
      final feedsList = result['feeds'];
      if (feedsList != null) {
        final newFeeds = (feedsList as List<FeedModel>);
        _applyLikedState(newFeeds);

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

  /// Track when a feed is viewed (called when feed becomes visible)
  Future<void> trackFeedView(String feedId) async {
    // Avoid duplicate tracking for the same feed in this session
    if (_viewedFeedIds.contains(feedId)) return;
    _viewedFeedIds.add(feedId);

    // Track in engagement service
    _engagementService.trackFeedView(feedId);

    try {
      final userData = await _userService.getUser();
      if (userData == null) return;

      await _feedRepository.trackInteraction(
        userId: userData.id,
        feedId: feedId,
        interactionType: 'view',
      );
    } catch (e) {
      // Silent fail - don't interrupt user experience
      print('Error tracking feed view: $e');
    }
  }

  /// Track when a feed is shared
  Future<void> trackFeedShare(String feedId) async {
    try {
      final userData = await _userService.getUser();
      if (userData == null) return;

      await _feedRepository.trackInteraction(
        userId: userData.id,
        feedId: feedId,
        interactionType: 'share',
      );
    } catch (e) {
      print('Error tracking feed share: $e');
    }
  }

  /// Track when a feed is saved/bookmarked
  Future<void> trackFeedSave(String feedId) async {
    try {
      final userData = await _userService.getUser();
      if (userData == null) return;

      await _feedRepository.trackInteraction(
        userId: userData.id,
        feedId: feedId,
        interactionType: 'save',
      );
    } catch (e) {
      print('Error tracking feed save: $e');
    }
  }

  /// Update user's location for location-based recommendations
  Future<void> updateUserLocation(double latitude, double longitude) async {
    try {
      final userData = await _userService.getUser();
      if (userData == null) return;

      await _feedRepository.updateUserInterest(
        userId: userData.id,
        latitude: latitude,
        longitude: longitude,
      );
    } catch (e) {
      print('Error updating user location: $e');
    }
  }

  /// Clear viewed feeds tracking (call on logout or session reset)

  Future<void> _ensureLikedFeedIdsLoaded({bool forceRefresh = false}) async {
    if (_likedFeedIdsLoaded && !forceRefresh) return;

    final userData = await _userService.getUser();
    if (userData == null) return;

    final likedIds = await _feedRepository.getUserLikedFeedIds(userData.id);
    _likedFeedIds
      ..clear()
      ..addAll(likedIds);
    _likedFeedIdsLoaded = true;
  }

  void _applyLikedState(List<FeedModel> feedList) {
    for (final feed in feedList) {
      final isLiked = _likedFeedIds.contains(feed.id) ||
          feed.isLiked ||
          feed.like['isLiked'] == true;
      feed.isLiked = isLiked;
      feed.like['isLiked'] = isLiked;
    }
  }
  void clearViewTracking() {
    _viewedFeedIds.clear();
    _likedFeedIds.clear();
    _likedFeedIdsLoaded = false;
  }

  /// Sync user's initial interests from profile/onboarding
  /// Call this after user completes onboarding or updates their interests
  Future<void> syncUserInterests({
    List<String>? interests,
    List<String>? categories,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final userData = await _userService.getUser();
      if (userData == null) return;

      await _feedRepository.syncInitialInterests(
        userId: userData.id,
        interests: interests,
        categories: categories,
        latitude: latitude,
        longitude: longitude,
      );

      // Refresh recommended feeds after syncing interests
      await fetchRecommendedFeeds(refresh: true);
    } catch (e) {
      print('Error syncing user interests: $e');
    }
  }
}
