import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:krishimantra/data/models/reel_model.dart';
import 'package:krishimantra/data/models/video_tutorial.dart';
import 'package:krishimantra/presentation/controllers/video_tutorial_controller.dart';
import 'package:krishimantra/presentation/controllers/reel_controller.dart';
import 'package:krishimantra/presentation/screens/video_tutorial/video_detail_screen.dart';
import 'package:krishimantra/presentation/screens/reel/reels_page.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/constants/colors.dart';
import 'package:video_player/video_player.dart';
import '../../../data/services/language_service.dart';
import 'package:krishimantra/core/utils/error_handler.dart';

class VideoListScreen extends GetView<VideoTutorialController> {
  final ReelController _reelController = Get.find<ReelController>();

  VideoListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.fetchVideos(refresh: true);
      _reelController.fetchReels(refresh: true);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mantra Videos',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.green,
        actions: [
          // IconButton(
          //   icon: const Icon(Icons.search),
          //   onPressed: () {
          //     // TODO: Implement search
          //   },
          // ),
          IconButton(
            icon: const Icon(
              Icons.refresh,
              color: Colors.white,
            ),
            onPressed: () => controller.fetchVideos(refresh: true),
          ),
        ],
      ),
      body: Obx(
        () {
          if (controller.hasError.value) {
            return ErrorHandler.getErrorWidget(
              errorType: ErrorType.unknown,
              onRetry: () => controller.fetchVideos(refresh: true),
              showRetry: true,
            );
          }

          if (controller.isLoading.value && controller.videos.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (controller.videos.isEmpty) {
            return const Center(
              child: Text('No videos found'),
            );
          }

          return RefreshIndicator(
            onRefresh: () => controller.fetchVideos(refresh: true),
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _calculateItemCount(),
              itemBuilder: (context, index) {
                // Check if this is a reel section
                if (_isReelSection(index)) {
                  return _buildReelSection();
                }

                // Calculate the actual video index
                final videoIndex = _getVideoIndex(index);

                if (videoIndex >= controller.videos.length) {
                  // Load more indicator
                  if (!controller.isLoadingMore.value) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      controller.fetchVideos();
                    });
                  }
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final video = controller.videos[videoIndex];
                return VideoCard(
                  video: video,
                  onTap: () =>
                      Get.to(() => VideoDetailScreen(videoId: video.id)),
                );
              },
            ),
          );
        },
      ),
    );
  }

  int _calculateItemCount() {
    final videoCount = controller.videos.length;
    return videoCount + 1 + (controller.hasMoreVideos.value ? 1 : 0);
  }

  bool _isReelSection(int index) {
    return index == 2;
  }

  int _getVideoIndex(int index) {
    return index > 2 ? index - 1 : index;
  }

  Widget _buildReelSection() {
    if (_reelController.isLoading && _reelController.reels.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
            child: Row(
              children: [
                const Text(
                  'Shorts',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Get.to(() => const ReelsPage()),
                  child: const Text('View All'),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 240,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemCount: _reelController.reels.length,
              itemBuilder: (context, index) {
                final reel = _reelController.reels[index];
                return _ReelCard(
                  reel: reel,
                  index: index,
                  reels: _reelController.reels.toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatViews(dynamic views) {
    final count =
        views is int ? views.toDouble() : (views is double ? views : 0.0);

    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(count >= 10000000 ? 0 : 1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(count >= 10000 ? 0 : 1)}K';
    }
    return count.round().toString();
  }
}

class _ReelCard extends StatelessWidget {
  final ReelModel reel;
  final int index;
  final List<ReelModel> reels;

  const _ReelCard({
    Key? key,
    required this.reel,
    required this.index,
    required this.reels,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Get.to(
          () => ReelsPage(
            initialIndex: index,
            reels: reels,
          ),
        );
      },
      child: Container(
        width: 150,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey[200],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: VideoThumbnail(videoUrl: reel.mediaUrl),
            ),
            const Center(
              child: Icon(
                Icons.play_circle_fill,
                color: Colors.white,
                size: 40,
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reel.description ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.favorite,
                        color: Colors.white70,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatLikeCount(reel.like['count'] ?? 0),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatLikeCount(dynamic count) {
    final num =
        count is int ? count.toDouble() : (count is double ? count : 0.0);

    if (num >= 1000000) {
      return '${(num / 1000000).toStringAsFixed(num >= 10000000 ? 0 : 1)}M';
    } else if (num >= 1000) {
      return '${(num / 1000).toStringAsFixed(num >= 10000 ? 0 : 1)}K';
    }
    return num.round().toString();
  }
}

class VideoThumbnail extends StatefulWidget {
  final String videoUrl;

  const VideoThumbnail({Key? key, required this.videoUrl}) : super(key: key);

  @override
  State<VideoThumbnail> createState() => _VideoThumbnailState();
}

class _VideoThumbnailState extends State<VideoThumbnail> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  Future<void> _initializeController() async {
    _controller = VideoPlayerController.network(widget.videoUrl);
    try {
      await _controller?.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      print('Error initializing video controller: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _controller == null) {
      return Container(
        color: Colors.grey[300],
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: _controller!.value.aspectRatio,
      child: VideoPlayer(_controller!),
    );
  }
}

class VideoCard extends StatefulWidget {
  final VideoTutorial video;
  final VoidCallback onTap;

  const VideoCard({Key? key, required this.video, required this.onTap})
      : super(key: key);

  @override
  State<VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<VideoCard> {
  late LanguageService _languageService;
  String _translatedTitle = '';
  bool _isTranslating = true;

  @override
  void initState() {
    super.initState();
    _initializeTranslation();
  }

  Future<void> _initializeTranslation() async {
    _languageService = await LanguageService.getInstance();
    final translatedTitle =
        await _languageService.translate(widget.video.title);
    if (mounted) {
      setState(() {
        _translatedTitle = translatedTitle;
        _isTranslating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: const EdgeInsets.only(bottom: 16),
        elevation: 0.5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Full width thumbnail
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: widget.video.thumbnail,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[200],
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[200],
                      child: const Center(
                        child: Icon(Icons.error),
                      ),
                    ),
                  ),
                  if (widget.video.duration != null)
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _formatDuration(widget.video.duration!),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Video info with profile picture, title and stats
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Channel profile picture
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: widget.video.profilePhoto != null &&
                            widget.video.profilePhoto!.isNotEmpty
                        ? CachedNetworkImageProvider(widget.video.profilePhoto!)
                        : null,
                    child: (widget.video.profilePhoto == null ||
                            widget.video.profilePhoto!.isEmpty)
                        ? Text(
                            widget.video.userName.substring(0, 1).toUpperCase(),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),

                  // Title and stats
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Video title with translation
                        if (_isTranslating)
                          const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        else
                          Text(
                            _translatedTitle.isNotEmpty
                                ? _translatedTitle
                                : widget.video.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              height: 1.3,
                            ),
                          ),
                        const SizedBox(height: 6),
                        // Channel name, views and date in one row
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.video.userName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Text(
                              '${_formatViews(widget.video.views.count)} views',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              ' • ',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              timeago.format(widget.video.createdAt),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final minutes = duration.inMinutes;
    final remainingSeconds = duration.inSeconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  String _formatViews(dynamic views) {
    final count =
        views is int ? views.toDouble() : (views is double ? views : 0.0);

    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(count >= 10000000 ? 0 : 1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(count >= 10000 ? 0 : 1)}K';
    }
    return count.round().toString();
  }
}
