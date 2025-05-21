import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'company_details_screen.dart';
import 'widgets/company_card.dart';
import '../../controllers/company_controller.dart';
import '../../../core/constants/colors.dart';


class CompanyListScreen extends GetView<CompanyController> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Fertilizer Companies',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.green,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: () => controller.fetchAllCompanies(refresh: true),
          ),
          IconButton(
            icon: Icon(Icons.search, color: Colors.white),
            onPressed: () {
              // TODO: Implement search functionality
            },
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
                  onPressed: () => controller.fetchAllCompanies(refresh: true),
                  child: Text('Retry'),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => controller.fetchAllCompanies(refresh: true),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.8,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
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
