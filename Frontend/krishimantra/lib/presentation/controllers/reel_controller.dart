import 'package:get/get.dart';
import '../../data/models/reel_model.dart';
import '../../data/repositories/reel_repository.dart';
import '../../data/services/engagement_service.dart';
import 'base_controller.dart';
import 'package:flutter/material.dart';
import '../../core/utils/error_handler.dart';

class ReelController extends BaseController {
  final ReelRepository _reelRepository;

  RxList<ReelModel> reels = <ReelModel>[].obs;
  RxList<Map<String, dynamic>> trendingTags = <Map<String, dynamic>>[].obs;
  RxInt currentPage = 1.obs;
  RxBool hasMorePages = true.obs;
  RxMap<String, List<Map<String, dynamic>>> reelComments =
      <String, List<Map<String, dynamic>>>{}.obs;

  // User interests tracking
  Rx<UserInterestModel?> userInterests = Rx<UserInterestModel?>(null);
  RxBool isRecommendationMode = false.obs;

  // Track viewed reels to avoid duplicate view recordings
  final Set<String> _viewedReelIds = {};
  final EngagementService _engagementService = EngagementService();

  ReelController(this._reelRepository);

  Future<void> fetchReels({bool refresh = false}) async {
    if (refresh) {
      currentPage.value = 1;
      hasMorePages.value = true; // Reset pagination on refresh
      reels.clear();
    }

    if (!hasMorePages.value && !refresh) {
      return;
    }

    await handleAsync<void>(
      () async {
        final response = await _reelRepository.getReels(
          page: currentPage.value,
          limit: 10,
        );

        final List<ReelModel> newReels = (response['data']['data'] as List)
            .map((reel) => ReelModel.fromJson(reel))
            .toList();

        reels.addAll(newReels);

        final pagination = response['data']['pagination'];
        hasMorePages.value = pagination['hasNextPage'];
        if (hasMorePages.value) {
          currentPage.value++;
        }
        update(); // Notify GetBuilder listeners
      },
      showLoading: reels.isEmpty, // Only show loading if no reels yet
      isRefresh: refresh,
    );
  }

  /// Fetch recommended reels based on user interests
  Future<void> fetchRecommendedReels({bool refresh = false}) async {
    if (refresh) {
      currentPage.value = 1;
      hasMorePages.value = true; // Reset pagination on refresh
      reels.clear();
    }

    if (!hasMorePages.value && !refresh) {
      return;
    }

    await handleAsync<void>(
      () async {
        final response = await _reelRepository.getRecommendedReels(
          page: currentPage.value,
          limit: 10,
        );

        List<ReelModel> newReels = [];

        // Handle both response formats (direct data array or nested in data.data)
        if (response['data'] is List) {
          newReels = (response['data'] as List)
              .map((reel) => ReelModel.fromJson(reel))
              .toList();
        } else if (response['data'] != null && response['data']['data'] is List) {
          newReels = (response['data']['data'] as List)
              .map((reel) => ReelModel.fromJson(reel))
              .toList();
        }

        reels.addAll(newReels);

        // Handle pagination
        final pagination = response['pagination'] ?? response['data']?['pagination'];
        if (pagination != null) {
          hasMorePages.value = pagination['hasNextPage'] ?? false;
          if (hasMorePages.value) {
            currentPage.value++;
          }
        } else {
          hasMorePages.value = newReels.length >= 10;
          if (hasMorePages.value) {
            currentPage.value++;
          }
        }

        isRecommendationMode.value = true;
        update(); // Notify GetBuilder listeners
      },
      showLoading: reels.isEmpty,
      isRefresh: refresh,
    );
  }

  Future<void> fetchTrendingTags() async {
    try {
      await handleAsync<void>(
        () async {
          final tags = await _reelRepository.getTrendingTags();
          if (tags != null) {
            trendingTags.value = tags;
          }
        },
        showLoading: false, // Don't show loading for tags
      );
    } catch (e) {
      // Silent error - don't crash the UI if tags can't be loaded
    }
  }

