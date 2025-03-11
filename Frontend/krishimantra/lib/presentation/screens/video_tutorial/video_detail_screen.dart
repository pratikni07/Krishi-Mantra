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
import '../../widgets/ShareBottomSheet.dart';

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
  final GlobalKey _commentSectionKey = GlobalKey();

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
      body: Stack(
        children: [
          // Main content with scrolling
          SingleChildScrollView(
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
                        videoId =
                            url.split('youtube.com/embed/')[1].split('?')[0];
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
                  child: Obx(() {
                    if (controller.currentVideo.value == null) {
                      return const SizedBox.shrink();
                    }

                    final video = controller.currentVideo.value!;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title with proper null check and style
                        Text(
                          video.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Action buttons (like, comment, share)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            // Like button
                            _buildActionButton(
                              icon: controller.currentVideo.value?.likes.users
                                          .contains(controller.currentUserId) ??
                                      false
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              label: '${_formatCount(video.likes.count)}',
                              color: controller.currentVideo.value?.likes.users
                                          .contains(controller.currentUserId) ??
                                      false
                                  ? Colors.red
                                  : Colors.grey,
                              onTap: () {
                                controller.toggleVideoLike(video.id);
                              },
                            ),

                            // Comment button
                            _buildActionButton(
                              icon: Icons.comment,
                              label: '${_formatCount(video.comments.count)}',
                              color: Colors.grey,
                              onTap: () {
                                // Scroll to comments section
                                Scrollable.ensureVisible(
                                  _commentSectionKey.currentContext!,
                                  duration: const Duration(milliseconds: 300),
                                );
                              },
                            ),

                            // Share button
                            _buildActionButton(
                              icon: Icons.share,
                              label: 'Share',
                              color: Colors.grey,
                              onTap: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (context) => ShareBottomSheet(
                                    postUrl: video.videoUrl,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),

                        const Divider(height: 24),

                        // Views and date
                        Row(
                          children: [
                            Text(
                              '${_formatViews(video.views.count)} views',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '•',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              timeago.format(video.createdAt),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Description with show more/less and tags
                        if (video.description != null)
                          ExpandableText(
                            text: video.description!,
                            maxLines: 3,
                            tags: video.tags,
                          ),

                        const SizedBox(height: 16),

                        // Channel/User info
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundImage: video.profilePhoto != null
                                  ? CachedNetworkImageProvider(
                                      video.profilePhoto!)
                                  : null,
                              child: video.profilePhoto == null
                                  ? Text(
                                      video.userName
                                          .substring(0, 1)
                                          .toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                video.userName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const Divider(height: 24),

                        // Comments section (with key for scrolling)
                        Container(key: _commentSectionKey),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Comments',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        // Comments list
                        Obx(() {
                          if (controller.isLoadingComments.value) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }

                          if (controller.comments.isEmpty) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text(
                                    'No comments yet. Be the first to comment!'),
                              ),
                            );
                          }

                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: controller.comments.length,
                            itemBuilder: (context, index) {
                              final comment = controller.comments[index];
                              return _buildCommentTile(comment);
                            },
                          );
                        }),

                        // Add space for the fixed comment box
                        const SizedBox(height: 70),
                      ],
                    );
                  }),
                ),
              ],
            ),
          ),

          // Fixed comment input box at the bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: TextField(
                        controller: _commentController,
                        decoration: InputDecoration(
                          hintText: 'Add a comment...',
                          hintStyle: TextStyle(color: Colors.grey[600]),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        maxLines: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: const BoxDecoration(
                      color: AppColors.green,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send, size: 20),
                      color: Colors.white,
                      onPressed: () async {
                        if (_commentController.text.trim().isNotEmpty) {
                          try {
                            await controller.addComment(
                              widget.videoId,
                              _commentController.text.trim(),
                            );
                            _commentController.clear();
                            await controller.fetchComments(widget.videoId);
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
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentTile(Map<String, dynamic> comment) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.grey[200],
            backgroundImage: comment['profilePhoto'] != null
                ? CachedNetworkImageProvider(comment['profilePhoto'])
                : null,
            child: comment['profilePhoto'] == null
                ? Text(
                    comment['userName']?.substring(0, 1).toUpperCase() ?? '?',
                    style: TextStyle(
                      color: Colors.grey[600],
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
                Row(
                  children: [
                    Text(
                      comment['userName'] ?? 'Unknown',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
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
                Text(comment['content'] ?? ''),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ExpandableText extends StatefulWidget {
  final String text;
  final int maxLines;
  final List<String> tags;

  const ExpandableText({
    Key? key,
    required this.text,
    this.maxLines = 3,
    this.tags = const [],
  }) : super(key: key);

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.text,
          maxLines: _expanded ? null : widget.maxLines,
          overflow: _expanded ? null : TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.grey[800],
            fontSize: 14,
            height: 1.4,
          ),
        ),
        
        // Show tags only when expanded
        if (_expanded && widget.tags.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.tags.map((tag) {
              // Split by comma if needed
              final tags = tag.contains(',') 
                  ? tag.split(',') 
                  : [tag];
              
              return Wrap(
                spacing: 8,
                children: tags.map((t) => 
                  Container(
                    margin: const EdgeInsets.only(right: 4, bottom: 4),
                    child: Text(
                      '#${t.trim()}',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                ).toList(),
              );
            }).toList(),
          ),
        ],
        
        GestureDetector(
          onTap: () {
            setState(() {
              _expanded = !_expanded;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              _expanded ? 'Show less' : 'Show more',
              style: TextStyle(
                color: Colors.grey[700],
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
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
