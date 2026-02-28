import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'company_details_screen.dart';
import 'widgets/company_card.dart';
import '../../controllers/company_controller.dart';
import '../../widgets/skeleton/skeleton_widgets.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../core/utils/language_helper.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/loading_state_widget.dart';
import '../../widgets/error_state_widget.dart';

class CompanyListScreen extends StatefulWidget {
  const CompanyListScreen({Key? key}) : super(key: key);

  @override
  State<CompanyListScreen> createState() => _CompanyListScreenState();
}

class _CompanyListScreenState extends State<CompanyListScreen> with TranslationMixin {
  final CompanyController controller = Get.find<CompanyController>();

  // Translation keys
  static const String KEY_FERTILIZER_COMPANIES = 'fertilizer_companies';
  static const String KEY_RETRY = 'retry';

  @override
  void initState() {
    super.initState();
    _registerTranslations();
    _initializeLanguage();
  }

  void _registerTranslations() {
    registerTranslation(KEY_FERTILIZER_COMPANIES, 'Fertilizer Companies');
    registerTranslation(KEY_RETRY, 'Retry');
  }

  Future<void> _initializeLanguage() async {
    await updateTranslations();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: Text(
          getTranslation(KEY_FERTILIZER_COMPANIES),
          style: TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
            fontSize: AppSizes.fontL,
          ),
        ),
        backgroundColor: AppColors.green,
        iconTheme: IconThemeData(color: AppColors.white, size: AppSizes.iconM),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppColors.white, size: AppSizes.iconM),
            onPressed: () => controller.fetchAllCompanies(refresh: true),
          ),
          IconButton(
            icon: Icon(Icons.search, color: AppColors.white, size: AppSizes.iconM),
            onPressed: () {
              // TODO: Implement search functionality
            },
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const LoadingStateWidget(
            message: 'Loading fertilizer companies...',
          );
        }

        if (controller.error.isNotEmpty) {
          return const ErrorStateWidget(
            title: 'Unable to Load Companies',
            subtitle: 'The tractor is having trouble reaching the companies. Please try again! 🚜',
          );
        }

        if (controller.companies.isEmpty) {
          return EmptyStateWidget(
            title: 'No Companies Found',
            subtitle: 'The tractor is on its way to bring you the best fertilizer companies! 🚜',
          );
        }

        return RefreshIndicator(
          onRefresh: () => controller.fetchAllCompanies(refresh: true),
          child: Padding(
            padding: RPadding.all(8),
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: ResponsiveUtils.gridCrossAxisCount,
                childAspectRatio: 0.8,
                crossAxisSpacing: AppSizes.paddingM,
                mainAxisSpacing: AppSizes.paddingM,
              ),
              itemCount: controller.companies.length,
              itemBuilder: (context, index) {
                final company = controller.companies[index];
                return CompanyCard(
                  company: company,
                  onTap: () => Get.to(
                    () => CompanyDetailScreen(companyId: company.id),
                  ),
                );
              },
            ),
          ),
        );
      }),
    );
  }
}