  Future<void> addComment(String reelId, String content,
      {String? parentCommentId}) async {
    return await handleAsync<void>(() async {
      final response = await _reelRepository.addComment(reelId, content,
          parentCommentId: parentCommentId);

      if (response['status'] == 'success' && response['data'] != null) {
        // Update comment count in the reel
        final reelIndex = reels.indexWhere((reel) => reel.id == reelId);
        if (reelIndex != -1) {
          final reel = reels[reelIndex];
          final currentCount = reel.comment['count'] as int;
          reels[reelIndex] = reel.copyWith(
            comment: {
              ...reel.comment,
              'count': currentCount + 1,
            },
          );
          reels.refresh();
        }

        // Add the new comment to the existing comments list
        final newComment = response['data'];
        // ignore: invalid_use_of_protected_member
        final currentComments = reelComments.value[reelId] ?? [];

        if (parentCommentId != null) {
          // If it's a reply, insert it after the parent comment
          final parentIndex =
              currentComments.indexWhere((c) => c['_id'] == parentCommentId);
          if (parentIndex != -1) {
            currentComments.insert(parentIndex + 1, newComment);
          } else {
            currentComments.add(newComment);
          }
        } else {
          // If it's a top-level comment, add it to the beginning
          currentComments.insert(0, newComment);
        }

        reelComments.value = {
          // ignore: invalid_use_of_protected_member
          ...reelComments.value,
          reelId: currentComments,
        };
        reelComments.refresh();
      }
    });
  }

  Future<List<ReelModel>> getReelsByTag(String tagName) async {
    return await handleAsync<List<ReelModel>>(
          () async {
            final tagReels = await _reelRepository.getReelsByTag(tagName);
            // Replace the active list so the reels feed actually shows
            // the tag-filtered set. Without this, the previous version
            // returned the data but the page kept rendering whatever was
            // already on screen — selecting a tag had no visible effect.
            currentPage.value = 1;
            hasMorePages.value = false;
            reels.value = tagReels;
            isRecommendationMode.value = false;
            update();
            return tagReels;
          },
          showLoading: true,
        ) ??
        [];
  }

  Future<void> fetchTrendingReels({bool refresh = false}) async {
    if (refresh) {
      currentPage.value = 1;
      hasMorePages.value = true;
      reels.clear();
    }

    await handleAsync<void>(
      () async {
        final response = await _reelRepository.getTrendingReels();
        final List<ReelModel> trendingReels = (response['data']['data'] as List)
            .map((reel) => ReelModel.fromJson(reel))
            .toList();
        reels.value = trendingReels;
        isRecommendationMode.value = false;
        update(); // Notify GetBuilder listeners
      },
      showLoading: reels.isEmpty,
      isRefresh: refresh,
    );
  }

  Future<List<Map<String, dynamic>>> fetchComments(String reelId) async {
    return await handleAsync<List<Map<String, dynamic>>>(
          () async {
            final comments = await _reelRepository.getComments(reelId);
            reelComments[reelId] = comments;
            reelComments.refresh();
            return comments;
          },
          showLoading: false,
        ) ??
        [];
  }

  Future<void> toggleLike(String reelId) async {
    try {
      final reelIndex = reels.indexWhere((reel) => reel.id == reelId);
      if (reelIndex == -1) return;

      final originalReel = reels[reelIndex];
      final isCurrentlyLiked = originalReel.like['isLiked'] == true;
      final currentCount = originalReel.like['count'] ?? 0;

      // Calculate new state (toggle)
      final newIsLiked = !isCurrentlyLiked;
      final newCount = newIsLiked ? currentCount + 1 : currentCount - 1;

      // Optimistically update UI immediately
      final optimisticLikeData = {
        'count': newCount < 0 ? 0 : newCount,
        'isLiked': newIsLiked,
      };

      reels[reelIndex] = originalReel.copyWith(like: optimisticLikeData);
      reels.refresh();

      // Track engagement
      if (newIsLiked) {
        _engagementService.trackReelLike(reelId);
      }

      // Fire and forget - don't await the API call
      // This ensures the UI stays responsive even with slow network
      _performLikeApiCall(reelId, isCurrentlyLiked, reelIndex, originalReel, newIsLiked);
    } catch (e) {
      // Silent fail for likes, don't show error screen
      debugPrint('Toggle like error: $e');
    }
  }

