import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';
import 'package:krishimantra/routes/app_routes.dart';
import '../../../core/constants/colors.dart';
import '../../../data/services/UserService.dart';
import '../../controllers/feed_controller.dart';
import '../../widgets/app_header.dart';
import 'widgets/feed_card.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({Key? key}) : super(key: key);

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final FeedController _feedController = Get.find<FeedController>();
  final UserService _userService = UserService();
  final ScrollController _scrollController = ScrollController();
  bool _showTrendingHashtags = true;
  bool _showCreatePost = false;

  final List<String> trendingHashtags = [
    '#trending',
    '#viral',
    '#latest',
    '#popular',
    '#hot',
    '#new',
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _feedController.fetchRecommendedFeeds();
    _checkUserRole();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: AppColors.green,
        statusBarIconBrightness: Brightness.light,
      ),
    );
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
    super.dispose();
  }

  Widget _buildTrendingHashtags() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: _showTrendingHashtags ? 80 : 0,
      color: AppColors.green,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 16, top: 8, bottom: 8),
              child: Text(
                'Trending Hashtags',
                style: TextStyle(
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
                itemCount: trendingHashtags.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        trendingHashtags[index],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Container(
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
                    },
                    child: Obx(
                      () => ListView.builder(
                        controller: _scrollController,
                        itemCount: _feedController.recommendedFeeds.length + 1,
                        itemBuilder: (context, index) {
                          if (index ==
                              _feedController.recommendedFeeds.length) {
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
                          return FeedCard(
                            feed: _feedController.recommendedFeeds[index],
                            onLike: () => _feedController.likeFeed(
                              _feedController.recommendedFeeds[index].id,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
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
