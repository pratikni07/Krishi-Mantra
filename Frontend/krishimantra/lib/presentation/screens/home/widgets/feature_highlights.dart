import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/utils/home_localizations.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../core/utils/language_helper.dart';
import '../../../../core/utils/translation_manager.dart';
import '../../../../data/services/language_service.dart';
import '../../../../routes/app_routes.dart';

class FeatureHighlights extends StatefulWidget {
  const FeatureHighlights({super.key});

  @override
  State<FeatureHighlights> createState() => _FeatureHighlightsState();
}

class _FeatureHighlightsState extends State<FeatureHighlights>
    with TranslationMixin {
  String _languageCode = '';
  // Translation keys
  static const String KEY_QUICK_ACCESS = 'quick_access';
  static const String KEY_EXPERT_CHAT = 'expert_chat';
  static const String KEY_EXPERT_SUBTITLE = 'expert_subtitle';
  static const String KEY_LEARN_VIDEOS = 'learn_videos';
  static const String KEY_VIDEOS_SUBTITLE = 'videos_subtitle';
  static const String KEY_WEATHER = 'weather';
  static const String KEY_WEATHER_SUBTITLE = 'weather_subtitle';
  static const String KEY_SETTINGS = 'settings';
  static const String KEY_SETTINGS_SUBTITLE = 'settings_subtitle';

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
    registerTranslation(KEY_QUICK_ACCESS, 'Quick Access');
    registerTranslation(KEY_EXPERT_CHAT, 'Expert Chat');
    registerTranslation(KEY_EXPERT_SUBTITLE, 'Talk to farming experts');
    registerTranslation(KEY_LEARN_VIDEOS, 'Learn Farming');
    registerTranslation(KEY_VIDEOS_SUBTITLE, 'Watch tutorial videos');
    registerTranslation(KEY_WEATHER, 'Weather');
    registerTranslation(KEY_WEATHER_SUBTITLE, 'Check forecast');
    registerTranslation(KEY_SETTINGS, 'Settings');
    registerTranslation(KEY_SETTINGS_SUBTITLE, 'App preferences');
  }

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);

    final features = [
      _FeatureItem(
        icon: Icons.support_agent_outlined,
        title: _tr(KEY_EXPERT_CHAT),
        subtitle: _tr(KEY_EXPERT_SUBTITLE),
        color: AppColors.green,
        route: AppRoutes.CONSULTATION,
      ),
      _FeatureItem(
        icon: Icons.play_circle_outline,
        title: _tr(KEY_LEARN_VIDEOS),
        subtitle: _tr(KEY_VIDEOS_SUBTITLE),
        color: AppColors.orange,
        route: AppRoutes.KRISHI_VIDEOS,
      ),
      _FeatureItem(
        icon: Icons.wb_sunny_outlined,
        title: _tr(KEY_WEATHER),
        subtitle: _tr(KEY_WEATHER_SUBTITLE),
        color: AppColors.info,
        route: AppRoutes.MAIN,
        arguments: {'tab': 2},
      ),
      _FeatureItem(
        icon: Icons.settings_outlined,
        title: _tr(KEY_SETTINGS),
        subtitle: _tr(KEY_SETTINGS_SUBTITLE),
        color: AppColors.success,
        route: AppRoutes.SETTINGS,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: AppSizes.paddingL,
            right: AppSizes.paddingL,
            bottom: 5,
          ),
          child: Text(
            _tr(KEY_QUICK_ACCESS),
            style: TextStyle(
              fontSize: AppSizes.fontXL,
              fontWeight: FontWeight.bold,
              color: AppColors.green,
            ),
          ),
        ),
        GridView.builder(
          padding: EdgeInsets.symmetric(horizontal: AppSizes.paddingL),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: AppSizes.paddingM,
            mainAxisSpacing: AppSizes.paddingM,
            childAspectRatio: 1.4,
          ),
          itemCount: features.length,
          itemBuilder: (context, index) {
            return _buildFeatureCard(features[index]);
          },
        ),
      ],
    );
  }

  Widget _buildFeatureCard(_FeatureItem feature) {
    return GestureDetector(
      onTap: () => Get.toNamed(feature.route, arguments: feature.arguments),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppSizes.radiusL),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowLight,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: feature.color.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(AppSizes.paddingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(AppSizes.paddingS),
                decoration: BoxDecoration(
                  color: feature.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppSizes.radiusM),
                ),
                child: Icon(
                  feature.icon,
                  color: feature.color,
                  size: AppSizes.iconL,
                ),
              ),
              SizedBox(height: AppSizes.paddingS),
              Text(
                feature.title,
                style: TextStyle(
                  fontSize: AppSizes.fontM,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 2),
              Text(
                feature.subtitle,
                style: TextStyle(
                  fontSize: AppSizes.fontS,
                  color: AppColors.textGrey,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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

class _FeatureItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final String route;
  final Map<String, dynamic>? arguments;

  _FeatureItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.route,
    this.arguments,
  });
}
