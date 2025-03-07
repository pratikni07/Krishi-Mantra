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

      hasError.value = false;
      errorMessage.value = '';
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

      final video = await _repository.getVideoById(videoId);
      currentVideo.value = video;

      // Fetch related videos
      final related = await _repository.getRelatedVideos(videoId);
      relatedVideos.value = related;

      // Fetch comments
      await fetchComments(videoId);
    } catch (e) {
      hasError.value = true;
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchComments(String videoId) async {
    try {
      isLoadingComments.value = true;
      final response = await _repository.getComments(videoId);
      comments.value =
          List<Map<String, dynamic>>.from(response['data']['data']);
    } catch (e) {
      Get.snackbar('Error', 'Failed to load comments');
    } finally {
      isLoadingComments.value = false;
    }
  }

  Future<void> toggleVideoLike(String videoId) async {
    try {
      await _repository.toggleLike(videoId);

      // Update local state
      final video = currentVideo.value;
      if (video != null) {
        final userId = currentUserId;
        if (userId != null) {
          final hasLiked = video.likes.users.contains(userId);
          final updatedLikes = VideoStats(
            count: hasLiked ? video.likes.count - 1 : video.likes.count + 1,
            users: hasLiked
                ? video.likes.users.where((id) => id != userId).toList()
                : [...video.likes.users, userId],
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
            likes: updatedLikes,
            views: video.views,
            comments: video.comments,
            createdAt: video.createdAt,
            updatedAt: video.updatedAt,
          );
        }
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to toggle like');
    }
  }

  Future<void> addComment(String videoId, String content,
      {String? parentCommentId}) async {
    try {
      final response = await _repository.addComment(
        videoId,
        content: content,
        parentComment: parentCommentId,
      );

      // If it's a reply, update the parent comment's replies
      if (parentCommentId != null) {
        final parentIndex =
            comments.indexWhere((c) => c['_id'] == parentCommentId);
        if (parentIndex != -1) {
          final parent = comments[parentIndex];
          final replies = List.from(parent['replies'] ?? []);
          replies.add(response['data']);
          comments[parentIndex] = {
            ...parent,
            'replies': replies,
          };
        }
      } else {
        // Add new comment to the top
        comments.insert(0, response['data']);
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
            count: video.comments.count + 1,
            users: video.comments.users,
          ),
          createdAt: video.createdAt,
          updatedAt: video.updatedAt,
        );
      }
    } catch (e) {
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
}
