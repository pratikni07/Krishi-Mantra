import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../controllers/reel_controller.dart';
import '../../controllers/ads_controller.dart';
import '../../widgets/skeleton/skeleton_widgets.dart';
import '../../../data/models/reel_model.dart';
import '../../../data/services/UserService.dart';
import '../../../data/repositories/feed_repository.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/rendering.dart';
import '../../../core/utils/error_handler.dart';
import '../feed/FeedDetailsScreen.dart';
import '../../widgets/loading_state_widget.dart';
import '../../widgets/error_state_widget.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/tractor_loading_indicator.dart';

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
  List<Map<String, dynamic>> _combinedContent = [];
  final int _reelsPerAd = 3; // Show an ad after every 3 reels

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: widget.initialIndex ?? 0,
    );

    // Defer reactive updates to after the first frame to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Set the default active tag as 'for_you' (recommended)
      activeTag.value = 'for_you';

      if (widget.reels != null) {
        // Use provided reels if available
        _reelController.reels.value = widget.reels!;
        _fetchReelAds();
      } else {
        // Fetch recommended reels by default (personalized for user)
        _fetchRecommendedReelsWithAds();
      }
      _reelController.fetchTrendingTags();
    });
  }

  Future<void> _fetchRecommendedReelsWithAds() async {
    await _reelController.fetchRecommendedReels(refresh: true);
    await _fetchReelAds();
  }

  Future<void> _fetchTrendingReelsWithAds() async {
    await _reelController.fetchTrendingReels(refresh: true);
    await _fetchReelAds();
  }

  Future<void> _fetchReelAds() async {
    try {
      _reelAds = await _adsController.fetchReelAds();
      logger.d('Fetched ${_reelAds.length} reel ads', tag: 'ReelsPage');
      await _combineReelsAndAds();
    } catch (e) {
      logger.e('Error fetching reel ads', tag: 'ReelsPage', error: e);
    }
  }

  Future<void> _combineReelsAndAds() async {
    // Snapshot the reactive list to avoid RxList.length infinite recursion
    // inside setState.
    final reelsList = List<ReelModel>.from(_reelController.reels);

    // Always rebuild the combined list, even if either input is empty:
    //   - ads empty + reels present  → reels-only, ads can be inserted later
    //   - reels empty (still loading) → empty list, build() falls through
    //     to the reels-direct path which shows the loading/empty state
    //   - both empty                  → empty list (build shows empty state)
    //
    // The previous early-returns left a stale `_combinedContent` in place.
    // If ads loaded first while reels were still in flight, this method
    // bailed; later reel arrival never re-triggered it, so ads never
    // appeared interspersed and (in pathological cases) the page sat on
    // an empty `_combinedContent` while reels accumulated invisibly.
    final List<Map<String, dynamic>> newCombinedContent = [];

    for (int i = 0; i < reelsList.length; i++) {
      newCombinedContent.add({'type': 'reel', 'content': reelsList[i]});

      if (_reelAds.isNotEmpty &&
          (i + 1) % _reelsPerAd == 0 &&
          i < reelsList.length - 1) {
        final adIndex = ((i + 1) / _reelsPerAd - 1).toInt() % _reelAds.length;
        newCombinedContent.add({'type': 'ad', 'content': _reelAds[adIndex]});
      }
    }

    if (mounted) {
      setState(() {
        _combinedContent = newCombinedContent;
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Reels Section (now full screen) - Using GetBuilder to avoid RxList.length infinite recursion
          GetBuilder<ReelController>(
            init: _reelController,
            builder: (controller) {
              // Check loading state from base controller
              if (controller.isLoading) {
                return const LoadingStateWidget(
                  message: 'Loading reels...',
                );
              } else if (controller.hasError) {
                return const ErrorStateWidget(
                  title: 'Unable to Load Reels',
                  subtitle: 'The tractor hit a bump while fetching reels. Please try again! 🎬',
                );
              }

              // Create a non-reactive copy of the reels list to avoid RxList issues
              final reelsList = List<ReelModel>.from(controller.reels);

              if (reelsList.isEmpty) {
                return const EmptyStateWidget(
                  title: 'No Reels Available',
                  subtitle: 'The tractor is out filming new reels for you — check back soon! 🎥',
                );
              }

              // Use _combinedContent if available, otherwise use reels directly
              final List<Map<String, dynamic>> contentList =
                  _combinedContent.isNotEmpty
                      ? _combinedContent
                      : reelsList
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
                    logger.d('Near the end, loading more reels...', tag: 'ReelsPage');
                    await controller.fetchReels();
                    await _combineReelsAndAds();
                  }

                  final currentContext = _pageController.position.haveDimensions
                      ? (_pageController.page?.round() ?? 0)
                      : 0;

                  if ((index - currentContext).abs() > 2) {
                    _ReelVideoCardState._videoCache
                        .removeWhere((url, ctrl) {
                      final shouldRemove = !reelsList
                          .sublist(max(0, index - 2),
                              min(reelsList.length, index + 3))
                          .any((reel) => reel.mediaUrl == url);
                      if (shouldRemove) {
                        ctrl.dispose();
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

          // Back Button
          Positioned(
            top: MediaQuery.of(context).padding.top + AppSizes.paddingS,
            left: AppSizes.paddingS,
            child: GestureDetector(
              onTap: () => Get.back(),
              child: Container(
                padding: EdgeInsets.all(AppSizes.paddingS),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: AppSizes.iconM,
                ),
              ),
            ),
          ),

          // Updated Trending Tags Section
          Positioned(
            top: MediaQuery.of(context).padding.top + AppSizes.paddingS,
            left: AppSizes.paddingXL * 2.5, // Offset to account for back button
            right: 0,
            child: Container(
              height: ResponsiveUtils.hp(4.5),
              child: Obx(() {
                if (_reelController.trendingTags.isEmpty) {
                  return const SizedBox.shrink();
                }

                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: RPadding.symmetric(horizontal: 8),
                  itemCount: _reelController.trendingTags.length + 2, // +2 for For You and Trending
                  itemBuilder: (context, index) {
                    // First button: For You (Recommended)
                    if (index == 0) {
                      return Padding(
                        padding: RPadding.symmetric(horizontal: 4),
                        child: Obx(() => ElevatedButton(
                              onPressed: () {
                                activeTag.value = 'for_you';
                                _reelController.fetchRecommendedReels(refresh: true).then((_) {
                                  _fetchReelAds();
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: activeTag.value == 'for_you'
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.2),
                                padding: RPadding.symmetric(
                                    horizontal: 12, vertical: 8),
                                minimumSize: Size.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppSizes.radiusXL),
                                ),
                              ),
                              child: Text(
                                'For You',
                                style: TextStyle(
                                  color: activeTag.value == 'for_you'
                                      ? Colors.black
                                      : Colors.white,
                                  fontSize: AppSizes.fontS,
                                ),
                              ),
                            )),
                      );
                    }

                    // Second button: Trending
                    if (index == 1) {
                      return Padding(
                        padding: RPadding.symmetric(horizontal: 4),
                        child: Obx(() => ElevatedButton(
                              onPressed: () {
                                activeTag.value = 'trending';
                                _reelController.fetchTrendingReels(refresh: true).then((_) {
                                  _fetchReelAds();
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: activeTag.value == 'trending'
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.2),
                                padding: RPadding.symmetric(
                                    horizontal: 12, vertical: 8),
                                minimumSize: Size.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppSizes.radiusXL),
                                ),
                              ),
                              child: Text(
                                'Trending',
                                style: TextStyle(
                                  color: activeTag.value == 'trending'
                                      ? Colors.black
                                      : Colors.white,
                                  fontSize: AppSizes.fontS,
                                ),
                              ),
                            )),
                      );
                    }

                    final tag = _reelController.trendingTags[index - 2]; // -2 for For You and Trending
                    final tagName = tag['name'] as String;

                    return Padding(
                      padding: RPadding.symmetric(horizontal: 4),
                      child: Obx(() => ElevatedButton(
                            onPressed: () async {
                              activeTag.value = tagName;

                              // Use setLoading and setLoaded instead of directly manipulating isLoading.value
                              _reelController.setLoading();
                              try {
                                final tagReels = await _reelController
                                    .getReelsByTag(tagName);
                                if (tagReels.isNotEmpty) {
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
                              padding: RPadding.symmetric(
                                  horizontal: 12, vertical: 8),
                              minimumSize: Size.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppSizes.radiusXL),
                              ),
                            ),
                            child: Text(
                              '#$tagName',
                              style: TextStyle(
                                color: activeTag.value == tagName
                                    ? Colors.black
                                    : Colors.white,
                                fontSize: AppSizes.fontS,
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
  VideoPlayerController? _videoPlayerController;
  bool _isVideoInitialized = false;
  bool _isPlaying = false;
  bool _canSkip = false;
  int _remainingSeconds = 5;
  bool _hasRecordedImpression = false;
  int _viewDuration = 0;
  late String _userId;
  bool _hasError = false;
  String _errorMessage = '';
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _isDisposed = false;
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
      if (!mounted || _isDisposed) return;

      final videoUrl = widget.ad['videoUrl'] ?? '';
      logger.d('Initializing ad video: $videoUrl', tag: 'ReelAdCard');

      if (videoUrl.isEmpty) {
        logger.w('Empty video URL for ad', tag: 'ReelAdCard');
        if (mounted && !_isDisposed) {
          setState(() {
            _hasError = true;
            _errorMessage = 'No video URL provided';
          });
        }
        return;
      }

      final uri = Uri.parse(videoUrl);
      if (!uri.isAbsolute) {
        logger.w('Invalid video URL: $videoUrl', tag: 'ReelAdCard');
        if (mounted && !_isDisposed) {
          setState(() {
            _hasError = true;
            _errorMessage = 'Invalid video URL';
          });
        }
        return;
      }

      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(videoUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );

      // Add timeout for video initialization
      await _videoPlayerController!.initialize().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Video load timeout - check network connection');
        },
      );

      if (_videoPlayerController!.value.isInitialized && mounted && !_isDisposed) {
        setState(() {
          _isVideoInitialized = true;
          _isPlaying = true;
        });

        // Start tracking view duration
        _startViewDurationTracking();

        await _videoPlayerController!.setPlaybackSpeed(1.0);
        await _videoPlayerController!.setLooping(true);
        await _videoPlayerController!.play();
        logger.d('Ad video started playing', tag: 'ReelAdCard');
      }
    } catch (e) {
      logger.e('Error initializing ad video', tag: 'ReelAdCard', error: e);
      if (mounted && !_isDisposed) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
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
        logger.e('Error recording ad impression', tag: 'ReelAdCard', error: e);
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _recordImpression();
    _videoPlayerController?.dispose();
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
          child: _hasError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      const Text(
                        'Failed to load ad',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          _errorMessage,
                          style: TextStyle(color: Colors.grey[400], fontSize: 12),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _hasError = false;
                            _errorMessage = '';
                          });
                          _initializeVideoPlayer();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _isVideoInitialized && _videoPlayerController != null
                  ? FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _videoPlayerController!.value.size.width,
                        height: _videoPlayerController!.value.size.height,
                        child: VideoPlayer(_videoPlayerController!),
                      ),
                    )
                  : const Center(
                      child: TractorLoadingIndicator(size: 100),
                    ),
        ),

        // Overlay with countdown
        Positioned(
          top: MediaQuery.of(context).padding.top + ResponsiveUtils.hp(6),
          right: AppSizes.paddingL,
          child: Container(
            padding: RPadding.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(AppSizes.radiusXL),
            ),
            child: _canSkip
                ? Text(
                    'Ad',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: AppSizes.fontM,
                    ),
                  )
                : Text(
                    'Ad • $_remainingSeconds',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: AppSizes.fontM,
                    ),
                  ),
          ),
        ),

        // Intercept user interaction to prevent scrolling during countdown
        if (!_canSkip)
          Positioned.fill(
            child: GestureDetector(
              onVerticalDragEnd: (_) {},
              onVerticalDragStart: (_) {},
              onVerticalDragUpdate: (_) {},
              onTap: () {}, // Disable tapping on video area
              child: Container(
                color: Colors.transparent,
              ),
            ),
          ),

        // Pop-up view at bottom if enabled (placed AFTER gesture detector so it's clickable)
        if (_isPopUpViewEnabled())
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: RPadding.all(16),
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
                    borderRadius: BorderRadius.circular(AppSizes.radiusL),
                    child: _buildPopupImage(),
                  ),
                  SizedBox(width: AppSizes.paddingL),
                  // Right side - Text and Button
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.ad['popUpView']['popupTitle'] ?? '',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: AppSizes.fontL,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: AppSizes.paddingS),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                widget.ad['title'] ?? 'Advertisement',
                                style: TextStyle(
                                  color: Colors.grey[300],
                                  fontSize: AppSizes.fontS,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(width: AppSizes.paddingS),
                            ElevatedButton(
                              onPressed: () => _navigateToContent(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.green,
                                foregroundColor: Colors.white,
                                padding: RPadding.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppSizes.radiusL),
                                ),
                              ),
                              child: Text(
                                'View',
                                style: TextStyle(fontSize: AppSizes.fontS),
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

        // Progress indicator
        if (_videoPlayerController != null && _isVideoInitialized)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: VideoProgressIndicator(
              _videoPlayerController!,
              allowScrubbing: false,
              padding: EdgeInsets.zero,
              colors: VideoProgressColors(
                playedColor: AppColors.green,
                bufferedColor: Colors.white.withOpacity(0.5),
                backgroundColor: Colors.white.withOpacity(0.2),
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
          logger.e('Error loading popup image', tag: 'ReelAdCard', error: error);
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

    logger.d('Navigating to $contentType: $contentId', tag: 'ReelAdCard');

    // Handle different content types
    switch (contentType) {
      case 'marketplace':
        if (contentId != null && contentId.toString().isNotEmpty) {
          // Navigate to specific marketplace product detail
          Get.toNamed('/marketplace-detail', arguments: contentId);
        } else {
          // Navigate to marketplace screen if no specific product
          Get.toNamed('/marketplace');
        }
        break;

      case 'posts':
      case 'feed':
        if (contentId != null && contentId.toString().isNotEmpty) {
          // Navigate to specific feed post
          _navigateToFeedPost(contentId);
        } else {
          // Navigate to main screen (feed tab is index 1)
          Get.offAllNamed('/main');
        }
        break;

      case 'schemes':
        // Navigate to government schemes screen
        Get.toNamed('/schemes');
        break;

      case 'companies':
        // Navigate to companies screen
        Get.toNamed('/companies');
        break;

      case 'products':
      case 'fertilizers':
        // Navigate to products/fertilizers screen
        Get.toNamed('/fertilizers');
        break;

      case 'videos':
        // Navigate to video tutorials
        Get.toNamed('/krishi-videos');
        break;

      case 'ai':
      case 'krishi-ai':
        // Navigate to AI chat
        Get.toNamed('/krishi-ai');
        break;

      case 'crop-calendar':
        // Navigate to crop calendar
        Get.toNamed('/crop-calendar');
        break;

      default:
        // If no valid type, show a message
        logger.w('Unknown content type: $contentType', tag: 'ReelAdCard');
        Get.snackbar(
          'Info',
          'Content not available',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.grey.withOpacity(0.8),
          colorText: Colors.white,
        );
    }
  }

  void _navigateToFeedPost(String contentId) {
    // Show loading dialog
    Get.dialog(
      Center(
        child: CircularProgressIndicator(
          color: AppColors.green,
        ),
      ),
      barrierDismissible: false,
    );

    try {
      final feedRepository = Get.find<FeedRepository>();

      feedRepository.getFeedById(contentId).then((feedData) {
        // Close loading dialog
        if (Get.isDialogOpen ?? false) {
          Get.back();
        }
        // Navigate directly to the feed details screen
        Get.to(() => FeedDetailsScreen(feed: feedData.toJson()));
      }).catchError((error) {
        // Close loading dialog
        if (Get.isDialogOpen ?? false) {
          Get.back();
        }
        logger.e('Error loading feed post', tag: 'ReelAdCard', error: error);
        Get.snackbar(
          'Error',
          'Could not load the post',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.withOpacity(0.6),
          colorText: Colors.white,
        );
      });
    } catch (e) {
      // Close loading dialog
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
      logger.e('Navigation error', tag: 'ReelAdCard', error: e);
      Get.snackbar(
        'Error',
        'Could not navigate to the post',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.6),
        colorText: Colors.white,
      );
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
  // Tracks whether `_videoPlayerController` has been assigned. If the user
  // scrolls past this card before _initializeVideoPlayer() reaches the
  // assignment, the `late` field is still uninitialized and any access
  // (including dispose) throws LateInitializationError. Guarding dispose
  // on this flag prevents the throw and the resulting controller leak.
  bool _isControllerAssigned = false;
  static const int PRELOAD_AHEAD = 1; // Reduced to prevent memory issues
  static final Map<String, VideoPlayerController> _videoCache = {};
  static const int MAX_CACHE_SIZE = 3; // Reduced cache size for stability
  bool _isVideoInitialized = false;
  bool _isPlaying = false;
  bool _hasError = false;
  String _errorMessage = '';
  final RxBool _isDescriptionExpanded = false.obs;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _isDisposed = false;
    _cleanupCache(); // Clean cache on init to prevent memory buildup
    _initializeVideoPlayer();
  }

  Future<void> _preloadVideos() async {
    try {
      // Create a non-reactive copy to avoid RxList issues
      final reelsLength = List<ReelModel>.from(_reelController.reels).length;

      // Preload previous videos
      for (int i = 1; i <= PRELOAD_AHEAD; i++) {
        final prevIndex = widget.index - i;
        if (prevIndex < 0) break;

        await _preloadSingleVideo(prevIndex);
      }

      // Preload next videos
      for (int i = 1; i <= PRELOAD_AHEAD; i++) {
        final nextIndex = widget.index + i;
        if (nextIndex >= reelsLength) break;

        await _preloadSingleVideo(nextIndex);
      }
    } catch (e) {}
  }

  Future<void> _preloadSingleVideo(int index) async {
    // Create a non-reactive copy to avoid RxList issues
    final reelsList = List<ReelModel>.from(_reelController.reels);
    if (index >= reelsList.length) return;

    final reel = reelsList[index];
    // Use bestVideoUrl for HLS streaming support
    final videoUrl = reel.bestVideoUrl;
    if (_videoCache.containsKey(videoUrl)) return;

    // Check cache size and remove oldest entries if needed
    if (_videoCache.length >= MAX_CACHE_SIZE) {
      final oldestUrl = _videoCache.keys.first;
      await _videoCache[oldestUrl]?.dispose();
      _videoCache.remove(oldestUrl);
    }

    final uri = Uri.parse(videoUrl);
    if (!uri.isAbsolute) return;

    try {
      final controller = VideoPlayerController.networkUrl(
        uri,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );

      await controller.initialize();
      _videoCache[videoUrl] = controller;
      logger.d('Preloaded video: ${reel.isHlsStreaming ? "HLS" : "MP4"}', tag: 'ReelVideoCard');
    } catch (e) {
      logger.e('Error preloading video: $e', tag: 'ReelVideoCard');
    }
  }

  Future<void> _initializeVideoPlayer() async {
    try {
      // Check if widget is still mounted before initializing
      if (!mounted) return;

      // Use bestVideoUrl which prefers HLS for adaptive streaming
      final videoUrl = widget.reel.bestVideoUrl;
      final isHls = widget.reel.isHlsStreaming;

      logger.d('Initializing video: $videoUrl (HLS: $isHls)', tag: 'ReelVideoCard');

      // Check cache first
      if (_videoCache.containsKey(videoUrl)) {
        _videoPlayerController = _videoCache[videoUrl]!;
        _isControllerAssigned = true;
        _videoCache.remove(videoUrl);
        logger.d('Using cached video controller', tag: 'ReelVideoCard');
      } else {
        final uri = Uri.parse(videoUrl);
        if (!uri.isAbsolute) {
          logger.e('Invalid video URL: $videoUrl', tag: 'ReelVideoCard');
          throw Exception('Invalid video URL');
        }

        _videoPlayerController = VideoPlayerController.networkUrl(
          uri,
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          // HLS streaming is automatically supported by video_player
        );
        _isControllerAssigned = true;

        logger.d('Starting video initialization (${isHls ? "HLS adaptive" : "direct"})...', tag: 'ReelVideoCard');

        // Add timeout for video initialization
        await _videoPlayerController.initialize().timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw Exception('Video load timeout - check network connection');
          },
        );
        logger.d('Video initialized successfully', tag: 'ReelVideoCard');
      }

      if (_videoPlayerController.value.isInitialized && mounted && !_isDisposed) {
        setState(() {
          _isVideoInitialized = true;
          _isPlaying = true;
        });

        await _videoPlayerController.setPlaybackSpeed(1.0);
        await _videoPlayerController.setLooping(true);
        await _videoPlayerController.play();
        logger.d('Video playing', tag: 'ReelVideoCard');

        // Disable preloading to prevent memory issues
        // _preloadVideos();
      }
    } catch (e) {
      logger.e('Error initializing video: $e', tag: 'ReelVideoCard', error: e);
      if (mounted && !_isDisposed) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;

    // Only touch the controller if it actually got assigned. The user can
    // scroll past this card before _initializeVideoPlayer assigns the late
    // field; touching it then throws LateInitializationError, the previous
    // catch swallowed it, and the controller (if it managed to spawn from
    // the network call after dispose) leaked.
    if (_isControllerAssigned) {
      try {
        _videoPlayerController.pause();
      } catch (e) {
        logger.e('Error pausing video on dispose: $e', tag: 'ReelVideoCard');
      }
      try {
        if (!_videoCache.containsValue(_videoPlayerController)) {
          _videoPlayerController.dispose();
        }
      } catch (e) {
        logger.e('Error disposing video controller: $e', tag: 'ReelVideoCard');
      }
    }

    try {
      _cleanupCache();
    } catch (e) {
      logger.e('Error cleaning video cache: $e', tag: 'ReelVideoCard');
    }
    super.dispose();
  }

  void _cleanupCache() {
    // Keep only MAX_CACHE_SIZE entries
    while (_videoCache.length > MAX_CACHE_SIZE) {
      final oldestUrl = _videoCache.keys.first;
      try {
        _videoCache[oldestUrl]?.dispose();
      } catch (e) {}
      _videoCache.remove(oldestUrl);
    }
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
            // Record view for recommendation engine (once per session)
            _reelController.recordReelView(widget.reel.id);
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
            if (_hasError) ...[
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'Failed to load video',
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        _errorMessage,
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _hasError = false;
                          _errorMessage = '';
                        });
                        _initializeVideoPlayer();
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ] else if (_isVideoInitialized) ...[
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
                child: TractorLoadingIndicator(size: 100),
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
                          // Like button wrapped in Obx for immediate UI updates
                          Obx(() {
                            // Get the current reel from controller's reactive list
                            final currentReel = _reelController.reels.firstWhere(
                              (r) => r.id == widget.reel.id,
                              orElse: () => widget.reel,
                            );
                            final isLiked = currentReel.like['isLiked'] == true;
                            final likeCount = currentReel.like['count'] ?? 0;

                            return _buildInteractionButton(
                              isLiked ? Icons.favorite : Icons.favorite_border,
                              likeCount.toString(),
                              onTap: () async {
                                await _reelController.toggleLike(widget.reel.id);
                              },
                              isLiked: isLiked,
                            );
                          }),
                          const SizedBox(height: 16),
                          // Comment button wrapped in Obx for immediate UI updates
                          Obx(() {
                            final currentReel = _reelController.reels.firstWhere(
                              (r) => r.id == widget.reel.id,
                              orElse: () => widget.reel,
                            );
                            final commentCount = currentReel.comment['count'] ?? 0;

                            return _buildInteractionButton(
                              Icons.chat_bubble_outline,
                              commentCount.toString(),
                              onTap: () => _showCommentsModal(context),
                            );
                          }),
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
                              // Record share interaction for recommendations
                              _reelController.recordShare(widget.reel.id);
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
      {VoidCallback? onTap, bool isLiked = false}) {
    // Special handling for like button
    if (icon == Icons.favorite || icon == Icons.favorite_border) {
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
