import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';
import 'package:krishimantra/routes/app_routes.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/error_handler.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../core/utils/language_helper.dart';
import '../../../data/services/UserService.dart';
import '../../../data/services/language_service.dart';
import '../../controllers/ads_controller.dart';
import '../../controllers/feed_controller.dart';
import '../../widgets/app_header.dart';
import '../../widgets/skeleton/skeleton_widgets.dart';
import 'widgets/feed_card.dart';
import 'dart:math';
import '../../../utils/image_utils.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({Key? key}) : super(key: key);

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> with WidgetsBindingObserver, TranslationMixin {
  final FeedController _feedController = Get.find<FeedController>();
  final AdsController _adsController = Get.find<AdsController>();
  final UserService _userService = UserService();
  late LanguageService _languageService;
  final ScrollController _scrollController = ScrollController();
  bool _showTrendingHashtags = true;
  bool _showCreatePost = false;

  List<dynamic> _feedAds = [];
  final Random _random = Random();
  bool _wasInactive = false;

  // Translation keys
  static const String KEY_TRENDING_HASHTAGS = 'trending_hashtags';
  static const String KEY_NO_POSTS = 'no_posts';
  static const String KEY_REFRESH = 'refresh';
  static const String KEY_ADVERTISEMENT = 'advertisement';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _feedController.fetchTrendingHashtags();
    _feedController.fetchRecommendedFeeds();
    _checkUserRole();
    _registerTranslations();
    _initializeLanguage();
    _loadFeedAds();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: AppColors.green,
        statusBarIconBrightness: Brightness.light,
      ),
    );
  }

  void _registerTranslations() {
    registerTranslation(KEY_TRENDING_HASHTAGS, 'Trending Hashtags');
    registerTranslation(KEY_NO_POSTS, 'No posts available');
    registerTranslation(KEY_REFRESH, 'Refresh');
    registerTranslation(KEY_ADVERTISEMENT, 'Advertisement');
  }

  Future<void> _initializeLanguage() async {
    _languageService = await LanguageService.getInstance();
    await _updateTranslations();
  }

  Future<void> _updateTranslations() async {
    await updateTranslations();

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
    if (_scrollController.offset > 0 && _showTrendingHashtags) {
      setState(() => _showTrendingHashtags = false);
    } else if (_scrollController.offset <= 0 && !_showTrendingHashtags) {
      setState(() => _showTrendingHashtags = true);
    }

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
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _wasInactive = true;
    } else if (state == AppLifecycleState.resumed && _wasInactive) {
      _resetToRecommendedFeeds();
      _wasInactive = false;
    }
    super.didChangeAppLifecycleState(state);
  }

  void _resetToRecommendedFeeds() {
    if (_feedController.selectedTag.value.isNotEmpty) {
      _feedController.clearSelectedTag();
    }
  }

  Future<void> _loadFeedAds() async {
    try {
      _feedAds = await _adsController.fetchFeedAds();
      logger.d('Feed ads loaded: ${_feedAds.length}', tag: 'FeedScreen');
      if (_feedAds.isNotEmpty) {
        logger.d('First ad URL: ${_feedAds[0]['content']}', tag: 'FeedScreen');
      }
      setState(() {});
    } catch (e) {
      logger.e('Error loading feed ads', tag: 'FeedScreen', error: e);
    }
  }

  Widget _buildTrendingHashtags() {
    ResponsiveUtils.init(context);
    final hashtagsHeight = ResponsiveUtils.responsive(
      mobile: ResponsiveUtils.hp(10),
      tablet: ResponsiveUtils.hp(8),
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: _showTrendingHashtags ? hashtagsHeight : 0,
      color: AppColors.green,
      child: Obx(() {
        if (_feedController.isLoadingHashtags.value) {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: RPadding.only(left: 16, top: 8, bottom: 8),
                  child: Text(
                    getTranslation(KEY_TRENDING_HASHTAGS),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: AppSizes.fontL,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(
                  height: ResponsiveUtils.hp(5),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: RPadding.only(left: 16),
                    itemCount: 5,
                    itemBuilder: (context, index) {
                      final widths = [80.0, 100.0, 70.0, 90.0, 85.0];
                      return SkeletonHashtagChip(width: widths[index]);
                    },
                  ),
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: RPadding.only(left: 16, top: 8, bottom: 8),
                child: Text(
                  getTranslation(KEY_TRENDING_HASHTAGS),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: AppSizes.fontL,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(
                height: ResponsiveUtils.hp(5),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: RPadding.only(left: 16),
                  itemCount: _feedController.trendingHashtags.length,
                  itemBuilder: (context, index) {
                    final hashtag = _feedController.trendingHashtags[index];
                    final tagName = hashtag['name'] as String;

                    return Padding(
                      padding: RPadding.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          _feedController.fetchFeedsByTag(tagName,
                              refresh: true);
                        },
                        child: Container(
                          padding: RPadding.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: _feedController.selectedTag.value == tagName
                                ? Colors.white
                                : Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(AppSizes.radiusXXL),
                          ),
                          child: Text(
                            '#$tagName',
                            style: TextStyle(
                              color:
                                  _feedController.selectedTag.value == tagName
                                      ? AppColors.green
                                      : Colors.white,
                              fontSize: AppSizes.fontM,
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
    ResponsiveUtils.init(context);

    return Scaffold(
      backgroundColor: AppColors.white,
      body: Focus(
        onFocusChange: (hasFocus) {
          if (hasFocus) {
            _resetToRecommendedFeeds();
          }
        },
        child: Container(
          color: AppColors.green,
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: RPadding.all(16),
                  child: const AppHeader(),
                ),
                _buildTrendingHashtags(),
                SizedBox(height: AppSizes.paddingL),

                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () =>
                        _feedController.fetchRecommendedFeeds(refresh: true),
                    color: AppColors.green,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(AppSizes.radiusXXL),
                          topRight: Radius.circular(AppSizes.radiusXXL),
                        ),
                      ),
                      child: Obx(() {
                        if (_feedController.isLoading &&
                            _feedController.recommendedFeeds.isEmpty) {
                          return ListView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: 3,
                            itemBuilder: (context, index) {
                              return const SkeletonFeedCard();
                            },
                          );
                        }

                        if (_feedController.hasError) {
                          return ErrorHandler.getErrorWidget(
                            errorType:
                                _feedController.errorType ?? ErrorType.unknown,
                            onRetry: () => _feedController
                                .fetchRecommendedFeeds(refresh: true),
                            showRetry: true,
                          );
                        }

                        if (_feedController.recommendedFeeds.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.article_outlined,
                                    size: AppSizes.iconXL,
                                    color: AppColors.textLight),
                                SizedBox(height: AppSizes.paddingL),
                                Text(
                                  getTranslation(KEY_NO_POSTS),
                                  style: TextStyle(
                                    fontSize: AppSizes.fontXL,
                                    color: AppColors.textGrey,
                                  ),
                                ),
                                SizedBox(height: AppSizes.paddingXL),
                                ElevatedButton(
                                  onPressed: () => _feedController
                                      .fetchRecommendedFeeds(refresh: true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.green,
                                    foregroundColor: Colors.white,
                                    padding: RPadding.symmetric(
                                        horizontal: 16, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(AppSizes.radiusL),
                                    ),
                                  ),
                                  child: Text(
                                    getTranslation(KEY_REFRESH),
                                    style: TextStyle(fontSize: AppSizes.fontM),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

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
      floatingActionButton: _showCreatePost
          ? FloatingActionButton(
              onPressed: () => Get.toNamed(AppRoutes.CREATE_POST),
              backgroundColor: AppColors.green,
              child: Icon(Icons.add, size: AppSizes.iconM),
            )
          : null,
    );
  }

  Widget _buildFeedContent() {
    final postsWithAds = <Widget>[];
    final postsPerAd = 4;

    for (var i = 0; i < _feedController.recommendedFeeds.length; i++) {
      postsWithAds.add(_buildFeedItem(_feedController.recommendedFeeds[i]));

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
      itemCount: postsWithAds.length + 1,
      itemBuilder: (context, index) {
        if (index < postsWithAds.length) {
          return postsWithAds[index];
        } else {
          return Obx(() => _feedController.isRecommendedLoading.value
              ? Container(
                  height: ResponsiveUtils.hp(12),
                  padding: RPadding.all(16),
                  alignment: Alignment.center,
                  child: Image.asset(
                    'assets/Images/krishimantraloading.gif',
                    height: AppSizes.iconXL,
                    width: AppSizes.iconXL,
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
      onView: () => _feedController.trackFeedView(feed.id),
      onShare: () => _feedController.trackFeedShare(feed.id),
      onSave: () => _feedController.trackFeedSave(feed.id),
    );
  }

  Widget _buildAdCard(dynamic ad) {
    final String validatedUrl = ImageUtils.validateUrl(ad['content'] ?? '');
    final adHeight = ResponsiveUtils.responsive(
      mobile: ResponsiveUtils.hp(25),
      tablet: ResponsiveUtils.hp(20),
    );

    if (validatedUrl.isEmpty) {
      logger.w('Invalid ad URL: ${ad['content']}', tag: 'FeedScreen');
      return Container(
        margin: RPadding.symmetric(horizontal: 16, vertical: 8),
        height: adHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSizes.radiusL),
          color: AppColors.shimmerBase,
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowLight,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSizes.radiusL),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.image_not_supported, color: AppColors.textGrey, size: AppSizes.iconXL),
                SizedBox(height: AppSizes.paddingS),
                Text(
                  ad['title'] ?? getTranslation(KEY_ADVERTISEMENT),
                  style: TextStyle(
                    color: AppColors.textGrey,
                    fontSize: AppSizes.fontM,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      margin: RPadding.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        child: Image.network(
          validatedUrl,
          height: adHeight,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            logger.e('Error loading ad image', tag: 'FeedScreen', error: error);
            return Container(
              height: adHeight,
              color: AppColors.shimmerBase,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, color: AppColors.textGrey, size: AppSizes.iconXL),
                    SizedBox(height: AppSizes.paddingS),
                    Text(
                      ad['title'] ?? getTranslation(KEY_ADVERTISEMENT),
                      style: TextStyle(
                        color: AppColors.textGrey,
                        fontSize: AppSizes.fontM,
                      ),
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
