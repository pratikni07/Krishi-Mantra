import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../controllers/product_controller.dart';
import '../../../core/utils/error_handler.dart';

class ProductDetailScreen extends GetView<ProductController> {
  const ProductDetailScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);
    final imageHeight = ResponsiveUtils.responsive(mobile: 250.0, tablet: 350.0);

    return Scaffold(
      backgroundColor: AppColors.faintGreen,
      appBar: AppBar(
        title: Text(
          'Product Details',
          style: TextStyle(fontSize: AppSizes.fontL),
        ),
        backgroundColor: AppColors.green,
        iconTheme: IconThemeData(size: AppSizes.iconM),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.error.isNotEmpty) {
          return ErrorHandler.getErrorWidget(
            errorType: ErrorType.unknown,
            onRetry: () {
              if (controller.selectedProduct.value != null) {
                controller.fetchProductById(controller.selectedProduct.value!.id);
              } else {
                Get.back();
              }
            },
            showRetry: true,
          );
        }

        final product = controller.selectedProduct.value;
        if (product == null) {
          return Center(
            child: Text(
              'No product selected',
              style: TextStyle(fontSize: AppSizes.fontM),
            ),
          );
        }

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.network(
                product.image,
                width: double.infinity,
                height: imageHeight,
                fit: BoxFit.cover,
              ),
              Padding(
                padding: RPadding.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: TextStyle(
                        fontSize: AppSizes.fontTitle,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textGrey,
                      ),
                    ),
                    SizedBox(height: AppSizes.paddingL),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: ResponsiveUtils.responsive(mobile: 20.0, tablet: 28.0),
                        backgroundImage: NetworkImage(product.company.logo),
                      ),
                      title: Text(
                        product.company.name,
                        style: TextStyle(
                          fontSize: AppSizes.fontL,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textGrey,
                        ),
                      ),
                    ),
                    SizedBox(height: AppSizes.paddingL),
                    Text(
                      'Usage Instructions:',
                      style: TextStyle(
                        fontSize: AppSizes.fontL,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textGrey,
                      ),
                    ),
                    SizedBox(height: AppSizes.paddingS),
                    Text(
                      product.usage,
                      style: TextStyle(
                        fontSize: AppSizes.fontM,
                        color: AppColors.textGrey,
                      ),
                    ),
                    SizedBox(height: AppSizes.paddingL),
                    Text(
                      'Used For:',
                      style: TextStyle(
                        fontSize: AppSizes.fontL,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textGrey,
                      ),
                    ),
                    SizedBox(height: AppSizes.paddingS),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: ResponsiveUtils.responsive(mobile: 20.0, tablet: 28.0),
                        backgroundImage: NetworkImage(product.usedFor.imageUrl),
                      ),
                      title: Text(
                        product.usedFor.name,
                        style: TextStyle(
                          fontSize: AppSizes.fontM,
                          color: AppColors.textGrey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
} 