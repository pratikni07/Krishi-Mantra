import 'package:get/get.dart';
import '../../data/models/reel_model.dart';
import '../../data/repositories/reel_repository.dart';
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

  ReelController(this._reelRepository);

  Future<void> fetchReels({bool refresh = false}) async {
    if (refresh) {
      currentPage.value = 1;
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
      },
      showLoading: reels.isEmpty, // Only show loading if no reels yet
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
          () => _reelRepository.getReelsByTag(tagName),
          showLoading: true,
        ) ??
        [];
  }

  Future<void> fetchTrendingReels() async {
    await handleAsync<void>(
      () async {
        final response = await _reelRepository.getTrendingReels();
        final List<ReelModel> trendingReels = (response['data']['data'] as List)
            .map((reel) => ReelModel.fromJson(reel))
            .toList();
        reels.value = trendingReels;
      },
      showLoading: reels.isEmpty,
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

      final reel = reels[reelIndex];
      final isLiked = reel.like['isLiked'] ?? false;

      // Optimistically update UI
      final optimisticLikeData = {
        'count': isLiked
            ? (reel.like['count'] ?? 0) - 1
            : (reel.like['count'] ?? 0) + 1,
        'isLiked': !isLiked,
      };

      reels[reelIndex] = reel.copyWith(like: optimisticLikeData);
      reels.refresh();

      try {
        Map<String, dynamic> response;
        if (isLiked) {
          response = await _reelRepository.unlikeReel(reelId);
        } else {
          response = await _reelRepository.likeReel(reelId);
        }

        // Update with actual server response
        if (response['status'] == 'success' && response['data'] != null) {
          final updatedLikeData =
              response['data']['like'] ?? optimisticLikeData;
          reels[reelIndex] = reel.copyWith(like: updatedLikeData);
          reels.refresh();
        }
      } catch (e) {
        // Revert optimistic update on error
        reels[reelIndex] = reel;
        reels.refresh();
        throw e;
      }
    } catch (e) {
      // Silent fail for likes, don't show error screen
      // Just log the error or show a minimal indicator
      setError(e);
    }
  }
}
