import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';
import 'package:krishimantra/routes/app_routes.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/error_handler.dart';
import '../../../data/services/UserService.dart';
import '../../../data/services/language_service.dart';
import '../../controllers/ads_controller.dart';
import '../../controllers/feed_controller.dart';
import '../../widgets/app_header.dart';
import 'widgets/feed_card.dart';
import 'dart:math';
import '../../../utils/image_utils.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({Key? key}) : super(key: key);

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> with WidgetsBindingObserver {
  final FeedController _feedController = Get.find<FeedController>();
  final AdsController _adsController = Get.find<AdsController>();
  final UserService _userService = UserService();
  late LanguageService _languageService;
  final ScrollController _scrollController = ScrollController();
  bool _showTrendingHashtags = true;
  bool _showCreatePost = false;

  // Add properties for feed ads
  List<dynamic> _feedAds = [];
  final Random _random = Random();

  // Add this property to track if the screen was inactive
  bool _wasInactive = false;

  // Translatable text
  String trendingHashtagsText = 'Trending Hashtags';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _feedController.fetchTrendingHashtags();
    _feedController.fetchRecommendedFeeds();
    _checkUserRole();
    _initializeLanguage();
    _loadFeedAds(); // Load feed ads
    // Register for lifecycle events
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: AppColors.green,
        statusBarIconBrightness: Brightness.light,
      ),
    );
  }

  Future<void> _initializeLanguage() async {
    _languageService = await LanguageService.getInstance();
    await _updateTranslations();
  }

  Future<void> _updateTranslations() async {
    final translations = await Future.wait([
      _languageService.translate('Trending Hashtags'),
    ]);

    setState(() {
      trendingHashtagsText = translations[0];
    });

    // Translate existing feed content
    for (var feed in _feedController.recommendedFeeds) {
      final translatedFeed = feed.copyWith(
          description: await _languageService.translate(feed.description),
          content: await _languageService.translate(feed.content));
      _feedController.recommendedFeeds[
          _feedController.recommendedFeeds.indexOf(feed)] = translatedFeed;
    }
    setState(() {});
  }

  Future<void> _checkUserRole() async {
    String? accountType = await _userService.getAccountType();
    setState(() {
      _showCreatePost = accountType == 'admin' || accountType == 'consultant';
    });
  }

  void _onScroll() {
    // Hide trending hashtags when scrolling down, show when at top
    if (_scrollController.offset > 0 && _showTrendingHashtags) {
      setState(() => _showTrendingHashtags = false);
    } else if (_scrollController.offset <= 0 && !_showTrendingHashtags) {
      setState(() => _showTrendingHashtags = true);
    }

    // Load more content when reaching 80% of the scroll length for better UX
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      if (!_feedController.isRecommendedLoading.value &&
          _feedController.hasMoreRecommendedFeeds.value) {
        _feedController.fetchRecommendedFeeds();
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    // Remove lifecycle observer
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Add lifecycle method to detect when screen becomes visible again
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _wasInactive = true;
    } else if (state == AppLifecycleState.resumed && _wasInactive) {
      // Reset to recommended feeds when coming back to the app
      _resetToRecommendedFeeds();
      _wasInactive = false;
    }
    super.didChangeAppLifecycleState(state);
  }

  // Add a method to handle resetting to recommended feeds
  void _resetToRecommendedFeeds() {
    if (_feedController.selectedTag.value.isNotEmpty) {
      _feedController.clearSelectedTag();
    }
  }

  // Add method to load feed ads
  Future<void> _loadFeedAds() async {
    try {
      _feedAds = await _adsController.fetchFeedAds();
      print('📊 Feed ads loaded: ${_feedAds.length}');
      if (_feedAds.isNotEmpty) {
        print('📱 First ad URL: ${_feedAds[0]['content']}');
      }
      setState(() {});
    } catch (e) {
      print('❌ Error loading feed ads: $e');
    }
  }

  Widget _buildTrendingHashtags() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: _showTrendingHashtags ? 80 : 0,
      color: AppColors.green,
      child: Obx(() {
        if (_feedController.isLoadingHashtags.value) {
          return const Center(
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          );
        }

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
                child: Text(
                  trendingHashtagsText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(left: 16),
                  itemCount: _feedController.trendingHashtags.length,
                  itemBuilder: (context, index) {
                    final hashtag = _feedController.trendingHashtags[index];
                    final tagName = hashtag['name'] as String;

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          _feedController.fetchFeedsByTag(tagName,
                              refresh: true);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _feedController.selectedTag.value == tagName
                                ? Colors.white
                                : Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '#$tagName',
                            style: TextStyle(
                              color:
                                  _feedController.selectedTag.value == tagName
                                      ? AppColors.green
                                      : Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Focus(
        onFocusChange: (hasFocus) {
          if (hasFocus) {
            // When screen gets focus again, reset to recommended feeds
            _resetToRecommendedFeeds();
          }
        },
        child: Container(
          color: AppColors.green,
          child: SafeArea(
            child: Column(
              children: [
                // Header Section with green background
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: AppHeader(),
                ),
                _buildTrendingHashtags(),
                SizedBox(
                  height: 20,
                ),

                // Content Section with white background and rounded corners at top
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () =>
                        _feedController.fetchRecommendedFeeds(refresh: true),
                    color: AppColors.green,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(24),
                          topRight: Radius.circular(24),
                        ),
                      ),
                      child: Obx(() {
                        // Show loading state
                        if (_feedController.isLoading &&
                            _feedController.recommendedFeeds.isEmpty) {
                          return const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.green),
                            ),
                          );
                        }

                        // Show error state
                        if (_feedController.hasError) {
                          return ErrorHandler.getErrorWidget(
                            errorType:
                                _feedController.errorType ?? ErrorType.unknown,
                            onRetry: () => _feedController
                                .fetchRecommendedFeeds(refresh: true),
                            showRetry: true,
                          );
                        }

                        // Show empty state
                        if (_feedController.recommendedFeeds.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.article_outlined,
                                    size: 64, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                Text(
                                  'No posts available',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton(
                                  onPressed: () => _feedController
                                      .fetchRecommendedFeeds(refresh: true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                  ),
                                  child: const Text('Refresh'),
                                ),
                              ],
                            ),
                          );
                        }

                        // Show content
                        return _buildFeedContent();
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

      // Show create post button for authorized users
      floatingActionButton: _showCreatePost
          ? FloatingActionButton(
              onPressed: () => Get.toNamed(AppRoutes.CREATE_POST),
              backgroundColor: AppColors.green,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildFeedContent() {
    // Calculate the number of posts to show between ads
    final postsWithAds = <Widget>[];
    final postsPerAd = 4; // Show an ad after every 4 posts

    for (var i = 0; i < _feedController.recommendedFeeds.length; i++) {
      // Add feed item
      postsWithAds.add(_buildFeedItem(_feedController.recommendedFeeds[i]));

      // Insert an ad after every postsPerAd items if we have ads
      if (_feedAds.isNotEmpty &&
          (i + 1) % postsPerAd == 0 &&
          i < _feedController.recommendedFeeds.length - 1) {
        final adIndex = _random.nextInt(_feedAds.length);
        postsWithAds.add(_buildAdCard(_feedAds[adIndex]));
      }
    }

    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: postsWithAds.length + 1, // +1 for loading indicator
      itemBuilder: (context, index) {
        if (index < postsWithAds.length) {
          return postsWithAds[index];
        } else {
          // Loading indicator at the bottom
          return Obx(() => _feedController.isRecommendedLoading.value
              ? Container(
                  height: 100,
                  padding: const EdgeInsets.all(16),
                  alignment: Alignment.center,
                  child: Image.asset(
                    'assets/Images/krishimantraloading.gif',
                    height: 50,
                    width: 50,
                  ),
                )
              : const SizedBox());
        }
      },
    );
  }

  Widget _buildFeedItem(feed) {
    return FeedCard(
      feed: feed,
      onLike: () => _feedController.likeFeed(feed.id),
    );
  }

  Widget _buildAdCard(dynamic ad) {
    // Validate and sanitize the URL
    final String validatedUrl = ImageUtils.validateUrl(ad['content'] ?? '');

    if (validatedUrl.isEmpty) {
      print('⚠️ Invalid ad URL: ${ad['content']}');
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey[200],
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.image_not_supported, color: Colors.grey, size: 48),
                SizedBox(height: 8),
                Text(
                  ad['title'] ?? 'Advertisement',
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          validatedUrl,
          height: 200,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            print('❌ Error loading ad image: $error');
            return Container(
              height: 200,
              color: Colors.grey[200],
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.grey, size: 48),
                    SizedBox(height: 8),
                    Text(
                      ad['title'] ?? 'Advertisement',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
