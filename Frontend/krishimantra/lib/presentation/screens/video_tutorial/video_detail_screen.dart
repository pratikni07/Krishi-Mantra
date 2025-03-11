// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:krishimantra/data/models/video_tutorial.dart';
import 'package:krishimantra/presentation/controllers/video_tutorial_controller.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/colors.dart';

class VideoDetailScreen extends StatefulWidget {
  final String videoId;

  const VideoDetailScreen({
    Key? key,
    required this.videoId,
  }) : super(key: key);

  @override
  State<VideoDetailScreen> createState() => _VideoDetailScreenState();
}

class _VideoDetailScreenState extends State<VideoDetailScreen> {
  final VideoTutorialController controller =
      Get.find<VideoTutorialController>();
  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Load data after the widget is built using a post-frame callback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.loadVideoDetails(widget.videoId);
      controller.fetchComments(widget.videoId);
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Details'),
        backgroundColor: AppColors.green,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Video player section
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (controller.currentVideo.value == null) {
                  return Container(
                    color: Colors.black,
                    child: const Center(
                      child: Text(
                        'Video not available',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  );
                }

                final video = controller.currentVideo.value!;

                // Handle YouTube videos
                if (video.videoType == 'youtube') {
                  // Extract YouTube video ID
                  String? videoId;
                  final url = video.videoUrl;

                  if (url.contains('youtu.be/')) {
                    videoId = url.split('youtu.be/')[1].split('?')[0];
                  } else if (url.contains('youtube.com/watch')) {
                    final uri = Uri.tryParse(url);
                    videoId = uri?.queryParameters['v'];
                  } else if (url.contains('youtube.com/embed/')) {
                    videoId = url.split('youtube.com/embed/')[1].split('?')[0];
                  } else {
                    // For URLs like "https://youtu.be/SO7sm12Rlto?si=YHZRO-ddQl7CZ54i"
                    final segments = url.split('?');
                    if (segments.isNotEmpty &&
                        segments[0].contains('youtu.be/')) {
                      videoId = segments[0].split('youtu.be/').last;
                    }
                  }

                  if (videoId != null && videoId.isNotEmpty) {
                    try {
                      return YoutubePlayer(
                        controller: YoutubePlayerController(
                          initialVideoId: videoId,
                          flags: const YoutubePlayerFlags(
                            autoPlay: false,
                            mute: false,
                          ),
                        ),
                        showVideoProgressIndicator: true,
                      );
                    } catch (e) {
                      print('YouTube player error: $e');
                      // Fallback to error display
                    }
                  }
                }

                // Fallback for other video types or if YouTube ID extraction fails
                return Container(
                  color: Colors.black,
                  child: const Center(
                    child: Text(
                      'Video format not supported',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                );
              }),
            ),

            // Video info section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title with proper null check and style
                  Text(
                    controller.currentVideo.value?.title ?? 'Untitled',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Views, likes and date with proper formatting
                  Row(
                    children: [
                      Text(
                        '${_formatViews(controller.currentVideo.value?.views.count ?? 0)} views',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        ' • ',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${_formatCount(controller.currentVideo.value?.likes.count ?? 0)} likes',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        ' • ',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        timeago.format(
                          controller.currentVideo.value?.createdAt ??
                              DateTime.now(),
                          locale: 'en_short',
                        ),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Channel info with proper null checks
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundImage:
                            controller.currentVideo.value?.profilePhoto != null
                                ? CachedNetworkImageProvider(
                                    controller
                                        .currentVideo.value!.profilePhoto!,
                                  )
                                : null,
                        child:
                            controller.currentVideo.value?.profilePhoto == null
                                ? Text(
                                    controller.currentVideo.value?.userName
                                            .substring(0, 1)
                                            .toUpperCase() ??
                                        '?',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              controller.currentVideo.value?.userName ??
                                  'Unknown User',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            if (controller.currentVideo.value?.description !=
                                null)
                              Text(
                                controller.currentVideo.value!.description!,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          if (controller.currentVideo.value != null) {
                            controller.toggleVideoLike(
                                controller.currentVideo.value!.id);
                          }
                        },
                        icon: Icon(
                          controller.currentVideo.value!.likes.users
                                  .contains(controller.currentUserId)
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: controller.currentVideo.value!.likes.users
                                  .contains(controller.currentUserId)
                              ? Colors.red
                              : null,
                        ),
                      ),
                    ],
                  ),

                  // Tags section
                  if (controller.currentVideo.value?.tags.isNotEmpty ??
                      false) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: controller.currentVideo.value!.tags
                          .map((tag) => Chip(
                                label: Text(tag),
                                backgroundColor: Colors.grey[200],
                              ))
                          .toList(),
                    ),
                  ],

