import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../../core/constants/colors.dart';
import '../../controllers/reel_controller.dart';
import '../../controllers/ads_controller.dart';
import '../../controllers/feed_controller.dart';
import '../../../data/models/reel_model.dart';
import '../../../data/services/UserService.dart';
import '../../../data/repositories/feed_repository.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/rendering.dart';
import '../../../core/utils/error_handler.dart';
import '../feed/FeedDetailsScreen.dart';

class ReelsPage extends StatefulWidget {
  final int? initialIndex;
  final List<ReelModel>? reels;

  const ReelsPage({
    Key? key,
    this.initialIndex,
    this.reels,
  }) : super(key: key);

  @override
  State<ReelsPage> createState() => _ReelsPageState();
}

class _ReelsPageState extends State<ReelsPage> {
  final ReelController _reelController = Get.find<ReelController>();
  final AdsController _adsController = Get.find<AdsController>();
  final UserService _userService = Get.find<UserService>();
  late PageController _pageController;
  RxString activeTag = ''.obs; // Add this to track active tag
  final RxBool _isDescriptionExpanded = false.obs;

  // Add variables for ad integration
  List<dynamic> _reelAds = [];
  final RxList<Map<String, dynamic>> _combinedContent =
      <Map<String, dynamic>>[].obs;
  final int _reelsPerAd = 3; // Show an ad after every 3 reels

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: widget.initialIndex ?? 0,
    );

    // Set the default active tag as 'trending'
    activeTag.value = 'trending';

    if (widget.reels != null) {
      // Use provided reels if available
      _reelController.reels.value = widget.reels!;
      _fetchReelAds();
    } else {
      // Otherwise fetch trending reels by default instead of regular reels
      _fetchTrendingReelsWithAds();
    }
    _reelController.fetchTrendingTags();
  }

  Future<void> _fetchTrendingReelsWithAds() async {
    await _reelController.fetchTrendingReels();
    await _fetchReelAds();
  }

  Future<void> _fetchReelAds() async {
    try {
      _reelAds = await _adsController.fetchReelAds();
      print('Fetched ${_reelAds.length} reel ads');
      await _combineReelsAndAds();
    } catch (e) {
      print('Error fetching reel ads: $e');
    }
  }

  Future<void> _combineReelsAndAds() async {
    if (_reelAds.isEmpty) {
      print('No ads available to combine with reels');
      return;
    }

    if (_reelController.reels.isEmpty) {
      print('No reels available to combine with ads');
      return;
    }

    print(
        'Combining ${_reelController.reels.length} reels with ${_reelAds.length} ads');

    _combinedContent.clear();

    // Combine reels and ads
    for (int i = 0; i < _reelController.reels.length; i++) {
      _combinedContent
          .add({'type': 'reel', 'content': _reelController.reels[i]});

      // Insert an ad after every _reelsPerAd reels
      if ((i + 1) % _reelsPerAd == 0 &&
          i < _reelController.reels.length - 1 &&
          _reelAds.isNotEmpty) {
        final adIndex = ((i + 1) / _reelsPerAd - 1).toInt() % _reelAds.length;
        print('Adding ad at index $adIndex after reel ${i + 1}');
        _combinedContent.add({'type': 'ad', 'content': _reelAds[adIndex]});
      }
    }

    print('Combined content contains ${_combinedContent.length} items');
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Reels Section (now full screen)
          Obx(
            () {
              if (_reelController.isLoading) {
                return const Center(child: CircularProgressIndicator());
              } else if (_reelController.hasError) {
                // Use our error handler to show an appropriate error screen
                return ErrorHandler.getErrorWidget(
                  errorType: _reelController.errorType ?? ErrorType.unknown,
                  onRetry: () => _reelController.fetchReels(refresh: true),
                  showRetry: true,
                );
              } else if (_reelController.reels.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.videocam_off,
                          size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No reels available',
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () =>
                            _reelController.fetchReels(refresh: true),
                        child: const Text('Refresh'),
                      ),
                    ],
                  ),
                );
              }

              // Use _combinedContent if available, otherwise use reels directly
              final List<Map<String, dynamic>> contentList =
                  _combinedContent.isNotEmpty
                      ? _combinedContent.cast<Map<String, dynamic>>()
                      : _reelController.reels
                          .map((reel) => {'type': 'reel', 'content': reel})
                          .toList();

              return PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                itemCount: contentList.length,
                onPageChanged: (index) async {
                  // Load more reels when approaching the end
                  if (contentList[index]['type'] == 'reel' &&
                      index == contentList.length - 2) {
                    print('Near the end, loading more reels...');
                    await _reelController.fetchReels();
                    await _combineReelsAndAds();
                  }

                  final currentContext = _pageController.position.haveDimensions
                      ? (_pageController.page?.round() ?? 0)
                      : 0;

                  if ((index - currentContext).abs() > 2) {
                    _ReelVideoCardState._videoCache
                        .removeWhere((url, controller) {
                      final shouldRemove = !_reelController.reels
                          .sublist(max(0, index - 2),
                              min(_reelController.reels.length, index + 3))
                          .any((reel) => reel.mediaUrl == url);
                      if (shouldRemove) {
                        controller.dispose();
                      }
                      return shouldRemove;
                    });
                  }
                },
                itemBuilder: (context, index) {
                  final item = contentList[index] as Map<String, dynamic>;

                  if (item['type'] == 'ad') {
                    // Show ad card
                    return ReelAdCard(
                      ad: item['content'],
                      adsController: _adsController,
                      userService: _userService,
                    );
                  } else {
                    // Show regular reel
                    final reel = item['content'] as ReelModel;
                    return ReelVideoCard(
                      reel: reel,
                      index: index,
                    );
                  }
                },
              );
            },
          ),

          // Updated Trending Tags Section
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 0,
            right: 0,
            child: Container(
              height: 35,
              child: Obx(() {
                if (_reelController.trendingTags.isEmpty) {
                  return const SizedBox.shrink();
                }

                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: _reelController.trendingTags.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Obx(() => ElevatedButton(
                              onPressed: () {
                                activeTag.value = 'trending';
                                _reelController.fetchTrendingReels().then((_) {
                                  _fetchReelAds();
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: activeTag.value == 'trending'
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.2),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                minimumSize: Size.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                '🔥 Trending',
                                style: TextStyle(
                                  color: activeTag.value == 'trending'
                                      ? Colors.black
                                      : Colors.white,
                                  fontSize: 13,
                                ),
                              ),
                            )),
                      );
                    }

                    final tag = _reelController.trendingTags[index - 1];
                    final tagName = tag['name'] as String;

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Obx(() => ElevatedButton(
                            onPressed: () async {
                              activeTag.value = tagName;

                              // Use setLoading and setLoaded instead of directly manipulating isLoading.value
                              _reelController.setLoading();
                              try {
                                final tagReels = await _reelController
                                    .getReelsByTag(tagName);
                                if (_reelController.reels.isNotEmpty) {
                                  _reelController.reels.value = tagReels;
                                  await _combineReelsAndAds();
                                }
                              } finally {
                                _reelController.setLoaded();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: activeTag.value == tagName
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.2),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              minimumSize: Size.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              '#$tagName',
                              style: TextStyle(
                                color: activeTag.value == tagName
                                    ? Colors.black
                                    : Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          )),
                    );
                  },
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// Add ReelAdCard class for displaying ads
class ReelAdCard extends StatefulWidget {
  final dynamic ad;
  final AdsController adsController;
  final UserService userService;

  const ReelAdCard({
    Key? key,
    required this.ad,
    required this.adsController,
    required this.userService,
  }) : super(key: key);

  @override
  State<ReelAdCard> createState() => _ReelAdCardState();
}

class _ReelAdCardState extends State<ReelAdCard> {
  late VideoPlayerController _videoPlayerController;
  bool _isVideoInitialized = false;
  bool _isPlaying = false;
  bool _canSkip = false;
  int _remainingSeconds = 5;
  bool _hasRecordedImpression = false;
  int _viewDuration = 0;
  late String _userId;

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
    _startTimer();
    _getUserId();
  }

  Future<void> _getUserId() async {
    _userId = (await widget.userService.getUserId()) ?? '';
  }

  void _startTimer() {
    // Start timer for 5 seconds before allowing skip
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;

      setState(() {
        _remainingSeconds--;
      });

      if (_remainingSeconds > 0) {
        _startTimer();
      } else {
        setState(() {
          _canSkip = true;
        });
      }
    });
  }

  Future<void> _initializeVideoPlayer() async {
    try {
      if (!mounted) return;

      final videoUrl = widget.ad['videoUrl'] ?? '';
      print('Initializing ad video: $videoUrl');

      if (videoUrl.isEmpty) {
        print('Empty video URL for ad');
        return;
      }

      final uri = Uri.parse(videoUrl);
      if (!uri.isAbsolute) {
        print('Invalid video URL: $videoUrl');
        throw Exception('Invalid video URL');
      }

      _videoPlayerController = VideoPlayerController.network(
        videoUrl,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        httpHeaders: {
          'Access-Control-Allow-Origin': '*',
          'Range': 'bytes=0-',
        },
      );

      await _videoPlayerController.initialize();

      if (_videoPlayerController.value.isInitialized && mounted) {
        setState(() {
          _isVideoInitialized = true;
          _isPlaying = true;
        });

        // Start tracking view duration
        _startViewDurationTracking();

        await _videoPlayerController.setPlaybackSpeed(1.0);
        await _videoPlayerController.setLooping(true);
        await _videoPlayerController.play();
        print('Ad video started playing');
      }
    } catch (e) {
      print('Error initializing ad video: $e');
    }
  }

  void _startViewDurationTracking() {
    if (!_hasRecordedImpression && _userId.isNotEmpty) {
      _hasRecordedImpression = true;

      // Start timer to track view duration
      Future.delayed(const Duration(seconds: 1), () {
        if (!mounted) return;

        _viewDuration++;

        // Continue tracking while video is playing
        if (_isPlaying) {
          _startViewDurationTracking();
        } else {
          // Record impression when video stops or user navigates away
          _recordImpression();
        }
      });
    }
  }

  Future<void> _recordImpression() async {
    if (_userId.isNotEmpty && _viewDuration > 0) {
      try {
        await widget.adsController
            .trackReelAdView(widget.ad['_id'], _userId, _viewDuration);
      } catch (e) {
        print('Error recording ad impression: $e');
      }
    }
  }

  @override
  void dispose() {
    _recordImpression();
    _videoPlayerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Video player or placeholder
        Container(
          color: Colors.black,
          child: _isVideoInitialized
              ? FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _videoPlayerController.value.size.width,
                    height: _videoPlayerController.value.size.height,
                    child: VideoPlayer(_videoPlayerController),
                  ),
                )
              : const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
        ),

        // Overlay with countdown
        Positioned(
          top: MediaQuery.of(context).padding.top + 50,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(16),
            ),
            child: _canSkip
                ? const Text(
                    'Ad',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : Text(
                    'Ad • $_remainingSeconds',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),

        // Pop-up view at bottom if enabled
        if (_isPopUpViewEnabled())
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.9),
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left side - Image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _buildPopupImage(),
                  ),
                  const SizedBox(width: 16),
                  // Right side - Text and Button
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.ad['popUpView']['popupTitle'] ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              widget.ad['title'] ?? 'Advertisement',
                              style: TextStyle(
                                color: Colors.grey[300],
                                fontSize: 14,
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () => _navigateToContent(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('View'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Progress indicator
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: VideoProgressIndicator(
            _videoPlayerController,
            allowScrubbing: false,
            padding: EdgeInsets.zero,
            colors: VideoProgressColors(
              playedColor: AppColors.green,
              bufferedColor: Colors.white.withOpacity(0.5),
              backgroundColor: Colors.white.withOpacity(0.2),
            ),
          ),
        ),

        // Intercept user interaction to prevent scrolling
        if (!_canSkip)
          Positioned.fill(
            child: GestureDetector(
              onVerticalDragEnd: (_) {},
              onVerticalDragStart: (_) {},
              onVerticalDragUpdate: (_) {},
              onTap: () {}, // Disable tapping as well
              child: Container(
                color: Colors.transparent,
              ),
            ),
          ),
      ],
    );
  }

  bool _isPopUpViewEnabled() {
    return widget.ad['popUpView'] != null &&
        widget.ad['popUpView']['enabled'] == true &&
        widget.ad['popUpView']['image'] != null;
  }

  Widget _buildPopupImage() {
    final imageUrl = widget.ad['popUpView']['image'];

    if (imageUrl == null || imageUrl.toString().trim().isEmpty) {
      // Return placeholder for missing image
      return Container(
        width: 80,
        height: 80,
        color: Colors.grey[300],
        child: const Icon(
          Icons.image_not_supported,
          color: Colors.grey,
        ),
      );
    }

    // Use a safer approach with error handling
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.grey[300], // Background color before image loads
      ),
      child: Image.network(
        imageUrl,
        fit: BoxFit.cover,
        width: 80,
        height: 80,
        errorBuilder: (context, error, stackTrace) {
          print('Error loading popup image: $error');
          return Container(
            width: 80,
            height: 80,
            color: Colors.grey[300],
            child: const Icon(
              Icons.broken_image,
              color: Colors.grey,
            ),
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: 80,
            height: 80,
            color: Colors.grey[300],
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
                color: AppColors.green,
              ),
            ),
          );
        },
      ),
    );
  }

  void _navigateToContent() {
    if (!_isPopUpViewEnabled()) return;

    final contentType = widget.ad['popUpView']['type'];
    final contentId = widget.ad['popUpView']['productId'];

    // Show loading dialog
    Get.dialog(
      Center(
        child: CircularProgressIndicator(
          color: AppColors.green,
        ),
      ),
      barrierDismissible: false,
    );

    print('Navigating to $contentType: $contentId');

    if (contentType == 'marketplace' && contentId != null) {
      // Close dialog first
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
      // Navigate to marketplace detail
      Get.toNamed('/marketplace-detail', arguments: contentId);
    } else if (contentType == 'feed' && contentId != null) {
      try {
        // Try a more direct approach without route names
        final feedController = Get.find<FeedController>();

        // Use a direct class import from FeedRepository
        try {
          final feedRepository = Get.find<FeedRepository>();

          feedRepository.getFeedById(contentId).then((feedData) {
            // Close loading dialog
            if (Get.isDialogOpen ?? false) {
              Get.back();
            }
            // Navigate directly to the screen instead of using named route
            Get.to(() => FeedDetailsScreen(feed: feedData.toJson()));
          }).catchError((error) {
            print('Error accessing feed repository: $error');
            _fallbackNavigation(contentId);
          });
        } catch (error) {
          print('Error finding feed repository: $error');
          _fallbackNavigation(contentId);
        }
      } catch (e) {
        // Close loading dialog
        if (Get.isDialogOpen ?? false) {
          Get.back();
        }
        print('Navigation error: $e');
        Get.snackbar(
          'Error',
          'Could not navigate to the post',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.withOpacity(0.6),
          colorText: Colors.white,
        );
      }
    } else {
      // Close dialog if no valid navigation
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
    }
  }

  void _fallbackNavigation(String contentId) {
    // Close loading dialog
    if (Get.isDialogOpen ?? false) {
      Get.back();
    }

    // Try using the simplest possible navigation with arguments
    try {
      Get.toNamed('/feed/${contentId}');
    } catch (e) {
      print('Fallback navigation failed: $e');
      // Last resort - pass the ID as a simple argument
      try {
        Get.toNamed('/feed-detail', arguments: contentId);
      } catch (e) {
        print('All navigation attempts failed: $e');
        Get.snackbar(
          'Error',
          'Could not open the post',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.withOpacity(0.6),
          colorText: Colors.white,
        );
      }
    }
  }
}

