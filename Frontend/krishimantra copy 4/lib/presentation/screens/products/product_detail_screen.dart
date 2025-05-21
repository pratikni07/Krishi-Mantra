import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/colors.dart';
import '../../controllers/product_controller.dart';
import '../../../core/utils/error_handler.dart';

class ProductDetailScreen extends GetView<ProductController> {
  const ProductDetailScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.faintGreen,
      appBar: AppBar(
        title: const Text('Product Details'),
        backgroundColor: AppColors.green,
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
          return const Center(child: Text('No product selected'));
        }

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.network(
                product.image,
                width: double.infinity,
                height: 250,
                fit: BoxFit.cover,
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textGrey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundImage: NetworkImage(product.company.logo),
                      ),
                      title: Text(
                        product.company.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textGrey,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Usage Instructions:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textGrey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      product.usage,
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.textGrey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Used For:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textGrey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundImage: NetworkImage(product.usedFor.imageUrl),
                      ),
                      title: Text(
                        product.usedFor.name,
                        style: const TextStyle(
                          fontSize: 16,
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