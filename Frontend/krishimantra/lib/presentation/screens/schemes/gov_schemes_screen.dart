// gov_schemes_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/language_helper.dart';
import '../../../data/models/scheme_model.dart';
import '../../../data/services/language_service.dart';
import '../../controllers/scheme_controller.dart';
import '../../widgets/skeleton/skeleton_widgets.dart';
import '../../../core/utils/error_handler.dart';

class GovSchemesScreen extends StatefulWidget {
  const GovSchemesScreen({Key? key}) : super(key: key);

  @override
  State<GovSchemesScreen> createState() => _GovSchemesScreenState();
}

class _GovSchemesScreenState extends State<GovSchemesScreen>
    with TranslationMixin {
  final SchemeController controller = Get.find<SchemeController>();
  final TextEditingController searchController = TextEditingController();
  final RxString selectedCategory = 'All'.obs;

  // Translation keys
  static const String KEY_TITLE = 'gov_schemes_title';
  static const String KEY_SEARCH = 'search_schemes';
  static const String KEY_ALL = 'all_category';
  static const String KEY_LAST_DATE = 'last_date';
  static const String KEY_VIEW_DETAILS = 'view_details';
  static const String KEY_DESCRIPTION = 'description';
  static const String KEY_ELIGIBILITY = 'eligibility';
  static const String KEY_BENEFITS = 'benefits';
  static const String KEY_DOCUMENTS = 'required_documents';
  static const String KEY_APPLY_NOW = 'apply_now';
  static const String KEY_SAVE_LATER = 'save_later';
  static const String KEY_NEED_HELP = 'need_help';
  static const String KEY_GOT_IT = 'got_it';
  static const String KEY_SEARCH_SCHEMES_HELP = 'search_schemes_help';
  static const String KEY_FILTER_CATEGORY = 'filter_category';
  static const String KEY_TAP_VIEW = 'tap_view';

  String _translatedAll = 'All';

  @override
  void initState() {
    super.initState();
    _registerTranslations();
    _translateAllCategory();
  }

  void _registerTranslations() {
    registerTranslation(KEY_TITLE, 'Government Schemes');
    registerTranslation(KEY_SEARCH, 'Search schemes...');
    registerTranslation(KEY_ALL, 'All');
    registerTranslation(KEY_LAST_DATE, 'Last Date');
    registerTranslation(KEY_VIEW_DETAILS, 'View Details');
    registerTranslation(KEY_DESCRIPTION, 'Description');
    registerTranslation(KEY_ELIGIBILITY, 'Eligibility');
    registerTranslation(KEY_BENEFITS, 'Benefits');
    registerTranslation(KEY_DOCUMENTS, 'Required Documents');
    registerTranslation(KEY_APPLY_NOW, 'Apply Now');
    registerTranslation(KEY_SAVE_LATER, 'Save for Later');
    registerTranslation(KEY_NEED_HELP, 'Need Help?');
    registerTranslation(KEY_GOT_IT, 'Got it');
    registerTranslation(KEY_SEARCH_SCHEMES_HELP,
        'Use the search bar to find specific schemes');
    registerTranslation(
        KEY_FILTER_CATEGORY, 'Use category chips to filter schemes by type');
    registerTranslation(
        KEY_TAP_VIEW, 'Tap on any scheme to see full details and apply');
  }

  Future<void> _translateAllCategory() async {
    final languageService = await LanguageService.getInstance();
    _translatedAll = await languageService.translate('All');
    selectedCategory.value = _translatedAll;
    if (mounted) setState(() {});
  }

  List<String> get categories {
    final Set<String> cats =
        controller.displaySchemes.map((s) => s.category).toSet();
    return [_translatedAll, ...cats];
  }

  List<SchemeModel> _getFilteredSchemes(
      String searchText, String selectedCat) {
    return controller.displaySchemes.where((scheme) {
      final matchesCategory =
          selectedCat == _translatedAll || scheme.category == selectedCat;
      final matchesSearch =
          scheme.title.toLowerCase().contains(searchText.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    // Responsive calculations
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    // Dynamic sizes
    final titleFontSize = isSmallScreen ? 16.0 : 18.0;
    final fabSize = isSmallScreen ? 48.0 : 56.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          getTranslation(KEY_TITLE),
          style: TextStyle(
            color: AppColors.white,
            fontSize: titleFontSize,
          ),
        ),
        backgroundColor: AppColors.green,
        iconTheme: const IconThemeData(color: AppColors.white),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.refresh,
              color: AppColors.white,
            ),
            onPressed: () => controller.fetchAllSchemes(refresh: true),
          ),
          IconButton(
            icon: const Icon(
              Icons.notifications,
              color: AppColors.white,
            ),
            onPressed: () {
              // TODO: Implement notifications
            },
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return ListView.builder(
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 5,
            itemBuilder: (context, index) {
              return const SkeletonSchemeListItem();
            },
          );
        }

        if (controller.error.isNotEmpty) {
          return _buildErrorWidget();
        }

        return Column(
          children: [
            _buildSearchBar(context, searchController),
            _buildCategoryFilter(context, selectedCategory),
            Expanded(
              child: Obx(() {
                final filteredSchemes = _getFilteredSchemes(
                  searchController.text,
                  selectedCategory.value,
                );
                return _buildSchemesList(context, filteredSchemes);
              }),
            ),
          ],
        );
      }),
      floatingActionButton: SizedBox(
        width: fabSize,
        height: fabSize,
        child: FloatingActionButton(
          onPressed: () => _showHelpDialog(context),
          backgroundColor: AppColors.green,
          child: Icon(
            Icons.help_outline,
            size: isSmallScreen ? 22 : 26,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return ErrorHandler.getErrorWidget(
      errorType: ErrorType.unknown,
      onRetry: () => controller.fetchAllSchemes(refresh: true),
      showRetry: true,
    );
  }

  Widget _buildSearchBar(
      BuildContext context, TextEditingController searchCtrl) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    // Responsive padding and sizing
    final horizontalPadding = (screenWidth * 0.04).clamp(12.0, 20.0);
    final verticalPadding = isSmallScreen ? 10.0 : 16.0;
    final fontSize = isSmallScreen ? 14.0 : 16.0;
    final iconSize = isSmallScreen ? 20.0 : 24.0;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      child: TextField(
        controller: searchCtrl,
        style: TextStyle(fontSize: fontSize),
        decoration: InputDecoration(
          hintText: getTranslation(KEY_SEARCH),
          hintStyle: TextStyle(fontSize: fontSize),
          prefixIcon: Icon(Icons.search, size: iconSize),
          contentPadding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 12 : 16,
            vertical: isSmallScreen ? 12 : 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          filled: true,
          fillColor: AppColors.faintGreen,
        ),
        onChanged: (value) {
          setState(() {});
        },
      ),
    );
  }

  Widget _buildCategoryFilter(BuildContext context, RxString selectedCat) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 360;

    // Responsive sizing
    final chipHeight = (screenHeight * 0.055).clamp(40.0, 50.0);
    final horizontalPadding = (screenWidth * 0.04).clamp(12.0, 20.0);
    final chipFontSize = isSmallScreen ? 12.0 : 14.0;
    final chipSpacing = isSmallScreen ? 6.0 : 8.0;

    return SizedBox(
      height: chipHeight,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        children: categories.map((category) {
          return Obx(() {
            final isSelected = category == selectedCat.value;
            return Padding(
              padding: EdgeInsets.only(right: chipSpacing),
              child: FilterChip(
                label: Text(
                  category,
                  style: TextStyle(fontSize: chipFontSize),
                ),
                selected: isSelected,
                onSelected: (selected) => selectedCat.value = category,
                backgroundColor: AppColors.faintGreen,
                selectedColor: AppColors.green.withOpacity(0.2),
                labelStyle: TextStyle(
                  color: isSelected ? AppColors.green : AppColors.textGrey,
                  fontSize: chipFontSize,
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 8 : 12,
                  vertical: isSmallScreen ? 4 : 6,
                ),
              ),
            );
          });
        }).toList(),
      ),
    );
  }

  Widget _buildSchemesList(BuildContext context, List<SchemeModel> schemes) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    // Responsive sizing
    final horizontalPadding = (screenWidth * 0.04).clamp(12.0, 20.0);
    final cardPadding = isSmallScreen ? 12.0 : 16.0;
    final cardMargin = isSmallScreen ? 10.0 : 16.0;
    final titleFontSize = isSmallScreen ? 15.0 : 18.0;
    final descFontSize = isSmallScreen ? 13.0 : 14.0;
    final categoryFontSize = isSmallScreen ? 10.0 : 12.0;
    final dateFontSize = isSmallScreen ? 12.0 : 14.0;
    final buttonFontSize = isSmallScreen ? 12.0 : 14.0;
    final iconSize = isSmallScreen ? 14.0 : 16.0;
    final spacingSmall = isSmallScreen ? 6.0 : 8.0;
    final spacingMedium = isSmallScreen ? 8.0 : 12.0;

    return ListView.builder(
      padding: EdgeInsets.all(horizontalPadding),
      itemCount: schemes.length,
      itemBuilder: (context, index) {
        final scheme = schemes[index];
        return Card(
          margin: EdgeInsets.only(bottom: cardMargin),
          elevation: 2,
          child: InkWell(
            onTap: () => _showSchemeDetails(context, scheme),
            child: Padding(
              padding: EdgeInsets.all(cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          scheme.title,
                          style: TextStyle(
                            fontSize: titleFontSize,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(width: spacingSmall),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 6 : 8,
                          vertical: isSmallScreen ? 3 : 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          scheme.category,
                          style: TextStyle(
                            color: AppColors.green,
                            fontSize: categoryFontSize,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: spacingSmall),
                  Text(
                    scheme.description,
                    style: TextStyle(
                      color: AppColors.textGrey,
                      fontSize: descFontSize,
                    ),
                    maxLines: isSmallScreen ? 2 : 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: spacingMedium),
                  // Responsive layout for date and button
                  isSmallScreen
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.calendar_today,
                                    size: iconSize, color: AppColors.textGrey),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    '${getTranslation(KEY_LAST_DATE)}: ${scheme.lastDate}',
                                    style: TextStyle(
                                      color: AppColors.textGrey,
                                      fontSize: dateFontSize,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: spacingSmall),
                            SizedBox(
                              width: double.infinity,
                              child: TextButton(
                                onPressed: () =>
                                    _showSchemeDetails(context, scheme),
                                style: TextButton.styleFrom(
                                  backgroundColor: AppColors.green,
                                  foregroundColor: AppColors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                ),
                                child: Text(
                                  getTranslation(KEY_VIEW_DETAILS),
                                  style: TextStyle(fontSize: buttonFontSize),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Icon(Icons.calendar_today,
                                size: iconSize, color: AppColors.textGrey),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '${getTranslation(KEY_LAST_DATE)}: ${scheme.lastDate}',
                                style: TextStyle(
                                  color: AppColors.textGrey,
                                  fontSize: dateFontSize,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () =>
                                  _showSchemeDetails(context, scheme),
                              style: TextButton.styleFrom(
                                backgroundColor: AppColors.green,
                                foregroundColor: AppColors.white,
                              ),
                              child: Text(
                                getTranslation(KEY_VIEW_DETAILS),
                                style: TextStyle(fontSize: buttonFontSize),
                              ),
                            ),
                          ],
                        ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showSchemeDetails(BuildContext context, SchemeModel scheme) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    // Responsive sizing for bottom sheet
    final sheetPadding = isSmallScreen ? 16.0 : 24.0;
    final titleFontSize = isSmallScreen ? 20.0 : 24.0;
    final buttonHeight = isSmallScreen ? 44.0 : 50.0;
    final buttonFontSize = isSmallScreen ? 14.0 : 16.0;
    final spacingMedium = isSmallScreen ? 12.0 : 16.0;
    final spacingLarge = isSmallScreen ? 18.0 : 24.0;

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
                padding: EdgeInsets.all(sheetPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: EdgeInsets.only(bottom: spacingMedium),
                        decoration: BoxDecoration(
                          color: AppColors.textGrey.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text(
                      scheme.title,
                      style: TextStyle(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: spacingMedium),
                    _buildDetailSection(context, getTranslation(KEY_DESCRIPTION),
                        scheme.description),
                    _buildDetailSection(
                      context,
                      getTranslation(KEY_ELIGIBILITY),
                      '',
                      bulletPoints: scheme.eligibility,
                    ),
                    _buildDetailSection(
                      context,
                      getTranslation(KEY_BENEFITS),
                      '',
                      bulletPoints: scheme.benefits,
                    ),
                    _buildDetailSection(
                      context,
                      getTranslation(KEY_DOCUMENTS),
                      '',
                      bulletPoints: scheme.documentRequired,
                    ),
                    SizedBox(height: spacingLarge),
                    ElevatedButton(
                      onPressed: () {
                        // TODO: Implement application process
                        // Launch URL: scheme.applicationUrl
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.green,
                        minimumSize: Size(double.infinity, buttonHeight),
                      ),
                      child: Text(
                        getTranslation(KEY_APPLY_NOW),
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: buttonFontSize,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    SizedBox(height: spacingMedium),
                    OutlinedButton(
                      onPressed: () {
                        // TODO: Implement save functionality
                      },
                      style: OutlinedButton.styleFrom(
                        minimumSize: Size(double.infinity, buttonHeight),
                      ),
                      child: Text(
                        getTranslation(KEY_SAVE_LATER),
                        style: TextStyle(
                          color: AppColors.green,
                          fontSize: buttonFontSize,
                        ),
                      ),
                    ),
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

  Widget _buildDetailSection(BuildContext context, String title, String content,
      {List<String>? bulletPoints}) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    final sectionTitleSize = isSmallScreen ? 16.0 : 18.0;
    final contentFontSize = isSmallScreen ? 13.0 : 14.0;
    final bulletFontSize = isSmallScreen ? 14.0 : 16.0;
    final spacingSmall = isSmallScreen ? 6.0 : 8.0;
    final bottomPadding = isSmallScreen ? 18.0 : 24.0;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: sectionTitleSize,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: spacingSmall),
          if (content.isNotEmpty)
            Text(
              content,
              style: TextStyle(fontSize: contentFontSize),
            ),
          if (bulletPoints != null) ...[
            SizedBox(height: spacingSmall),
            ...bulletPoints.map((point) => Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('• ', style: TextStyle(fontSize: bulletFontSize)),
                      Expanded(
                        child: Text(
                          point,
                          style: TextStyle(fontSize: contentFontSize),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    final titleFontSize = isSmallScreen ? 18.0 : 20.0;

    Get.dialog(
      AlertDialog(
        title: Text(
          getTranslation(KEY_NEED_HELP),
          style: TextStyle(fontSize: titleFontSize),
        ),
        contentPadding: EdgeInsets.fromLTRB(
          isSmallScreen ? 16 : 24,
          isSmallScreen ? 16 : 20,
          isSmallScreen ? 16 : 24,
          0,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHelpItem(
              context,
              Icons.search,
              getTranslation(KEY_SEARCH),
              getTranslation(KEY_SEARCH_SCHEMES_HELP),
            ),
            _buildHelpItem(
              context,
              Icons.category,
              getTranslation(KEY_ALL),
              getTranslation(KEY_FILTER_CATEGORY),
            ),
            _buildHelpItem(
              context,
              Icons.touch_app,
              getTranslation(KEY_VIEW_DETAILS),
              getTranslation(KEY_TAP_VIEW),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              getTranslation(KEY_GOT_IT),
              style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem(
      BuildContext context, IconData icon, String title, String description) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    final iconSize = isSmallScreen ? 22.0 : 26.0;
    final titleFontSize = isSmallScreen ? 13.0 : 14.0;
    final descFontSize = isSmallScreen ? 11.0 : 12.0;
    final iconSpacing = isSmallScreen ? 12.0 : 16.0;
    final bottomPadding = isSmallScreen ? 12.0 : 16.0;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.green, size: iconSize),
          SizedBox(width: iconSpacing),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: titleFontSize,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    color: AppColors.textGrey,
                    fontSize: descFontSize,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
