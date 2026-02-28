import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/utils/home_localizations.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../core/utils/language_helper.dart';
import '../../../../core/utils/translation_manager.dart';
import '../../../../data/services/language_service.dart';
import '../../../controllers/feed_controller.dart';
import '../../../widgets/skeleton/skeleton_widgets.dart';

class TrendingHashtags extends StatefulWidget {
  const TrendingHashtags({super.key});

  @override
  State<TrendingHashtags> createState() => _TrendingHashtagsState();
}

class _TrendingHashtagsState extends State<TrendingHashtags>
    with TranslationMixin {
  final FeedController _feedController = Get.find<FeedController>();
  String _languageCode = '';

  // Translation keys
  static const String KEY_TRENDING_TOPICS = 'trending_topics';

  // Colors for hashtag chips
  final List<Color> _chipColors = [
    AppColors.green,
    AppColors.orange,
    AppColors.info,
    AppColors.success,
    const Color(0xFF9C27B0), // Purple
    const Color(0xFFE91E63), // Pink
  ];

  @override
  void initState() {
    super.initState();
    _registerTranslations();
    _initializeTranslations();
    _syncLanguageCode();
    TranslationManager.instance.addLanguageChangeListener(_onLanguageChanged);
    _fetchHashtags();
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
    registerTranslation(KEY_TRENDING_TOPICS, 'Trending Topics');
  }

  Future<void> _fetchHashtags() async {
    if (_feedController.trendingHashtags.isEmpty) {
      await _feedController.fetchTrendingHashtags();
    }
  }

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);

    // Using GetBuilder instead of Obx to avoid RxList.length infinite recursion bug
    return GetBuilder<FeedController>(
      init: _feedController,
      builder: (controller) {
        // Create a non-reactive copy to avoid RxList issues
        final hashtags =
            List<Map<String, dynamic>>.from(controller.trendingHashtags);

        if (hashtags.isEmpty && !controller.isLoadingHashtags.value) {
          return const SizedBox.shrink();
        }

        if (controller.isLoadingHashtags.value) {
          return _buildLoadingState();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(
                left: AppSizes.paddingL,
                right: AppSizes.paddingL,
                top: AppSizes.paddingS,
                bottom: AppSizes.paddingS,
              ),
              child: Text(
                _tr(KEY_TRENDING_TOPICS),
                style: TextStyle(
                  fontSize: AppSizes.fontXL,
                  fontWeight: FontWeight.bold,
                  color: AppColors.green,
                ),
              ),
            ),
            SizedBox(
              height: ResponsiveUtils.responsive(mobile: 38.0, tablet: 48.0),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: AppSizes.paddingL),
                itemCount: hashtags.length > 8 ? 8 : hashtags.length,
                itemBuilder: (context, index) {
                  final hashtag = hashtags[index];
                  final tagName = hashtag['name'] as String;
                  final count = hashtag['count'] ?? 0;
                  return _buildHashtagChip(tagName, count, index);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLoadingState() {
    // Varying widths for more realistic skeleton appearance
    final widths = [80.0, 100.0, 70.0, 90.0, 85.0];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: AppSizes.paddingL,
            right: AppSizes.paddingL,
            top: AppSizes.paddingS,
            bottom: AppSizes.paddingS,
          ),
          child: Text(
            _tr(KEY_TRENDING_TOPICS),
            style: TextStyle(
              fontSize: AppSizes.fontXL,
              fontWeight: FontWeight.bold,
              color: AppColors.green,
            ),
          ),
        ),
        SizedBox(
          height: ResponsiveUtils.responsive(mobile: 38.0, tablet: 48.0),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: AppSizes.paddingL),
            itemCount: 5,
            itemBuilder: (context, index) {
              return SkeletonHashtagChip(width: widths[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHashtagChip(String tagName, int count, int index) {
    final color = _chipColors[index % _chipColors.length];

    return GestureDetector(
      onTap: () {
        // Set selected hashtag and navigate to feed screen
        _feedController.selectedTag.value = tagName;
        Get.toNamed('/main', arguments: {'tab': 1});
      },
      child: Container(
        margin: EdgeInsets.only(right: AppSizes.paddingS),
        padding: EdgeInsets.symmetric(
          horizontal: AppSizes.paddingS + 2,
          vertical: AppSizes.paddingXS,
        ),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppSizes.radiusXXL),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.tag,
              size: AppSizes.iconXS,
              color: color,
            ),
            SizedBox(width: 2),
            Text(
              tagName,
              style: TextStyle(
                fontSize: AppSizes.fontS,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
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
