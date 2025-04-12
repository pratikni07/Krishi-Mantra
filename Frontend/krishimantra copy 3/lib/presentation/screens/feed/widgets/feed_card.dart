// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:share_plus/share_plus.dart';
import 'package:get/get.dart';
import '../../../../data/models/feed_model.dart';
import '../FeedDetailsScreen.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';

// Create a global controller to manage active videos
class VideoController extends GetxController {
  static VideoController get instance => Get.find<VideoController>();
  Rx<String?> currentlyPlayingVideoUrl = Rx<String?>(null);

  void setCurrentlyPlaying(String? url) {
    currentlyPlayingVideoUrl.value = url;
  }
}

class FeedCard extends StatefulWidget {
  final FeedModel feed;
  final VoidCallback onLike;
  final VoidCallback? onSave;

  const FeedCard({
    super.key,
    required this.feed,
    required this.onLike,
    this.onSave,
  });

  @override
  State<FeedCard> createState() => _FeedCardState();
}

class _FeedCardState extends State<FeedCard> {
  bool _isExpanded = false;
  bool _isVideoPlaying = false;
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  Widget _buildHashtagText(String content) {
    final words = content.split(' ');
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          color: Colors.black,
          fontSize: 15,
          height: 1.4,
        ),
        children: words.map((word) {
          if (word.startsWith('#')) {
            return TextSpan(
              text: '$word ',
              style: const TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.w500,
              ),
            );
          }
          return TextSpan(text: '$word ');
        }).toList(),
      ),
    );
  }

  Widget _buildContent(String content) {
    const int maxWords = 100;
    final words = content.split(' ');

    if (words.length <= maxWords || _isExpanded) {
      return _buildHashtagText(content);
    }

    final truncatedContent = words.take(maxWords).join(' ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHashtagText('$truncatedContent...'),
        GestureDetector(
          onTap: () => setState(() => _isExpanded = true),
          child: const Padding(
            padding: EdgeInsets.only(top: 8.0),
            child: Text(
              'Show more',
              style: TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showShareBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Share via',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildShareOption(
                  context,
                  'Copy Link',
                  Icons.link,
                  Colors.grey,
                  () => Navigator.pop(context),
                ),
                _buildShareOption(
                  context,
                  'WhatsApp',
                  Icons.facebook,
                  Colors.green,
                  () {
                    Share.share(widget.feed.content);
                    Navigator.pop(context);
                  },
                ),
                _buildShareOption(
                  context,
                  'Facebook',
                  Icons.facebook,
                  Colors.blue,
                  () {
                    Share.share(widget.feed.content);
                    Navigator.pop(context);
                  },
                ),
                _buildShareOption(
                  context,
                  'Twitter',
                  Icons.flutter_dash,
                  Colors.lightBlue,
                  () {
                    Share.share(widget.feed.content);
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShareOption(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User Info Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.grey.shade200,
                      width: 2,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 24,
                    backgroundImage: widget.feed.profilePhoto.isNotEmpty &&
                            Uri.parse(widget.feed.profilePhoto).isAbsolute
                        ? NetworkImage(widget.feed.profilePhoto)
                        : const AssetImage('assets/images/default_profile.png')
                            as ImageProvider,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.feed.userName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Uploaded ${timeago.format(widget.feed.date)}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                      // if (widget.feed.location != null)
                      //   Row(
                      //     children: [
                      //       const Icon(
                      //         Icons.location_on,
                      //         size: 14,
                      //         color: AppColors.textGrey,
                      //       ),
                      //       const SizedBox(width: 4),
                      //       Text(
                      //         widget.feed.location?['name'] ?? '',
                      //         style: const TextStyle(
                      //           color: AppColors.textGrey,
                      //           fontSize: 12,
                      //         ),
                      //       ),
                      //     ],
                      //   ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Media Content
          if (widget.feed.mediaUrl != null)
            _buildMediaContent(widget.feed.mediaUrl!),

          // Text Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildContent(widget.feed.content),
          ),

          // Actions Section with equal spacing
          // Find this section in the Padding widget with Row children inside your FeedCard
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  icon: widget.feed.isLiked
                      ? Icons.favorite
                      : Icons.favorite_border,
                  color: widget.feed.isLiked ? Colors.red : Colors.grey,
                  count: widget.feed.like['count'] ?? 0,
                  onTap: widget.onLike,
                ),
                _buildActionButton(
                  icon: Icons.comment_outlined,
                  color: Colors.grey,
                  count: widget.feed.comment['count'] ?? 0,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            FeedDetailsScreen(feed: widget.feed.toJson()),
                      ),
                    );
                  },
                ),
                _buildActionButton(
                  icon: Icons.share_outlined,
                  color: Colors.grey,
                  onTap: () => _showShareBottomSheet(context),
                ),
                _buildActionButton(
                  icon: Icons.bookmark_border,
                  color: Colors.grey,
                  onTap: widget.onSave,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaContent(String url) {
    // Add URL validation to prevent errors with empty or invalid URLs
    if (url.isEmpty || url == "file:///" || !Uri.parse(url).isAbsolute) {
      return Container(
        width: double.infinity,
        height: 200,
        color: Colors.grey.withOpacity(0.2),
        child: const Center(
          child: Icon(
            Icons.broken_image,
            color: Colors.grey,
            size: 48,
          ),
        ),
      );
    }

    // Check if the URL is a video based on common video extensions or domains
    bool isVideo = url.toLowerCase().endsWith('.mp4') ||
        url.toLowerCase().endsWith('.mov') ||
        url.toLowerCase().endsWith('.avi') ||
        url.contains('commondatastorage.googleapis.com/gtv-videos-bucket');

    if (isVideo) {
      if (!_isVideoPlaying) {
        // Show thumbnail with play button when video is not playing
        return GestureDetector(
          onTap: () {
            _initializeAndPlayVideo(url);
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: double.infinity,
                height: 200,
                color: Colors.black.withOpacity(0.1),
                child: const Center(
                  child: Text(
                    'Video Content',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 48,
                ),
              ),
            ],
          ),
        );
      } else {
        // Show video player when video is playing
        if (_chewieController != null) {
          return AspectRatio(
            aspectRatio: _chewieController!.aspectRatio ?? 16 / 9,
            child: Chewie(controller: _chewieController!),
          );
        } else {
          // Show loading indicator while video initializes
          return Container(
            height: 200,
            color: Colors.black.withOpacity(0.1),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
      }
    } else {
      // For images, use the existing image display with error handling
      return Image.network(
        url,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: double.infinity,
            height: 200,
            color: Colors.grey.withOpacity(0.2),
            child: const Center(
              child: Icon(
                Icons.broken_image,
                color: Colors.grey,
                size: 48,
              ),
            ),
          );
        },
      );
    }
  }

  void _initializeAndPlayVideo(String videoUrl) async {
    setState(() {
      _isVideoPlaying = true;
    });

    try {
      // Initialize the video player
      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(videoUrl),
      );

      await _videoPlayerController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        autoPlay: true,
        looping: false,
        showControls: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.green,
          handleColor: Colors.greenAccent,
          backgroundColor: Colors.grey,
          bufferedColor: Colors.lightGreen,
        ),
        placeholder: Container(
          color: Colors.black.withOpacity(0.1),
        ),
        errorBuilder: (context, errorMessage) {
          setState(() {
            _isVideoPlaying = false;
          });
          return Center(
            child: Text(
              'Error loading video: $errorMessage',
              style: const TextStyle(color: Colors.white),
            ),
          );
        },
      );

      // This will trigger a rebuild to show the video player
      setState(() {});
    } catch (e) {
      print('Error initializing video player: $e');
      setState(() {
        _isVideoPlaying = false;
      });
    }
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    int? count,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            if (count != null) ...[
              const SizedBox(width: 4),
              Text(
                count.toString(),
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
