import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../data/models/product_model.dart';
import '../../controllers/product_controller.dart';
import '../../widgets/skeleton/skeleton_widgets.dart';
import 'product_detail_screen.dart';
import '../../../core/utils/error_handler.dart';

class ProductListScreen extends GetView<ProductController> {
  const ProductListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);
    final imageHeight = ResponsiveUtils.responsive(mobile: 120.0, tablet: 160.0);

    return Scaffold(
      backgroundColor: AppColors.faintGreen,
      appBar: AppBar(
        title: Text(
          'Agricultural Products',
          style: TextStyle(fontSize: AppSizes.fontL),
        ),
        backgroundColor: AppColors.green,
        iconTheme: IconThemeData(size: AppSizes.iconM),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return GridView.builder(
            padding: RPadding.all(16),
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: ResponsiveUtils.gridCrossAxisCount,
              childAspectRatio: 0.75,
              crossAxisSpacing: AppSizes.paddingL,
              mainAxisSpacing: AppSizes.paddingL,
            ),
            itemCount: 6,
            itemBuilder: (context, index) {
              return const SkeletonProductGridItem();
            },
          );
        }

        if (controller.error.isNotEmpty) {
          return ErrorHandler.getErrorWidget(
            errorType: ErrorType.unknown,
            onRetry: () => controller.fetchAllProducts(),
            showRetry: true,
          );
        }

        return GridView.builder(
          padding: RPadding.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: ResponsiveUtils.gridCrossAxisCount,
            childAspectRatio: 0.75,
            crossAxisSpacing: AppSizes.paddingL,
            mainAxisSpacing: AppSizes.paddingL,
          ),
          itemCount: controller.products.length,
          itemBuilder: (context, index) {
            final product = controller.products[index];
            return GestureDetector(
              onTap: () {
                controller.selectedProduct.value = product;
                Get.to(() => const ProductDetailScreen());
              },
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusXL),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.radiusXL)),
                      child: Image.network(
                        product.image,
                        height: imageHeight,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Padding(
                      padding: RPadding.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            style: TextStyle(
                              fontSize: AppSizes.fontL,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textGrey,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: AppSizes.paddingS),
                          Row(
                            children: [
                              CircleAvatar(
                                radius: ResponsiveUtils.responsive(mobile: 12.0, tablet: 16.0),
                                backgroundImage: NetworkImage(product.company.logo),
                              ),
                              SizedBox(width: AppSizes.paddingS),
                              Expanded(
                                child: Text(
                                  product.company.name,
                                  style: TextStyle(
                                    fontSize: AppSizes.fontS,
                                    color: AppColors.textGrey,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }),
    );
  }
} 