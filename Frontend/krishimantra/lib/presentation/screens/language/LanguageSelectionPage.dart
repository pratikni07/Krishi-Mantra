import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:get/get.dart';

import '../../../core/constants/colors.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../data/services/language_service.dart';
import '../../../core/utils/translation_manager.dart';
import '../../../routes/app_routes.dart';
import '../../../core/utils/language_helper.dart';

// LanguageData class remains the same
class LanguageData {
  final String name;
  final String nativeName;
  final String flagEmoji;

  LanguageData({
    required this.name,
    required this.nativeName,
    required this.flagEmoji,
  });
}

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen>
    with SingleTickerProviderStateMixin, TranslationMixin {
  late AnimationController _earthController;
  String? selectedLanguage;

  // Translation keys
  static const String KEY_CHOOSE_LANGUAGE = 'choose_language';
  static const String KEY_SELECT_PREFERRED = 'select_preferred';
  static const String KEY_CONTINUE = 'continue_button';
  static const String KEY_SELECT_LANGUAGE = 'select_language';

  final List<LanguageData> languages = [
    LanguageData(
      name: 'English',
      nativeName: 'English',
      flagEmoji: '🇺🇸',
    ),
    LanguageData(
      name: 'Hindi',
      nativeName: 'हिंदी',
      flagEmoji: '🇮🇳',
    ),
    LanguageData(
      name: 'Marathi',
      nativeName: 'मराठी',
      flagEmoji: '🇮🇳',
    ),
    LanguageData(
      name: 'Gujarati',
      nativeName: 'ગુજરાતી',
      flagEmoji: '🇮🇳',
    ),
    LanguageData(
      name: 'Bengali',
      nativeName: 'বাংলা',
      flagEmoji: '🇮🇳',
    ),
    LanguageData(
      name: 'Tamil',
      nativeName: 'தமிழ்',
      flagEmoji: '🇮🇳',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _earthController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();
    _initializeLanguage();
    _registerTranslations();
  }

  void _registerTranslations() {
    registerTranslation(KEY_CHOOSE_LANGUAGE, 'Choose Your Language');
    registerTranslation(KEY_SELECT_PREFERRED, 'Select the language you prefer');
    registerTranslation(KEY_CONTINUE, 'Continue');
    registerTranslation(KEY_SELECT_LANGUAGE, 'Select a language');
  }

  Future<void> _initializeLanguage() async {
    final languageService = await LanguageService.getInstance();
    setState(() {
      selectedLanguage = languageService.getLanguage();
    });
    // The TranslationMixin will handle initialization
  }

  @override
  void dispose() {
    _earthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _buildLanguageList(),
            ),
            _buildBottomButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final emojiSize = ResponsiveUtils.responsive(mobile: 108.0, tablet: 140.0);

    return Container(
      padding: RPadding.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _earthController,
            builder: (_, child) {
              return Transform.rotate(
                angle: _earthController.value * 2 * math.pi,
                child: Text(
                  '🌍',
                  style: TextStyle(fontSize: emojiSize),
                ),
              );
            },
          ),
          SizedBox(height: AppSizes.paddingS),
          Text(
            getTranslation(KEY_CHOOSE_LANGUAGE),
            style: TextStyle(
              fontSize: AppSizes.fontTitle,
              fontWeight: FontWeight.bold,
              color: AppColors.green,
            ),
          ),
          SizedBox(height: AppSizes.paddingS),
          Text(
            getTranslation(KEY_SELECT_PREFERRED),
            style: TextStyle(
              fontSize: AppSizes.fontL,
              color: AppColors.textGrey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageList() {
    return ListView.builder(
      padding: RPadding.symmetric(horizontal: 16, vertical: 8),
      itemCount: languages.length,
      shrinkWrap: true, // Important: Makes ListView work within Column
      physics: const BouncingScrollPhysics(), // Adds bounce effect on scroll
      itemBuilder: (context, index) {
        return _buildLanguageCard(languages[index]);
      },
    );
  }

  Widget _buildLanguageCard(LanguageData language) {
    final isSelected = selectedLanguage == language.name;
    final flagContainerSize = ResponsiveUtils.responsive(mobile: 48.0, tablet: 56.0);
    final flagFontSize = ResponsiveUtils.responsive(mobile: 24.0, tablet: 30.0);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: EdgeInsets.symmetric(vertical: AppSizes.paddingS),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _selectLanguage(language.name),
          borderRadius: BorderRadius.circular(AppSizes.radiusXL),
          child: Container(
            padding: RPadding.all(16),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.green.withOpacity(0.1) : AppColors.white,
              border: Border.all(
                color: isSelected ? AppColors.green : AppColors.borderLight,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(AppSizes.radiusXL),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? AppColors.green.withOpacity(0.1)
                      : AppColors.shadowLight,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: flagContainerSize,
                  height: flagContainerSize,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.scaffoldBackground,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    language.flagEmoji,
                    style: TextStyle(fontSize: flagFontSize),
                  ),
                ),
                SizedBox(width: AppSizes.paddingL),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        language.name,
                        style: TextStyle(
                          fontSize: AppSizes.fontL,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      SizedBox(height: AppSizes.paddingS),
                      Text(
                        language.nativeName,
                        style: TextStyle(
                          fontSize: AppSizes.fontS,
                          color: AppColors.textGrey,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Container(
                    padding: RPadding.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.green,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check,
                      color: AppColors.white,
                      size: AppSizes.iconS,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomButton() {
    return Container(
      padding: RPadding.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: AppSizes.buttonHeight,
        child: ElevatedButton(
          onPressed: selectedLanguage != null
              ? () async {
                  final languageService = await LanguageService.getInstance();
                  await languageService.saveLanguage(selectedLanguage!);

                  // Use the translation manager to notify other screens
                  await TranslationManager.instance
                      .changeLanguage(selectedLanguage!);

                  if (mounted) {
                    Get.offAllNamed(AppRoutes.PHONE_NUMBER);
                  }
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.green,
            foregroundColor: AppColors.white,
            padding: RPadding.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusXL),
            ),
            elevation: selectedLanguage != null ? 4 : 0,
          ),
          child: Text(
            selectedLanguage != null
                ? getTranslation(KEY_CONTINUE)
                : getTranslation(KEY_SELECT_LANGUAGE),
            style: TextStyle(
              fontSize: AppSizes.fontL,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  void _selectLanguage(String language) async {
    setState(() {
      selectedLanguage = language;
    });

    // Update translations when language changes
    await updateTranslations();
  }
}
