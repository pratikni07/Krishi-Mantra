import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/utils/home_localizations.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../core/utils/language_helper.dart';
import '../../../../core/utils/translation_manager.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../data/services/language_service.dart';
import '../../../controllers/reel_controller.dart';
import '../../../widgets/skeleton/skeleton_widgets.dart';
import '../../reel/reels_page.dart';

class TrendingReelsSection extends StatefulWidget {
  const TrendingReelsSection({super.key});

  @override
  State<TrendingReelsSection> createState() => _TrendingReelsSectionState();
}

class _TrendingReelsSectionState extends State<TrendingReelsSection>
    with TranslationMixin {
  final ReelController _reelController = Get.find<ReelController>();
  String _languageCode = '';

  // Translation keys
  static const String KEY_TRENDING_VIDEOS = 'trending_videos';
  static const String KEY_VIEW_ALL = 'view_all';
  static const String KEY_VIEWS = 'views';

  @override
  void initState() {
    super.initState();
    _registerTranslations();
    _initializeTranslations();
    _syncLanguageCode();
    TranslationManager.instance.addLanguageChangeListener(_onLanguageChanged);
  }

  Future<void> _initializeTranslations() async {
    if (!mounted) return;
  }

  Future<void> _onLanguageChanged() async {
    await _syncLanguageCode();
  }

  Future<void> _syncLanguageCode() async {
    final languageService = await LanguageService.getInstance();
    if (!mounted) return;
    setState(() {
      _languageCode = languageService.getLanguageCode();
    });
  }

  void _registerTranslations() {
    registerTranslation(KEY_TRENDING_VIDEOS, 'Trending Videos');
    registerTranslation(KEY_VIEW_ALL, 'View All');
    registerTranslation(KEY_VIEWS, 'views');
  }

  String _formatViewCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  String _getVideoThumbnail(String videoUrl) {
    // For video URLs, we'll use a placeholder or generate thumbnail
    // Most video platforms provide thumbnail URLs
    if (videoUrl.isEmpty) return '';

    // If it's a direct video URL, return as is for now
    // In production, you'd want to generate a thumbnail
    return videoUrl;
  }

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);

    // Using GetBuilder instead of Obx to avoid RxList.length infinite recursion bug
    return GetBuilder<ReelController>(
      init: _reelController,
      builder: (controller) {
        // Create a non-reactive copy to avoid RxList issues
        final allReels = List.from(controller.reels);
        final reels = allReels.take(5).toList();

        // Show skeleton while loading
        if (controller.isLoading && reels.isEmpty) {
          return _buildLoadingState();
        }

        if (reels.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSizes.paddingL,
                vertical: AppSizes.paddingM,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _tr(KEY_TRENDING_VIDEOS),
                    style: TextStyle(
                      fontSize: AppSizes.fontXL,
                      fontWeight: FontWeight.bold,
                      color: AppColors.green,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      // Navigate to reels page - pass a non-reactive copy
                      Get.to(
                          () => ReelsPage(reels: List.from(controller.reels)));
                    },
                    child: Row(
                      children: [
                        Text(
                          _tr(KEY_VIEW_ALL),
                          style: TextStyle(
                            fontSize: AppSizes.fontM,
                            color: AppColors.green,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: AppSizes.iconS,
                          color: AppColors.green,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: ResponsiveUtils.responsive(mobile: 180.0, tablet: 220.0),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: AppSizes.paddingL),
                itemCount: reels.length,
                itemBuilder: (context, index) {
                  final reel = reels[index];
                  return _buildReelCard(reel, index);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSizes.paddingL,
            vertical: AppSizes.paddingM,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _tr(KEY_TRENDING_VIDEOS),
                style: TextStyle(
                  fontSize: AppSizes.fontXL,
                  fontWeight: FontWeight.bold,
                  color: AppColors.green,
                ),
              ),
              SkeletonContainer(
                width: 60,
                height: 16,
                borderRadius: 4,
              ),
            ],
          ),
        ),
        SizedBox(
          height: ResponsiveUtils.responsive(mobile: 180.0, tablet: 220.0),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: AppSizes.paddingL),
            itemCount: 4,
            itemBuilder: (context, index) {
              return const SkeletonReelCard();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReelCard(dynamic reel, int index) {
    final viewCount = reel.like['count'] ?? 0;

    return GestureDetector(
      onTap: () {
        // Navigate to reels page starting from this reel - pass a non-reactive copy
        Get.to(() => ReelsPage(
              reels: List.from(_reelController.reels),
              initialIndex: index,
            ));
      },
      child: Container(
        width: ResponsiveUtils.responsive(mobile: 130.0, tablet: 160.0),
        margin: EdgeInsets.only(right: AppSizes.paddingM),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSizes.radiusL),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowLight,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSizes.radiusL),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Video thumbnail/preview - Use thumbnail if available, fallback to placeholder
              Container(
                color: AppColors.shimmerBase,
                child: reel.thumbnail.isNotEmpty
                    ? Image.network(
                        reel.thumbnail,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: AppColors.green.withOpacity(0.1),
                            child: Icon(
                              Icons.play_circle_outline,
                              size: AppSizes.iconXL,
                              color: AppColors.green,
                            ),
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: AppColors.shimmerBase,
                            child: Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.green.withOpacity(0.5),
                                ),
                              ),
                            ),
                          );
                        },
                      )
                    : Container(
                        color: AppColors.green.withOpacity(0.1),
                        child: Icon(
                          Icons.play_circle_outline,
                          size: AppSizes.iconXL,
                          color: AppColors.green,
                        ),
                      ),
              ),
              // Gradient overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                    stops: const [0.5, 1.0],
                  ),
                ),
              ),
              // Play icon
              Center(
                child: Container(
                  padding: EdgeInsets.all(AppSizes.paddingS),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.play_arrow,
                    color: AppColors.green,
                    size: AppSizes.iconM,
                  ),
                ),
              ),
              // View count and user info
              Positioned(
                bottom: AppSizes.paddingS,
                left: AppSizes.paddingS,
                right: AppSizes.paddingS,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reel.userName ?? '',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: AppSizes.fontS,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.favorite,
                          color: Colors.white,
                          size: AppSizes.iconXS,
                        ),
                        SizedBox(width: 4),
                        Text(
                          _formatViewCount(viewCount),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: AppSizes.fontXS,
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
  void dispose() {
    TranslationManager.instance
        .removeLanguageChangeListener(_onLanguageChanged);
    super.dispose();
  }

  String _tr(String key) {
    if (_languageCode.isEmpty) {
      return '';
    }
    return HomeLocalizations.text(key, _languageCode);
  }
}
