import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';
import 'package:krishimantra/routes/app_routes.dart';
import '../../../core/constants/colors.dart';
import '../../../data/services/UserService.dart';
import '../../../data/services/language_service.dart';
import '../../controllers/ads_controller.dart';
import '../../controllers/feed_controller.dart';
import '../../widgets/app_header.dart';
import 'widgets/feed_card.dart';
import 'dart:math';

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

    // Load more content when reaching bottom
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      _feedController.fetchRecommendedFeeds();
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
      setState(() {});
    } catch (e) {
      print('Error loading feed ads: $e');
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
                // Content Section
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: RefreshIndicator(
                      onRefresh: () async {
                        await _feedController.fetchRecommendedFeeds(
                            refresh: true);
                        await _loadFeedAds(); // Refresh ads too
                      },
                      child: Obx(
                        () {
                          final feeds = _feedController.recommendedFeeds;
                          // Calculate total items including ads after 5th position
                          int totalItems = feeds.length + 1; // +1 for loading indicator
                          if (feeds.length > 5 && _feedAds.isNotEmpty) {
                            // Add potential ad positions after 5th item
                            int adPositions = (feeds.length - 5) ~/ 3;
                            totalItems += adPositions;
                          }
                          
                          return ListView.builder(
                            controller: _scrollController,
                            itemCount: totalItems,
                            itemBuilder: (context, index) {
                              // Check if this is the last item (loading indicator)
                              if (index == totalItems - 1) {
                                return Obx(() {
                                  if (_feedController.isRecommendedLoading.value) {
                                    return const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(16.0),
                                        child: CircularProgressIndicator(
                                          color: AppColors.green,
                                        ),
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                });
                              }
                              
                              // Determine if this position should show an ad
                              // Logic: after 5th item, potentially show an ad every 3 items with some randomness
                              if (index > 5 && _feedAds.isNotEmpty && (index - 5) % 3 == 0 && _random.nextBool()) {
                                // Show a random ad
                                final adIndex = _random.nextInt(_feedAds.length);
                                final ad = _feedAds[adIndex];
                                
                                // Display ad content as image
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: InkWell(
                                          onTap: () {
                                            // Handle ad click if needed
                                            if (ad['dirURL'] != null) {
                                              // Navigate or handle the ad link
                                            }
                                          },
                                          child: Image.network(
                                            ad['content'],
                                            width: double.infinity,
                                            height: 200,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              return Container(
                                                width: double.infinity,
                                                height: 200,
                                                color: Colors.grey[300],
                                                child: const Icon(Icons.image_not_supported, size: 50),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                      const Divider(),
                                    ],
                                  ),
                                );
                              }
                              
                              // Adjust the feed index to account for ads
                              int feedIndex = index;
                              if (index > 5 && _feedAds.isNotEmpty) {
                                feedIndex = index - ((index - 5) ~/ 3);
                              }
                              
                              // Return regular feed item if within range
                              if (feedIndex < feeds.length) {
                                return FeedCard(
                                  feed: feeds[feedIndex],
                                  onLike: () => _feedController.likeFeed(
                                    feeds[feedIndex].id,
                                  ),
                                );
                              }
                              
                              return const SizedBox.shrink();
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: _showCreatePost
          ? FloatingActionButton(
              backgroundColor: AppColors.green,
              onPressed: () {
                Get.offAllNamed(AppRoutes.CREATE_POST);
              },
              child: const Icon(Icons.add, color: AppColors.white),
            )
          : null,
    );
  }
}