                  // Comments section
                  const Divider(height: 32),
                  _CommentSection(
                    controller: controller,
                    videoId: widget.videoId,
                    commentController: _commentController,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatViews(int views) {
    if (views >= 1000000) {
      return '${(views / 1000000).toStringAsFixed(1)}M';
    } else if (views >= 1000) {
      return '${(views / 1000).toStringAsFixed(1)}K';
    }
    return views.toString();
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}

class _CommentSection extends StatelessWidget {
  final VideoTutorialController controller;
  final String videoId;
  final TextEditingController commentController;
  final RxString replyingTo = ''.obs;
  final RxString replyingToId = ''.obs;

  _CommentSection({
    Key? key,
    required this.controller,
    required this.videoId,
    required this.commentController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Comments',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Obx(() {
          if (controller.isLoadingComments.value) {
            return const Center(child: CircularProgressIndicator());
          }

          if (controller.comments.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No comments yet. Be the first to comment!'),
              ),
            );
          }

          return ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: controller.comments.length,
            itemBuilder: (context, index) {
              final comment = controller.comments[index];
              if (comment['parentComment'] != null)
                return const SizedBox.shrink();

              return _buildCommentThread(context, comment);
            },
          );
        }),

        // Comment input section
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Show replying to indicator
              Obx(() {
                if (replyingTo.value.isNotEmpty) {
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Text(
                          'Replying to @${replyingTo.value}',
                          style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () {
                            replyingTo.value = '';
                            replyingToId.value = '';
                            commentController.clear();
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              }),

              // Comment input field
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: commentController,
                      decoration: const InputDecoration(
                        hintText: 'Add a comment...',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: () async {
                      if (commentController.text.trim().isNotEmpty) {
                        try {
                          await controller.addComment(
                            videoId,
                            commentController.text.trim(),
                            parentCommentId: replyingToId.value.isNotEmpty
                                ? replyingToId.value
                                : null,
                          );
                          commentController.clear();
                          replyingTo.value = '';
                          replyingToId.value = '';
                          await controller.fetchComments(videoId);
                        } catch (e) {
                          Get.snackbar(
                            'Error',
                            'Failed to add comment',
                            backgroundColor: Colors.red,
                            colorText: Colors.white,
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCommentThread(
      BuildContext context, Map<String, dynamic> comment) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CommentTile(
          comment: comment,
          onReply: () {
            replyingTo.value = comment['userName'];
            replyingToId.value = comment['_id'];
            commentController.text = '@${comment['userName']} ';
            commentController.selection = TextSelection.fromPosition(
              TextPosition(offset: commentController.text.length),
            );
            // Scroll to comment input
            Scrollable.ensureVisible(
              context,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          },
          onLike: () => controller.toggleCommentLike(comment['_id']),
          onDelete: controller.currentUserId == comment['userId']
              ? () => controller.deleteComment(comment['_id'])
              : null,
        ),

        // Show replies with indentation
        if (comment['replies'] != null && comment['replies'].isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 32.0),
            child: Column(
              children: [
                for (var reply in comment['replies'])
                  _CommentTile(
                    comment: reply,
                    onReply: () {
                      replyingTo.value = reply['userName'];
                      replyingToId.value =
                          comment['_id']; // Use parent comment ID
                      commentController.text = '@${reply['userName']} ';
                      commentController.selection = TextSelection.fromPosition(
                        TextPosition(offset: commentController.text.length),
                      );
                    },
                    onLike: () => controller.toggleCommentLike(reply['_id']),
                    onDelete: controller.currentUserId == reply['userId']
                        ? () => controller.deleteComment(reply['_id'])
                        : null,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CommentTile extends StatelessWidget {
  final Map<String, dynamic> comment;
  final VoidCallback onReply;
  final VoidCallback onLike;
  final VoidCallback? onDelete;

  const _CommentTile({
    Key? key,
    required this.comment,
    required this.onReply,
    required this.onLike,
    this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.grey[200],
            backgroundImage: comment['profilePhoto'] != null &&
                    !comment['profilePhoto'].toString().endsWith('.mp4')
                ? CachedNetworkImageProvider(comment['profilePhoto'])
                : null,
            child: comment['profilePhoto'] == null ||
                    comment['profilePhoto'].toString().endsWith('.mp4')
                ? Text(
                    comment['userName']?.substring(0, 1).toUpperCase() ?? '?',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
            onBackgroundImageError: (e, s) {
              print('Error loading profile image: $e');
              // Don't call setState here, just log the error
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment['userName'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeago.format(DateTime.parse(comment['createdAt'])),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(comment['content']),
                const SizedBox(height: 8),
                Row(
                  children: [
                    GestureDetector(
                      onTap: onLike,
                      child: Row(
                        children: [
                          Icon(
                            comment['likes']['users'].contains(
                                    Get.find<VideoTutorialController>()
                                        .currentUserId)
                                ? Icons.favorite
                                : Icons.favorite_border,
                            size: 16,
                            color: comment['likes']['users'].contains(
                                    Get.find<VideoTutorialController>()
                                        .currentUserId)
                                ? Colors.red
                                : Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            comment['likes']['count'].toString(),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: onReply,
                      child: Text(
                        'Reply',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (onDelete != null) ...[
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: onDelete,
                        child: Text(
                          'Delete',
                          style: TextStyle(
                            color: Colors.red[400],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