class ReelVideoCard extends StatefulWidget {
  final ReelModel reel;
  final int index;

  const ReelVideoCard({
    Key? key,
    required this.reel,
    required this.index,
  }) : super(key: key);

  @override
  State<ReelVideoCard> createState() => _ReelVideoCardState();
}

class _ReelVideoCardState extends State<ReelVideoCard> {
  final ReelController _reelController = Get.find<ReelController>();
  late VideoPlayerController _videoPlayerController;
  static const int PRELOAD_AHEAD =
      2; // Number of videos to preload ahead and behind
  static final Map<String, VideoPlayerController> _videoCache =
      {}; // Cache for video controllers
  static const int MAX_CACHE_SIZE =
      7; // Increased cache size to accommodate both directions
  bool _isVideoInitialized = false;
  bool _isPlaying = false;
  final RxBool _isDescriptionExpanded = false.obs;

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
  }

  Future<void> _preloadVideos() async {
    try {
      // Preload previous videos
      for (int i = 1; i <= PRELOAD_AHEAD; i++) {
        final prevIndex = widget.index - i;
        if (prevIndex < 0) break;

        await _preloadSingleVideo(prevIndex);
      }

      // Preload next videos
      for (int i = 1; i <= PRELOAD_AHEAD; i++) {
        final nextIndex = widget.index + i;
        if (nextIndex >= _reelController.reels.length) break;

        await _preloadSingleVideo(nextIndex);
      }
    } catch (e) {}
  }

  Future<void> _preloadSingleVideo(int index) async {
    final reel = _reelController.reels[index];
    if (_videoCache.containsKey(reel.mediaUrl)) return;

    // Check cache size and remove oldest entries if needed
    if (_videoCache.length >= MAX_CACHE_SIZE) {
      final oldestUrl = _videoCache.keys.first;
      await _videoCache[oldestUrl]?.dispose();
      _videoCache.remove(oldestUrl);
    }

    final uri = Uri.parse(reel.mediaUrl);
    if (!uri.isAbsolute) return;

    try {
      final controller = VideoPlayerController.network(
        reel.mediaUrl,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        httpHeaders: {
          'Access-Control-Allow-Origin': '*',
          'Range': 'bytes=0-',
        },
      );

      await controller.initialize();
      _videoCache[reel.mediaUrl] = controller;
    } catch (e) {}
  }

  Future<void> _initializeVideoPlayer() async {
    try {
      // Check if widget is still mounted before initializing
      if (!mounted) return;

      // Check cache first
      if (_videoCache.containsKey(widget.reel.mediaUrl)) {
        _videoPlayerController = _videoCache[widget.reel.mediaUrl]!;
        _videoCache.remove(widget.reel.mediaUrl);
      } else {
        final uri = Uri.parse(widget.reel.mediaUrl);
        if (!uri.isAbsolute) {
          throw Exception('Invalid video URL');
        }

        _videoPlayerController = VideoPlayerController.network(
          widget.reel.mediaUrl,
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          httpHeaders: {
            'Access-Control-Allow-Origin': '*',
            'Range': 'bytes=0-',
          },
        );

        await _videoPlayerController.initialize();
      }

      if (_videoPlayerController.value.isInitialized && mounted) {
        setState(() {
          _isVideoInitialized = true;
          _isPlaying = true;
        });

        await _videoPlayerController.setPlaybackSpeed(1.0);
        await _videoPlayerController.setLooping(true);
        await _videoPlayerController.play();

        // Start preloading videos in both directions
        _preloadVideos();
      }
    } catch (e) {}
  }

  @override
  void dispose() {
    try {
      if (!_videoCache.containsValue(_videoPlayerController)) {
        _videoPlayerController.pause();
        _videoPlayerController.dispose();
      }
    } catch (e) {}
    super.dispose();
  }

  void _togglePlay() {
    setState(() {
      _isPlaying = !_isPlaying;
      _isPlaying
          ? _videoPlayerController.play()
          : _videoPlayerController.pause();
    });
  }

  void _showCommentsModal(BuildContext context) async {
    final TextEditingController commentController = TextEditingController();
    final comments = await _reelController.fetchComments(widget.reel.id);
    RxString replyingTo = ''.obs; // Track which comment we're replying to

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textGrey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Comments',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textGrey,
                  ),
                ),
              ),
              Expanded(
                child: Obx(() {
                  final reelComments =
                      _reelController.reelComments[widget.reel.id] ?? [];

                  if (reelComments.isEmpty) {
                    return const Center(
                      child: Text(
                        'No comments yet',
                        style: TextStyle(color: AppColors.textGrey),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: reelComments.length,
                    itemBuilder: (context, index) {
                      final comment = reelComments[index];
                      final replies =
                          comment['replies'] as List<dynamic>? ?? [];
                      final hasReplies = replies.isNotEmpty;
                      final showAllReplies = RxBool(false);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Main Comment
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: _buildCommentItem(
                                comment, replyingTo, commentController),
                          ),

                          // Replies Section
                          if (hasReplies)
                            Obx(() {
                              final displayReplies = showAllReplies.value
                                  ? replies
                                  : (replies.length > 2
                                      ? replies.sublist(0, 2)
                                      : replies);

                              return Padding(
                                padding: const EdgeInsets.only(left: 32),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ...displayReplies
                                        .map((reply) => Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 8),
                                              child: _buildCommentItem(
                                                  reply,
                                                  replyingTo,
                                                  commentController),
                                            ))
                                        .toList(),

                                    // Show More Replies Button
                                    if (replies.length > 2 &&
                                        !showAllReplies.value)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            top: 4, bottom: 8),
                                        child: GestureDetector(
                                          onTap: () =>
                                              showAllReplies.value = true,
                                          child: Text(
                                            'Show ${replies.length - 2} more replies',
                                            style: const TextStyle(
                                              color: AppColors.green,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            }),
                        ],
                      );
                    },
                  );
                }),
              ),

              // Updated comment input section
              Container(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  left: 16,
                  right: 16,
                  top: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  border: Border(
                    top: BorderSide(color: AppColors.textGrey.withOpacity(0.2)),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Obx(
                      () => replyingTo.value.isNotEmpty
                          ? Container(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Text(
                                    'Replying to ${replyingTo.value}',
                                    style: const TextStyle(
                                      color: AppColors.textGrey,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 16),
                                    onPressed: () {
                                      replyingTo.value = '';
                                      commentController.clear();
                                    },
                                    color: AppColors.textGrey,
                                  ),
                                ],
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: commentController,
                            decoration: const InputDecoration(
                              hintText: 'Add a comment...',
                              hintStyle: TextStyle(color: AppColors.textGrey),
                              border: InputBorder.none,
                            ),
                            style: const TextStyle(color: AppColors.textGrey),
                            maxLines: null,
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            if (commentController.text.trim().isNotEmpty) {
                              try {
                                final parentComment = replyingTo
                                        .value.isNotEmpty
                                    ? _reelController
                                        .reelComments.value[widget.reel.id]
                                        ?.where((comment) =>
                                            comment['userName'] != null &&
                                            comment['userName'].toString() ==
                                                replyingTo.value)
                                        .firstOrNull
                                    : null;

                                final parentCommentId =
                                    parentComment?['_id'] as String?;

                                await _reelController.addComment(
                                  widget.reel.id,
                                  commentController.text.trim(),
                                  parentCommentId: parentCommentId,
                                );

                                commentController.clear();
                                replyingTo.value = '';
                                await _reelController
                                    .fetchComments(widget.reel.id);
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Failed to add comment'),
                                    backgroundColor: AppColors.orange,
                                  ),
                                );
                              }
                            }
                          },
                          child: const Text(
                            'Post',
                            style: TextStyle(color: AppColors.green),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key(widget.reel.id),
      onVisibilityChanged: (visibilityInfo) {
        var visiblePercentage = visibilityInfo.visibleFraction * 100;
        if (!mounted) return; // Add this check

        try {
          if (visiblePercentage > 90) {
            if (_videoPlayerController.value.isInitialized) {
              _videoPlayerController.play();
            }
          } else if (visiblePercentage < 10) {
            if (_videoPlayerController.value.isInitialized) {
              _videoPlayerController.pause();
            }
          }
        } catch (e) {}
      },
      child: Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_isVideoInitialized) ...[
              GestureDetector(
                onTap: _togglePlay,
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _videoPlayerController.value.size.width,
                    height: _videoPlayerController.value.size.height,
                    child: VideoPlayer(_videoPlayerController),
                  ),
                ),
              ),
              if (!_isPlaying)
                Center(
                  child: Icon(
                    Icons.play_arrow,
                    size: 80,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
            ] else
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),

            // Video Controls and Info Overlay
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.only(bottom: 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Video info (left side)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundImage:
                                      NetworkImage(widget.reel.profilePhoto),
                                  onBackgroundImageError:
                                      (exception, stackTrace) {},
                                  backgroundColor: AppColors.textGrey,
                                  child: widget.reel.profilePhoto.isEmpty
                                      ? Text(
                                          widget.reel.userName
                                                  ?.substring(0, 1)
                                                  .toUpperCase() ??
                                              '?',
                                          style: const TextStyle(
                                              color: Colors.white),
                                        )
                                      : null,
                                  radius: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  widget.reel.userName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Obx(() {
                              final words = widget.reel.description.split(' ');
                              final styledDescription = words.map((word) {
                                if (word.startsWith('#')) {
                                  return TextSpan(
                                    text: '$word ',
                                    style: const TextStyle(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  );
                                }
                                return TextSpan(
                                  text: '$word ',
                                  style: const TextStyle(
                                    color: Colors.white,
                                  ),
                                );
                              }).toList();

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  RichText(
                                    text: TextSpan(
                                      children: _isDescriptionExpanded.value
                                          ? styledDescription
                                          : [
                                              ...styledDescription.take(15),
                                              if (words.length > 15)
                                                const TextSpan(text: '... ')
                                            ],
                                    ),
                                    maxLines:
                                        _isDescriptionExpanded.value ? null : 2,
                                    overflow: TextOverflow.clip,
                                  ),
                                  if (words.length > 15)
                                    GestureDetector(
                                      onTap: () =>
                                          _isDescriptionExpanded.value =
                                              !_isDescriptionExpanded.value,
                                      child: Text(
                                        _isDescriptionExpanded.value
                                            ? 'Show less'
                                            : 'Show more',
                                        style: const TextStyle(
                                          color: AppColors.green,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            }),
                            if (widget.reel.location != null &&
                                widget.reel.location.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.location_on,
                                      color: Colors.white, size: 16),
                                  const SizedBox(width: 4),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    // Right side buttons
                    Container(
                      padding: const EdgeInsets.only(right: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildInteractionButton(
                            widget.reel.like['isLiked'] == true
                                ? Icons.favorite
                                : Icons.favorite_border,
                            widget.reel.like['count'].toString(),
                            onTap: () async {
                              try {
                                await _reelController
                                    .toggleLike(widget.reel.id);
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Failed to update like'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildInteractionButton(
                            Icons.chat_bubble_outline,
                            widget.reel.comment['count'].toString(),
                            onTap: () => _showCommentsModal(context),
                          ),
                          const SizedBox(height: 16),
                          _buildInteractionButton(
                            _videoPlayerController.value.volume > 0
                                ? Icons.volume_up
                                : Icons.volume_off,
                            _videoPlayerController.value.volume > 0
                                ? 'Audio'
                                : 'Muted', // Updated label
                            onTap: () {
                              setState(() {
                                _videoPlayerController.setVolume(
                                    _videoPlayerController.value.volume > 0
                                        ? 0
                                        : 1);
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildInteractionButton(
                            Icons.share,
                            'Share',
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                backgroundColor: Colors.transparent,
                                builder: (context) => Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(20)),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        margin: const EdgeInsets.symmetric(
                                            vertical: 10),
                                        width: 40,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[300],
                                          borderRadius:
                                              BorderRadius.circular(2),
                                        ),
                                      ),
                                      const Padding(
                                        padding: EdgeInsets.all(16.0),
                                        child: Text(
                                          'Share to',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textGrey,
                                          ),
                                        ),
                                      ),
                                      GridView.count(
                                        shrinkWrap: true,
                                        crossAxisCount: 4,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 24, vertical: 8),
                                        children: [
                                          _buildShareOption(
                                            icon: Icons.copy,
                                            label: 'Copy Link',
                                            onTap: () {
                                              Clipboard.setData(ClipboardData(
                                                text:
                                                    'https://yourdomain.com/reels/${widget.reel.id}',
                                              )).then((_) {
                                                Navigator.pop(context);
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                        'Link copied to clipboard'),
                                                    backgroundColor:
                                                        AppColors.green,
                                                  ),
                                                );
                                              });
                                            },
                                          ),
                                          _buildShareOption(
                                            icon: Icons.facebook,
                                            label: 'WhatsApp',
                                            onTap: () async {
                                              final url = Uri.parse(
                                                'whatsapp://send?text=Check out this reel: https://yourdomain.com/reels/${widget.reel.id}',
                                              );
                                              if (await canLaunchUrl(url)) {
                                                await launchUrl(url);
                                              }
                                              Navigator.pop(context);
                                            },
                                          ),
                                          _buildShareOption(
                                            icon: Icons.facebook,
                                            label: 'Facebook',
                                            onTap: () async {
                                              final url = Uri.parse(
                                                'https://www.facebook.com/sharer/sharer.php?u=https://yourdomain.com/reels/${widget.reel.id}',
                                              );
                                              if (await canLaunchUrl(url)) {
                                                await launchUrl(url);
                                              }
                                              Navigator.pop(context);
                                            },
                                          ),
                                          _buildShareOption(
                                            icon: Icons.telegram,
                                            label: 'Telegram',
                                            onTap: () async {
                                              final url = Uri.parse(
                                                'https://t.me/share/url?url=https://yourdomain.com/reels/${widget.reel.id}&text=Check out this reel!',
                                              );
                                              if (await canLaunchUrl(url)) {
                                                await launchUrl(url);
                                              }
                                              Navigator.pop(context);
                                            },
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 20),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildInteractionButton(
                            Icons.more_vert,
                            '', // Empty label
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                backgroundColor: Colors.transparent,
                                builder: (context) => Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(20)),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        margin: const EdgeInsets.symmetric(
                                            vertical: 10),
                                        width: 40,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[300],
                                          borderRadius:
                                              BorderRadius.circular(2),
                                        ),
                                      ),
                                      const Padding(
                                        padding: EdgeInsets.all(16.0),
                                        child: Text(
                                          'Report',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textGrey,
                                          ),
                                        ),
                                      ),
                                      ListTile(
                                        leading: const Icon(
                                            Icons.report_problem,
                                            color: AppColors.textGrey),
                                        title:
                                            const Text('Inappropriate Content'),
                                        onTap: () {
                                          // Handle report
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                  'Thank you for reporting'),
                                              backgroundColor: AppColors.green,
                                            ),
                                          );
                                        },
                                      ),
                                      ListTile(
                                        leading: const Icon(Icons.copyright,
                                            color: AppColors.textGrey),
                                        title: const Text(
                                            'Copyright Infringement'),
                                        onTap: () {
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                  'Thank you for reporting'),
                                              backgroundColor: AppColors.green,
                                            ),
                                          );
                                        },
                                      ),
                                      ListTile(
                                        leading: const Icon(Icons.dangerous,
                                            color: AppColors.textGrey),
                                        title:
                                            const Text('Harmful or Dangerous'),
                                        onTap: () {
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                  'Thank you for reporting'),
                                              backgroundColor: AppColors.green,
                                            ),
                                          );
                                        },
                                      ),
                                      ListTile(
                                        leading: const Icon(Icons.block,
                                            color: AppColors.textGrey),
                                        title: const Text('Spam or Misleading'),
                                        onTap: () {
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                  'Thank you for reporting'),
                                              backgroundColor: AppColors.green,
                                            ),
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 20),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_videoPlayerController.value.volume == 0)
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.volume_off,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: VideoProgressIndicator(
                _videoPlayerController,
                allowScrubbing: true,
                padding: EdgeInsets.zero,
                colors: VideoProgressColors(
                  playedColor: AppColors.green,
                  bufferedColor: Colors.white.withOpacity(0.5),
                  backgroundColor: Colors.white.withOpacity(0.2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractionButton(IconData icon, String label,
      {VoidCallback? onTap}) {
    // Special handling for like button
    if (icon == Icons.favorite || icon == Icons.favorite_border) {
      final isLiked = widget.reel.like['isLiked'] == true;
      return GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Icon(
              isLiked ? Icons.favorite : Icons.favorite_border,
              color: isLiked ? Colors.red : Colors.white,
              size: 28,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    // Default button style for other buttons
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  String getTimeAgo(String dateString) {
    final date = DateTime.parse(dateString);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '$years ${years == 1 ? 'year' : 'years'} ago';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    } else if (difference.inDays > 7) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'Just now';
    }
  }

  Widget _buildCommentItem(
    Map<String, dynamic> comment,
    RxString replyingTo,
    TextEditingController commentController,
  ) {
    final RxBool isExpanded = false.obs;
    final content = comment['content'] as String;
    final words = content.split(' ');
    final styledContent = words.map((word) {
      if (word.startsWith('#')) {
        return TextSpan(
          text: '$word ',
          style: const TextStyle(
            color: Colors.blue,
            fontWeight: FontWeight.w500,
          ),
        );
      }
      return TextSpan(
          text: '$word ', style: const TextStyle(color: AppColors.textGrey));
    }).toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          backgroundImage: NetworkImage(comment['profilePhoto']),
          onBackgroundImageError: (exception, stackTrace) {},
          backgroundColor: AppColors.textGrey,
          child: widget.reel.profilePhoto.isEmpty
              ? Text(
                  comment['userName']?.substring(0, 1).toUpperCase() ?? '?',
                  style: const TextStyle(color: Colors.white),
                )
              : null,
          radius: 16,
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
                      color: AppColors.textGrey,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    getTimeAgo(comment['createdAt']),
                    style: const TextStyle(
                      color: AppColors.textGrey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Obx(() => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          children: isExpanded.value
                              ? styledContent
                              : [
                                  ...styledContent.take(50),
                                  if (content.length > 50)
                                    const TextSpan(text: '... ')
                                ],
                        ),
                        maxLines: isExpanded.value ? null : 2,
                        overflow: TextOverflow.clip,
                      ),
                      if (content.length > 50)
                        GestureDetector(
                          onTap: () => isExpanded.value = !isExpanded.value,
                          child: Text(
                            isExpanded.value ? 'Show less' : 'Show more',
                            style: const TextStyle(
                              color: AppColors.green,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  )),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () {
                  replyingTo.value = comment['userName'];
                  commentController.text = '@${comment['userName']} ';
                  commentController.selection = TextSelection.fromPosition(
                    TextPosition(offset: commentController.text.length),
                  );
                  FocusScope.of(context).requestFocus();
                },
                child: const Text(
                  'Reply',
                  style: TextStyle(
                    color: AppColors.green, // Changed to green
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildShareOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: AppColors.textGrey,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textGrey,
            ),
          ),
        ],
      ),
    );
  }
}
