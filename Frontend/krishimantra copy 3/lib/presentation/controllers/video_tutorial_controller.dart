import 'package:get/get.dart';
import 'package:krishimantra/data/models/video_tutorial.dart';

import 'package:krishimantra/data/repositories/video_tutorial_repository.dart';
import 'package:krishimantra/data/services/UserService.dart';

class VideoTutorialController extends GetxController {
  final VideoTutorialRepository _repository;
  final UserService _userService;

  VideoTutorialController(this._repository, this._userService);

  // Observables
  final videos = <VideoTutorial>[].obs;
  final currentVideo = Rxn<VideoTutorial>();
  final relatedVideos = <VideoTutorial>[].obs;
  final comments = <Map<String, dynamic>>[].obs;
  final isLoading = false.obs;
  final hasError = false.obs;
  final errorMessage = ''.obs;

  // Pagination
  final currentPage = 1.obs;
  final totalPages = 1.obs;
  final totalItems = 0.obs;
  final itemsPerPage = 12.obs;
  final hasMoreVideos = true.obs;
  final isLoadingMore = false.obs;

//   final isLoadingMore = false.obs;
// final currentPage = 1.obs;
  final hasMoreComments = true.obs;

  // Video player state
  final isPlaying = false.obs;
  final currentPosition = Duration.zero.obs;
  final videoDuration = Duration.zero.obs;

  // Video details
  final isLoadingComments = false.obs;

  // Current user ID getter
  String? get currentUserId => _userService.currentUser?.id;

  @override
  void onInit() {
    super.onInit();
    fetchVideos();
  }

//   Future<void> loadMoreComments(String videoId) async {
//   if (!hasMoreComments.value || isLoadingMore.value) return;

//   try {
//     isLoadingMore.value = true;
//     final response = await _repository.getComments(
//       videoId,
//       page: currentPage.value + 1,
//     );

//     final newComments = List<Map<String, dynamic>>.from(response['data']['data']);
//     if (newComments.isEmpty) {
//       hasMoreComments.value = false;
//     } else {
//       comments.addAll(newComments);
//       currentPage.value++;
//     }
//   } catch (e) {
//     Get.snackbar('Error', 'Failed to load more comments');
//   } finally {
//     isLoadingMore.value = false;
//   }
// }

  Future<void> fetchVideos({bool refresh = false}) async {
    if (refresh) {
      currentPage.value = 1;
      hasMoreVideos.value = true;
      videos.clear();
    }

    if (!hasMoreVideos.value || isLoadingMore.value) return;

    try {
      if (videos.isEmpty) {
        isLoading.value = true;
      } else {
        isLoadingMore.value = true;
      }

      hasError.value = false;
      errorMessage.value = '';

      final newVideos = await _repository.getVideos(
        page: currentPage.value,
        limit: itemsPerPage.value,
      );

      if (newVideos.isEmpty) {
        hasMoreVideos.value = false;
      } else {
        videos.addAll(newVideos);
        currentPage.value++;
      }
    } catch (e) {
      hasError.value = true;
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
      isLoadingMore.value = false;
    }
  }

