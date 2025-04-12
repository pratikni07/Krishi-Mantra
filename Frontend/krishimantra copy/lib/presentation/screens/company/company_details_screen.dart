import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/company_controller.dart';
import 'widgets/company_header.dart';
import 'widgets/contact_info.dart';
import '../../../data/services/language_service.dart';

// import 'widgets/;
import 'widgets/reviews_section.dart';
import 'widgets/products_section.dart';

class CompanyDetailScreen extends StatefulWidget {
  final String companyId;

  const CompanyDetailScreen({Key? key, required this.companyId})
      : super(key: key);

  @override
  State<CompanyDetailScreen> createState() => _CompanyDetailScreenState();
}

class _CompanyDetailScreenState extends State<CompanyDetailScreen> {
  final CompanyController controller = Get.find<CompanyController>();
  late LanguageService _languageService;
  String companyDetailsText = "Company Details";
  String retryText = "Retry";
  bool _translationsInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.fetchCompanyDetails(widget.companyId);
    });
    _initializeTranslations();
  }

  Future<void> _initializeTranslations() async {
    _languageService = await LanguageService.getInstance();

    final translations = await Future.wait([
      _languageService.translate('Company Details'),
      _languageService.translate('Retry'),
    ]);

    if (mounted) {
      setState(() {
        companyDetailsText = translations[0];
        retryText = translations[1];
        _translationsInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[800],
        title: Text(
          companyDetailsText,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => controller.fetchCompanyDetails(widget.companyId),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.error.isNotEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(controller.error.value),
                ElevatedButton(
                  onPressed: () =>
                      controller.fetchCompanyDetails(widget.companyId),
                  child: Text(retryText),
                ),
              ],
            ),
          );
        }

        final company = controller.selectedCompany.value;
        if (company == null) return const SizedBox.shrink();

        return RefreshIndicator(
          onRefresh: () => controller.fetchCompanyDetails(widget.companyId),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  CompanyHeader(company: company),
                  const SizedBox(height: 24),
                  ContactInfo(company: company),
                  const SizedBox(height: 24),
                  ReviewsSection(company: company),
                  const SizedBox(height: 24),
                  ProductsSection(company: company),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}
