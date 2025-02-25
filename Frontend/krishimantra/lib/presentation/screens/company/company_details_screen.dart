import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/company_controller.dart';
import 'widgets/company_header.dart';
import 'widgets/contact_info.dart';

// import 'widgets/;
import 'widgets/reviews_section.dart';
import 'widgets/products_section.dart';

class CompanyDetailScreen extends GetView<CompanyController> {
  final String companyId;

  const CompanyDetailScreen({Key? key, required this.companyId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Fetch company details when screen is loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.fetchCompanyDetails(companyId);
    });

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[800],
        title: Text(
          'Company Details',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () => controller.fetchCompanyDetails(companyId),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return Center(child: CircularProgressIndicator());
        }

        if (controller.error.isNotEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(controller.error.value),
                ElevatedButton(
                  onPressed: () => controller.fetchCompanyDetails(companyId),
                  child: Text('Retry'),
                ),
              ],
            ),
          );
        }

        final company = controller.selectedCompany.value;
        if (company == null) return SizedBox.shrink();

        return RefreshIndicator(
          onRefresh: () => controller.fetchCompanyDetails(companyId),
          child: SingleChildScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  CompanyHeader(company: company),
                  // CompanyHeader(company: company),
                  SizedBox(height: 24),
                  ContactInfo(company: company),
                  SizedBox(height: 24),
                  ReviewsSection(company: company),
                  SizedBox(height: 24),
                  ProductsSection(company: company),
                  SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}