  Future<void> loadVideoDetails(String videoId) async {
    try {
      isLoading.value = true;
      hasError.value = false;

      // Get non-null user ID or use a placeholder for anonymous views
      final userId = currentUserId ?? 'anonymous';
      
      final videoData = await _repository.getVideoById(videoId);
      VideoTutorial video = VideoTutorial.fromJson(videoData);
      
      // Check if the user has already viewed this video
      bool alreadyViewed = video.views.users.contains(userId);
      
      // Only update view count on first view for this user
      if (!alreadyViewed && currentUserId != null) {
        // Create updated views with the user added and count increased
        VideoStats updatedViews = VideoStats(
          count: video.views.count + 1,
          users: [...video.views.users, userId],
        );
        
        // Create a new video object with the updated views
        video = VideoTutorial(
          id: video.id,
          userId: video.userId,
          userName: video.userName,
          profilePhoto: video.profilePhoto,
          title: video.title,
          description: video.description,
          thumbnail: video.thumbnail,
          videoUrl: video.videoUrl,
          videoType: video.videoType,
          duration: video.duration,
          tags: video.tags,
          category: video.category,
          visibility: video.visibility,
          likes: video.likes,
          views: updatedViews,
          comments: video.comments,
          createdAt: video.createdAt,
          updatedAt: video.updatedAt,
        );
      }
      
      currentVideo.value = video;
      
      // Fetch related videos
      final related = await _repository.getRelatedVideos(videoId);
      relatedVideos.value = related;

      // Fetch comments
      await fetchComments(videoId);
    } catch (e) {
      print('Error loading video details: $e');
      hasError.value = true;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchComments(String videoId, {bool refresh = false}) async {
    try {
      if (refresh) {
        comments.clear();
        currentPage.value = 1;
        hasMoreComments.value = true;
      }

      if (!hasMoreComments.value) return;

      isLoadingComments.value = true;

      final response = await _repository.getComments(
        videoId,
        page: currentPage.value,
        limit: 10,
      );

      // Debug - print the response to see its structure
      print('Comments response: ${response}');

      // Check if the data structure matches what we expect
      if (response['data'] != null) {
        final commentData = response['data'] is List
            ? response['data']
            : (response['data']['data'] != null
                ? response['data']['data']
                : []);

        if (commentData.isEmpty) {
          hasMoreComments.value = false;
        } else {
          currentPage.value++;
          List<Map<String, dynamic>> newComments = [];

          for (var item in commentData) {
            newComments.add(Map<String, dynamic>.from(item));
          }

          comments.addAll(newComments);
        }
      } else {
        hasMoreComments.value = false;
      }
    } catch (e) {
      print('Error fetching comments: $e');
      Get.snackbar('Error', 'Failed to load comments: $e');
    } finally {
      isLoadingComments.value = false;
    }
  }

  Future<void> toggleLike(String videoId) async {
    try {
      // Need non-null user ID
      if (currentUserId == null) {
        Get.snackbar('Error', 'You need to be logged in to like videos');
        return;
      }
      
      // Store current state
      final video = currentVideo.value;
      if (video == null) return;
      
      // Determine current like state
      final bool isCurrentlyLiked = video.likes.users.contains(currentUserId!);
      
      // Apply optimistic update immediately
      VideoStats updatedLikes = VideoStats(
        count: isCurrentlyLiked ? video.likes.count - 1 : video.likes.count + 1,
        users: isCurrentlyLiked 
          ? video.likes.users.where((id) => id != currentUserId).toList()
          : [...video.likes.users, currentUserId!],
      );
      
      // Update UI immediately with optimistic change
      currentVideo.value = VideoTutorial(
        id: video.id,
        userId: video.userId,
        userName: video.userName,
        profilePhoto: video.profilePhoto,
        title: video.title,
        description: video.description,
        thumbnail: video.thumbnail,
        videoUrl: video.videoUrl,
        videoType: video.videoType,
        duration: video.duration,
        tags: video.tags,
        category: video.category,
        visibility: video.visibility,
        likes: updatedLikes,
        views: video.views,
        comments: video.comments,
        createdAt: video.createdAt,
        updatedAt: video.updatedAt,
      );
      currentVideo.refresh();
      
      // Call the API
      final response = await _repository.toggleLike(videoId);
      
      // If API response differs from our optimistic update, correct the UI
      final serverLiked = response['data']?['liked'] ?? !isCurrentlyLiked;
      final serverLikesCount = response['data']?['likesCount'] ?? updatedLikes.count;
      
      if (serverLiked != !isCurrentlyLiked || serverLikesCount != updatedLikes.count) {
        // Server response different from our prediction, update UI with correct data
        VideoStats serverLikes = VideoStats(
          count: serverLikesCount,
          users: serverLiked 
            ? [...video.likes.users.where((id) => id != currentUserId).toList(), currentUserId!]
            : video.likes.users.where((id) => id != currentUserId).toList(),
        );
        
        currentVideo.value = VideoTutorial(
          id: video.id,
          userId: video.userId,
          userName: video.userName,
          profilePhoto: video.profilePhoto,
          title: video.title,
          description: video.description,
          thumbnail: video.thumbnail,
          videoUrl: video.videoUrl,
          videoType: video.videoType,
          duration: video.duration,
          tags: video.tags,
          category: video.category,
          visibility: video.visibility,
          likes: serverLikes,
          views: video.views,
          comments: video.comments,
          createdAt: video.createdAt,
          updatedAt: video.updatedAt,
        );
        currentVideo.refresh();
      }
    } catch (e) {
      print('Error toggling like: $e');
      Get.snackbar('Error', 'Failed to toggle like');
      
      // Revert to original state on error
      await loadVideoDetails(videoId);
    }
  }

  Future<void> addComment(String videoId, String content) async {
    try {
      final response = await _repository.addComment(
        videoId,
        {
          'userId': currentUserId,
          'userName': _userService.currentUser?.name ?? 'Anonymous',
          'profilePhoto': _userService.currentUser?.image,
          'content': content,
          // Don't include parentComment field for parent comments
        },
      );

      // Add the new comment to the local list
      if (response['status'] == 'success' && response['data'] != null) {
        final newComment = response['data'];
        comments.insert(
            0, Map<String, dynamic>.from(newComment)); // Add at the beginning
      }

      // Refresh comments to ensure everything is in sync
      await fetchComments(videoId, refresh: true);
    } catch (e) {
      print('Error adding comment: $e');
      Get.snackbar('Error', 'Failed to add comment');
      rethrow;
    }
  }

  Future<void> deleteComment(String commentId) async {
    try {
      await _repository.deleteComment(commentId);

      // Find and remove the comment (could be a parent or child)
      int parentIndex = -1;
      int replyIndex = -1;

      // First check if it's a parent comment
      parentIndex = comments.indexWhere((c) => c['_id'] == commentId);
      if (parentIndex != -1) {
        comments.removeAt(parentIndex);
      } else {
        // If not found as parent, look for it in replies
        for (var i = 0; i < comments.length; i++) {
          final replies = List.from(comments[i]['replies'] ?? []);
          replyIndex = replies.indexWhere((r) => r['_id'] == commentId);
          if (replyIndex != -1) {
            replies.removeAt(replyIndex);
            comments[i] = {
              ...comments[i],
              'replies': replies,
            };
            break;
          }
        }
      }

      // Update comment count in current video
      final video = currentVideo.value;
      if (video != null) {
        currentVideo.value = VideoTutorial(
          id: video.id,
          userId: video.userId,
          userName: video.userName,
          profilePhoto: video.profilePhoto,
          title: video.title,
          description: video.description,
          thumbnail: video.thumbnail,
          videoUrl: video.videoUrl,
          videoType: video.videoType,
          duration: video.duration,
          tags: video.tags,
          category: video.category,
          visibility: video.visibility,
          likes: video.likes,
          views: video.views,
          comments: VideoStats(
            count: video.comments.count - 1,
            users: video.comments.users,
          ),
          createdAt: video.createdAt,
          updatedAt: video.updatedAt,
        );
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to delete comment');
      rethrow;
    }
  }

  Future<void> toggleCommentLike(String commentId) async {
    try {
      await _repository.toggleCommentLike(commentId);

      // Find and update the comment (could be a parent or child)
      int parentIndex = -1;
      int replyIndex = -1;

      // First check if it's a parent comment
      parentIndex = comments.indexWhere((c) => c['_id'] == commentId);
      if (parentIndex != -1) {
        final comment = comments[parentIndex];
        final hasLiked = comment['likes']['users'].contains(currentUserId);
        comments[parentIndex] = {
          ...comment,
          'likes': {
            'count': hasLiked
                ? comment['likes']['count'] - 1
                : comment['likes']['count'] + 1,
            'users': hasLiked
                ? (comment['likes']['users'] as List)
                    .where((id) => id != currentUserId)
                    .toList()
                : [...(comment['likes']['users'] as List), currentUserId],
          },
        };
      } else {
        // If not found as parent, look for it in replies
        for (var i = 0; i < comments.length; i++) {
          final replies = List.from(comments[i]['replies'] ?? []);
          replyIndex = replies.indexWhere((r) => r['_id'] == commentId);
          if (replyIndex != -1) {
            final reply = replies[replyIndex];
            final hasLiked = reply['likes']['users'].contains(currentUserId);
            replies[replyIndex] = {
              ...reply,
              'likes': {
                'count': hasLiked
                    ? reply['likes']['count'] - 1
                    : reply['likes']['count'] + 1,
                'users': hasLiked
                    ? (reply['likes']['users'] as List)
                        .where((id) => id != currentUserId)
                        .toList()
                    : [...(reply['likes']['users'] as List), currentUserId],
              },
            };
            comments[i] = {
              ...comments[i],
              'replies': replies,
            };
            break;
          }
        }
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to toggle comment like');
      rethrow;
    }
  }

  // Video player controls
  void updatePlayingState(bool isPlaying) {
    this.isPlaying.value = isPlaying;
  }

  void updatePosition(Duration position) {
    currentPosition.value = position;
  }

  void updateDuration(Duration duration) {
    videoDuration.value = duration;
  }

  // Search videos
  Future<List<VideoTutorial>> searchVideos(String query) async {
    try {
      return await _repository.searchVideos(query);
    } catch (e) {
      Get.snackbar('Error', 'Failed to search videos');
      return [];
    }
  }

  // For adding a reply to a comment
  Future<void> addReply(
      String videoId, String parentCommentId, String content) async {
    try {
      final response = await _repository.addComment(
        videoId,
        {
          'userId': currentUserId,
          'userName': _userService.currentUser?.name ?? 'Anonymous',
          'profilePhoto': _userService.currentUser?.image,
          'content': content,
          'parentComment': parentCommentId, // Include parentComment for replies
        },
      );

      // Update local comments
      for (int i = 0; i < comments.length; i++) {
        if (comments[i]['_id'] == parentCommentId) {
          List<dynamic> replies = List.from(comments[i]['replies'] ?? []);
          replies.add(response['data']);
          comments[i] = {
            ...comments[i],
            'replies': replies,
          };
          break;
        }
      }
    } catch (e) {
      print('Error adding reply: $e');
      Get.snackbar('Error', 'Failed to add reply');
      rethrow;
    }
  }

  // Method to load more comments
  Future<void> loadMoreComments(String videoId) async {
    if (isLoadingMore.value || !hasMoreComments.value) return;

    isLoadingMore.value = true;
    try {
      await fetchComments(videoId);
    } catch (e) {
      print('Error loading more comments: $e');
    } finally {
      isLoadingMore.value = false;
    }
  }
}
