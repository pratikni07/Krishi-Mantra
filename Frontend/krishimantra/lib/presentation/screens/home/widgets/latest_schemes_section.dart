import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../core/utils/language_helper.dart';
import '../../../../data/repositories/scheme_repository.dart';
import '../../../../data/models/scheme_model.dart';
import '../../../../data/services/language_service.dart';
import '../../../../routes/app_routes.dart';
import '../../../widgets/skeleton/skeleton_widgets.dart';

class LatestSchemesSection extends StatefulWidget {
  const LatestSchemesSection({super.key});

  @override
  State<LatestSchemesSection> createState() => _LatestSchemesSectionState();
}

class _LatestSchemesSectionState extends State<LatestSchemesSection>
    with TranslationMixin {
  List<SchemeModel> _schemes = [];
  bool _isLoading = true;

  // Translation keys
  static const String KEY_LATEST_SCHEMES = 'latest_schemes';
  static const String KEY_VIEW_ALL = 'view_all';
  static const String KEY_LEARN_MORE = 'learn_more';
  static const String KEY_ACTIVE = 'active';
  static const String KEY_DESCRIPTION = 'description';
  static const String KEY_ELIGIBILITY = 'eligibility';
  static const String KEY_BENEFITS = 'benefits';
  static const String KEY_DOCUMENTS = 'required_documents';
  static const String KEY_CLOSE = 'close';

  @override
  void initState() {
    super.initState();
    _registerTranslations();
    _fetchSchemes();
  }

  void _registerTranslations() {
    registerTranslation(KEY_LATEST_SCHEMES, 'Government Schemes');
    registerTranslation(KEY_VIEW_ALL, 'View All');
    registerTranslation(KEY_LEARN_MORE, 'Learn More');
    registerTranslation(KEY_ACTIVE, 'Active');
    registerTranslation(KEY_DESCRIPTION, 'Description');
    registerTranslation(KEY_ELIGIBILITY, 'Eligibility');
    registerTranslation(KEY_BENEFITS, 'Benefits');
    registerTranslation(KEY_DOCUMENTS, 'Required Documents');
    registerTranslation(KEY_CLOSE, 'Close');
  }

  Future<void> _fetchSchemes() async {
    try {
      final schemeRepository = Get.find<SchemeRepository>();
      final schemes = await schemeRepository.getAllSchemes();

      // Translate schemes
      final translatedSchemes = await _translateSchemes(schemes.take(4).toList());

      if (mounted) {
        setState(() {
          _schemes = translatedSchemes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<List<SchemeModel>> _translateSchemes(List<SchemeModel> schemes) async {
    final languageService = await LanguageService.getInstance();

    // If English, no translation needed
    if (languageService.getLanguage() == 'English') {
      return schemes;
    }

    final List<SchemeModel> translated = [];

    for (final scheme in schemes) {
      try {
        final translatedTitle = await languageService.translate(scheme.title);
        final translatedCategory = await languageService.translate(scheme.category);
        final translatedDescription = await languageService.translate(scheme.description);
        final translatedStatus = await languageService.translate(scheme.status);

        // Translate lists
        final translatedEligibility = await Future.wait(
          scheme.eligibility.map((e) => languageService.translate(e))
        );
        final translatedBenefits = await Future.wait(
          scheme.benefits.map((b) => languageService.translate(b))
        );
        final translatedDocuments = await Future.wait(
          scheme.documentRequired.map((d) => languageService.translate(d))
        );

        translated.add(SchemeModel(
          id: scheme.id,
          title: translatedTitle,
          category: translatedCategory,
          description: translatedDescription,
          eligibility: translatedEligibility,
          benefits: translatedBenefits,
          lastDate: scheme.lastDate,
          status: translatedStatus,
          applicationUrl: scheme.applicationUrl,
          documentRequired: translatedDocuments,
        ));
      } catch (e) {
        // If translation fails, use original
        translated.add(scheme);
      }
    }

    return translated;
  }

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);

    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_schemes.isEmpty) {
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
                getTranslation(KEY_LATEST_SCHEMES),
                style: TextStyle(
                  fontSize: AppSizes.fontXL,
                  fontWeight: FontWeight.bold,
                  color: AppColors.green,
                ),
              ),
              GestureDetector(
                onTap: () => Get.toNamed(AppRoutes.SCHEMES),
                child: Row(
                  children: [
                    Text(
                      getTranslation(KEY_VIEW_ALL),
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
          height: ResponsiveUtils.responsive(mobile: 160.0, tablet: 190.0),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: AppSizes.paddingL),
            itemCount: _schemes.length,
            itemBuilder: (context, index) {
              return _buildSchemeCard(_schemes[index]);
            },
          ),
        ),
      ],
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
                getTranslation(KEY_LATEST_SCHEMES),
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
          height: ResponsiveUtils.responsive(mobile: 160.0, tablet: 190.0),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: AppSizes.paddingL),
            itemCount: 3,
            itemBuilder: (context, index) {
              return const SkeletonSchemeCard();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSchemeCard(SchemeModel scheme) {
    final isActive = scheme.status.toLowerCase() == 'active';

    return GestureDetector(
      onTap: () {
        _showSchemeDetails(scheme);
      },
      child: Container(
        width: ResponsiveUtils.responsive(mobile: 260.0, tablet: 320.0),
        margin: EdgeInsets.only(right: AppSizes.paddingM),
        padding: EdgeInsets.all(AppSizes.paddingM),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppSizes.radiusL),
          border: Border.all(
            color: AppColors.green.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowLight,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with icon and status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: EdgeInsets.all(AppSizes.paddingS),
                  decoration: BoxDecoration(
                    color: AppColors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppSizes.radiusM),
                  ),
                  child: Icon(
                    Icons.account_balance_outlined,
                    color: AppColors.green,
                    size: AppSizes.iconM,
                  ),
                ),
                if (isActive)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSizes.paddingS,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppSizes.radiusS),
                      border: Border.all(
                        color: AppColors.success.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 4),
                        Text(
                          getTranslation(KEY_ACTIVE),
                          style: TextStyle(
                            fontSize: AppSizes.fontXS,
                            color: AppColors.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            SizedBox(height: AppSizes.paddingS),
            // Title
            Text(
              scheme.title,
              style: TextStyle(
                fontSize: AppSizes.fontM,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 4),
            // Category
            Text(
              scheme.category,
              style: TextStyle(
                fontSize: AppSizes.fontS,
                color: AppColors.green,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            // Learn more button
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  getTranslation(KEY_LEARN_MORE),
                  style: TextStyle(
                    fontSize: AppSizes.fontS,
                    color: AppColors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward,
                  size: AppSizes.iconS,
                  color: AppColors.green,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSchemeDetails(SchemeModel scheme) {
    Get.bottomSheet(
      DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: EdgeInsets.all(AppSizes.paddingL),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: EdgeInsets.only(bottom: AppSizes.paddingM),
                        decoration: BoxDecoration(
                          color: AppColors.textGrey.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text(
                      scheme.title,
                      style: TextStyle(
                        fontSize: AppSizes.fontXXL,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    SizedBox(height: AppSizes.paddingS),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSizes.paddingS,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppSizes.radiusS),
                      ),
                      child: Text(
                        scheme.category,
                        style: TextStyle(
                          fontSize: AppSizes.fontS,
                          color: AppColors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(height: AppSizes.paddingL),
                    _buildDetailSection(getTranslation(KEY_DESCRIPTION), scheme.description),
                    if (scheme.eligibility.isNotEmpty)
                      _buildDetailSection(
                        getTranslation(KEY_ELIGIBILITY),
                        '',
                        bulletPoints: scheme.eligibility,
                      ),
                    if (scheme.benefits.isNotEmpty)
                      _buildDetailSection(
                        getTranslation(KEY_BENEFITS),
                        '',
                        bulletPoints: scheme.benefits,
                      ),
                    if (scheme.documentRequired.isNotEmpty)
                      _buildDetailSection(
                        getTranslation(KEY_DOCUMENTS),
                        '',
                        bulletPoints: scheme.documentRequired,
                      ),
                    SizedBox(height: AppSizes.paddingL),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Get.back(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.green,
                          padding: EdgeInsets.symmetric(vertical: AppSizes.paddingM),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppSizes.radiusM),
                          ),
                        ),
                        child: Text(
                          getTranslation(KEY_CLOSE),
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: AppSizes.fontM,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: AppSizes.paddingM),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      isScrollControlled: true,
    );
  }

  Widget _buildDetailSection(String title, String content,
      {List<String>? bulletPoints}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: AppSizes.fontL,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        SizedBox(height: AppSizes.paddingS),
        if (content.isNotEmpty)
          Text(
            content,
            style: TextStyle(
              fontSize: AppSizes.fontM,
              color: AppColors.textGrey,
              height: 1.5,
            ),
          ),
        if (bulletPoints != null && bulletPoints.isNotEmpty)
          ...bulletPoints.map((point) => Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• ',
                      style: TextStyle(
                        fontSize: AppSizes.fontM,
                        color: AppColors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        point,
                        style: TextStyle(
                          fontSize: AppSizes.fontM,
                          color: AppColors.textGrey,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        SizedBox(height: AppSizes.paddingM),
      ],
    );
  }
}
