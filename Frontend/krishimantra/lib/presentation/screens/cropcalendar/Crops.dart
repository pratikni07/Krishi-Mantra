import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/api_constants.dart';
import '../../../data/models/crop_model.dart';
import '../../controllers/crop_controller.dart';
import '../../widgets/cached_image.dart';
import '../../widgets/skeleton/skeleton_widgets.dart';

class CropsScreen extends StatelessWidget {
  const CropsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final CropController cropController = Get.find<CropController>();
    final TextEditingController searchController = TextEditingController();
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final topPadding = mediaQuery.padding.top;

    // Calculate appropriate height for app bar - reduced for less spacing
    final appBarHeight = screenHeight * 0.20;

    // Ensure fresh data when returning to this screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Get.isRegistered<CropController>()) {
        cropController.fetchAllCrops(refresh: false);
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildAppBar(context, searchController, cropController, appBarHeight, topPadding),
              SliverToBoxAdapter(
                child: Obx(
                  () => cropController.isLoading.value
                      ? _buildLoadingIndicator()
                      : cropController.error.value.isNotEmpty
                          ? _buildErrorWidget(cropController)
                          : cropController.searchResults.isNotEmpty
                              ? _buildCropGrid(cropController.searchResults, context)
                              : cropController.crops.isEmpty
                                  ? _buildEmptyState()
                                  : _buildCropGrid(cropController.crops, context),
                ),
              ),
            ],
          ),
          // Loading overlay when fetching calendar
          Obx(() => cropController.isLoadingCalendar.value
              ? Container(
                  color: Colors.black.withOpacity(0.5),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Loading crop calendar...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : const SizedBox.shrink()),
        ],
      ),
      // Add a floating refresh button
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.green,
        onPressed: () => cropController.fetchAllCrops(refresh: true),
        child: const Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }

  SliverAppBar _buildAppBar(
      BuildContext context, 
      TextEditingController controller, 
      CropController cropController,
      double appBarHeight,
      double topPadding) {
    return SliverAppBar(
      backgroundColor: AppColors.green,
      elevation: 0,
      pinned: true,
      expandedHeight: appBarHeight,
      collapsedHeight: kToolbarHeight + 10,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          } else {
            Get.back();
          }
        },
      ),
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate available content height
          final availableHeight = constraints.maxHeight - topPadding - 16;
          // Determine if the app bar is collapsed
          final isCollapsed = constraints.maxHeight < appBarHeight * 0.8;
          
          return FlexibleSpaceBar(
            titlePadding: EdgeInsets.zero,
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.green,
                    AppColors.green.withOpacity(0.8),
                  ],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (!isCollapsed) ... [
                        Text(
                          'Crop Calendar',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.3),
                                offset: const Offset(0, 2),
                                blurRadius: 4,
                              )
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Find the best time to grow your crops',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (availableHeight > 60) _buildSearchBar(controller, cropController),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
      ),
    );
  }

  Widget _buildSearchBar(
      TextEditingController controller, CropController cropController) {
    return Hero(
      tag: 'searchBar',
      child: Material(
        elevation: 6,
        shadowColor: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(15),
        child: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Search crops...',
            hintStyle: const TextStyle(color: AppColors.textGrey),
            prefixIcon: const Icon(Icons.search, color: AppColors.green),
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear, color: AppColors.textGrey),
              onPressed: () {
                controller.clear();
                cropController.clearSearch();
              },
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: AppColors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              cropController.searchCrops(value, '');
            } else {
              cropController.clearSearch();
            }
          },
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.8,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: 9,
        itemBuilder: (context, index) {
          return const SkeletonCropCard();
        },
      ),
    );
  }

  Widget _buildErrorWidget(CropController controller) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: AppColors.orange, size: 70),
            const SizedBox(height: 16),
            Text(
              'Error: ${controller.error.value}',
              style: const TextStyle(
                color: AppColors.textGrey,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 3,
              ),
              onPressed: () => controller.retryLastOperation(),
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: const Text(
                'Retry',
                style: TextStyle(color: AppColors.white, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/empty_crops.png', 
              height: 150,
              errorBuilder: (context, error, stackTrace) => 
                Icon(Icons.eco_outlined, color: AppColors.textGrey, size: 80),
            ),
            const SizedBox(height: 24),
            const Text(
              'No crops found',
              style: TextStyle(
                color: AppColors.textGrey,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try searching for a different crop or check again later',
              style: TextStyle(
                color: AppColors.textGrey.withOpacity(0.7),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCropGrid(RxList<CropModel> crops, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: AnimationLimiter(
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.75,
          ),
          itemCount: crops.length,
          itemBuilder: (context, index) {
            return AnimationConfiguration.staggeredGrid(
              position: index,
              duration: const Duration(milliseconds: 500),
              columnCount: 2,
              child: ScaleAnimation(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
                child: FadeInAnimation(
                  child: _buildCropCard(crops[index], context),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCropCard(CropModel crop, BuildContext context) {
    // Format the image URL properly
    String imageUrl = crop.imageUrl;
    if (imageUrl.isNotEmpty && !imageUrl.startsWith('http')) {
      imageUrl = '${ApiConstants.IMAGE_BASE_URL}/$imageUrl';
    }

    return GestureDetector(
      onTap: () {
        Get.find<CropController>().fetchCropCalendar(crop.id);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: 'crop_image_${crop.id}',
                    child: ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(20)),
                      child: CachedImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholderColor: AppColors.faintGreen,
                        errorWidget: Container(
                          color: AppColors.faintGreen,
                          child: const Icon(
                            Icons.image_not_supported,
                            color: AppColors.textGrey,
                            size: 40,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.7),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Add a season indicator if available
                  if (crop.seasons.isNotEmpty)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getSeasonColor(crop.seasons.first.type),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          crop.seasons.first.type,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FutureBuilder<String>(
                      future: crop.getTranslatedName(),
                      builder: (context, snapshot) {
                        return Text(
                          snapshot.data ?? crop.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.green,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    FutureBuilder<String>(
                      future: crop.getTranslatedScientificName(),
                      builder: (context, snapshot) {
                        return Text(
                          snapshot.data ?? crop.scientificName,
                          style: const TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: AppColors.textGrey,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.faintGreen,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: AppColors.green,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${crop.growingPeriod} days',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.green,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Color _getSeasonColor(String season) {
    switch (season.toLowerCase()) {
      case 'kharif':
        return Colors.green.shade700;
      case 'rabi':
        return Colors.orange.shade700;
      case 'zaid':
        return Colors.blue.shade700;
      default:
        return AppColors.green;
    }
  }
}
