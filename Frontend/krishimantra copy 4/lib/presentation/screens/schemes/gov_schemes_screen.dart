// gov_schemes_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/colors.dart';
import '../../../data/models/scheme_model.dart';
import '../../controllers/scheme_controller.dart';
import '../../../core/utils/error_handler.dart';


class GovSchemesScreen extends GetView<SchemeController> {
  const GovSchemesScreen({Key? key}) : super(key: key);

  List<String> get categories {
    final Set<String> cats = controller.schemes
        .map((s) => s.category)
        .toSet();
    return ['All', ...cats];
  }

  List<SchemeModel> _getFilteredSchemes(String searchText, String selectedCategory) {
    return controller.schemes.where((scheme) {
      final matchesCategory =
          selectedCategory == 'All' || scheme.category == selectedCategory;
      final matchesSearch = scheme.title
          .toLowerCase()
          .contains(searchText.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final searchController = TextEditingController();
    final selectedCategory = 'All'.obs;

    return Scaffold(
     appBar: AppBar(
  title: const Text(
    'Government Schemes',
    style: TextStyle(color: AppColors.white), // Added white color
  ),
  backgroundColor: AppColors.green,
  iconTheme: const IconThemeData(color: AppColors.white), // Makes all icons white
  actions: [
    IconButton(
      icon: const Icon(
        Icons.refresh,
        color: AppColors.white, // Added white color
      ),
      onPressed: () => controller.fetchAllSchemes(refresh: true),
    ),
    IconButton(
      icon: const Icon(
        Icons.notifications,
        color: AppColors.white, // Added white color
      ),
      onPressed: () {
        // TODO: Implement notifications
      },
    ),
  ],
),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.error.isNotEmpty) {
          return _buildErrorWidget();
        }

        return Column(
          children: [
            _buildSearchBar(searchController),
            _buildCategoryFilter(selectedCategory),
            Expanded(
              child: Obx(() {
                final filteredSchemes = _getFilteredSchemes(
                  searchController.text,
                  selectedCategory.value,
                );
                return _buildSchemesList(filteredSchemes);
              }),
            ),
          ],
        );
      }),
      floatingActionButton: FloatingActionButton(
        onPressed: _showHelpDialog,
        backgroundColor: AppColors.green,
        child: const Icon(Icons.help_outline),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return ErrorHandler.getErrorWidget(
      errorType: ErrorType.unknown, // Since we don't have direct access to errorType
      onRetry: () => controller.fetchAllSchemes(refresh: true),
      showRetry: true,
    );
  }

  Widget _buildSearchBar(TextEditingController searchController) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: searchController,
        decoration: InputDecoration(
          hintText: 'Search schemes...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          filled: true,
          fillColor: AppColors.faintGreen,
        ),
        onChanged: (value) => searchController.text = value,
      ),
    );
  }

  Widget _buildCategoryFilter(RxString selectedCategory) {
    return Container(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: categories.map((category) {
          return Obx(() {
            final isSelected = category == selectedCategory.value;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: FilterChip(
                label: Text(category),
                selected: isSelected,
                onSelected: (selected) => selectedCategory.value = category,
                backgroundColor: AppColors.faintGreen,
                selectedColor: AppColors.green.withOpacity(0.2),
                labelStyle: TextStyle(
                  color: isSelected ? AppColors.green : AppColors.textGrey,
                ),
              ),
            );
          });
        }).toList(),
      ),
    );
  }

  Widget _buildSchemesList(List<SchemeModel> schemes) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: schemes.length,
      itemBuilder: (context, index) {
        final scheme = schemes[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 2,
          child: InkWell(
            onTap: () => _showSchemeDetails(scheme),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          scheme.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          scheme.category,
                          style: TextStyle(
                            color: AppColors.green,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    scheme.description,
                    style: TextStyle(color: AppColors.textGrey),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.calendar_today,
                          size: 16, color: AppColors.textGrey),
                      const SizedBox(width: 4),
                      Text(
                        'Last Date: ${scheme.lastDate}',
                        style: TextStyle(color: AppColors.textGrey),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => _showSchemeDetails(scheme),
                        child: const Text('View Details'),
                        style: TextButton.styleFrom(
                          backgroundColor: AppColors.green,
                          foregroundColor: AppColors.white,
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
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: AppColors.textGrey.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text(
                      scheme.title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildDetailSection('Description', scheme.description),
                    _buildDetailSection(
                      'Eligibility',
                      '',
                      bulletPoints: scheme.eligibility,
                    ),
                    _buildDetailSection(
                      'Benefits',
                      '',
                      bulletPoints: scheme.benefits,
                    ),
                    _buildDetailSection(
                      'Required Documents',
                      '',
                      bulletPoints: scheme.documentRequired,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        // TODO: Implement application process
                        // Launch URL: scheme.applicationUrl
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.green,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text(
                        'Apply Now',
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () {
                        // TODO: Implement save functionality
                      },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text('Save for Later',
                      style: TextStyle(
                        color: AppColors.green,
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

  Widget _buildDetailSection(String title, String content,
      {List<String>? bulletPoints}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (content.isNotEmpty) Text(content),
          if (bulletPoints != null) ...[
            const SizedBox(height: 8),
            ...bulletPoints.map((point) => Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(fontSize: 16)),
                      Expanded(child: Text(point)),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  void _showHelpDialog() {
    Get.dialog(
      AlertDialog(
        title: const Text('Need Help?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHelpItem(
              Icons.search,
              'Search Schemes',
              'Use the search bar to find specific schemes',
            ),
            _buildHelpItem(
              Icons.category,
              'Filter by Category',
              'Use category chips to filter schemes by type',
            ),
            _buildHelpItem(
              Icons.touch_app,
              'View Details',
              'Tap on any scheme to see full details and apply',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Icon(icon, color: AppColors.green),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  description,
                  style: TextStyle(
                    color: AppColors.textGrey,
                    fontSize: 12,
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