  /// Performs the like/unlike API call in the background
  /// Only reverts the UI on specific business logic errors, NOT on timeouts
  Future<void> _performLikeApiCall(
    String reelId,
    bool wasLiked,
    int reelIndex,
    ReelModel originalReel,
    bool newIsLiked,
  ) async {
    try {
      Map<String, dynamic> response;
      if (wasLiked) {
        // Was liked, now unliking
        response = await _reelRepository.unlikeReel(reelId);
      } else {
        // Was not liked, now liking
        response = await _reelRepository.likeReel(reelId);
      }

      // Server responded successfully - update count if provided
      if (response['status'] == 'success' &&
          response['data'] != null &&
          response['data']['like'] != null) {
        final serverLikeData = response['data']['like'];
        final serverCount = serverLikeData['count'];
        if (serverCount != null && reelIndex < reels.length) {
          // Verify the reel is still at the same index
          if (reels[reelIndex].id == originalReel.id) {
            reels[reelIndex] = originalReel.copyWith(like: {
              'count': serverCount,
              'isLiked': newIsLiked,
            });
            reels.refresh();
          }
        }
      }
    } catch (e) {
      // DON'T revert on timeout or connection errors - the operation may have succeeded
      // Only revert on specific business logic errors
      final errorString = e.toString().toLowerCase();
      final isTimeoutOrConnectionError = errorString.contains('timeout') ||
          errorString.contains('connection') ||
          errorString.contains('circuit breaker');

      if (!isTimeoutOrConnectionError) {
        // Only revert for actual business logic errors (like 404, 400, etc.)
        if (reelIndex < reels.length && reels[reelIndex].id == originalReel.id) {
          reels[reelIndex] = originalReel;
          reels.refresh();
        }
      }
      // Log but don't revert for timeout/connection errors
      debugPrint('Toggle like API error: $e');
    }
  }

  /// Record that a user viewed a reel (for recommendation engine)
  Future<void> recordReelView(String reelId, {int? watchDuration, double? completionRate}) async {
    // Only record each view once per session
    if (_viewedReelIds.contains(reelId)) return;
    _viewedReelIds.add(reelId);

    // Track in engagement service
    _engagementService.trackReelView(reelId, watchDuration: watchDuration, completionRate: completionRate);

    // Fire and forget — but with a `.catchError` so a failed recommendation
    // ping doesn't surface as an unhandled future. The view itself is
    // best-effort telemetry; the next fetch will reconcile recommendations.
    _reelRepository
        .recordInteraction(reelId, InteractionType.view)
        .catchError((_) {});
  }

  /// Record reel completion
  void recordReelComplete(String reelId, int watchDuration) {
    _engagementService.trackReelComplete(reelId, watchDuration);
  }

  /// Record share interaction
  Future<void> recordShare(String reelId) async {
    await _reelRepository.recordInteraction(reelId, InteractionType.share);
  }

  /// Fetch user's interest profile
  Future<void> fetchUserInterests() async {
    try {
      final interests = await _reelRepository.getUserInterests();
      userInterests.value = interests;
    } catch (e) {
      // Silent fail
    }
  }

  /// Initialize user interests from their like history
  Future<void> initializeUserInterests() async {
    try {
      final interests = await _reelRepository.initializeUserInterests();
      userInterests.value = interests;
    } catch (e) {
      // Silent fail
    }
  }

  /// Get the current feed mode label
  String get currentFeedMode {
    return isRecommendationMode.value ? 'For You' : 'Trending';
  }

  /// Check if user has interests (for showing recommended vs trending)
  bool get hasUserInterests {
    return userInterests.value != null &&
        userInterests.value!.interests.isNotEmpty;
  }
}
