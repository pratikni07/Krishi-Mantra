import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../presentation/controllers/background_upload_controller.dart';

class UploadStatusOverlay extends StatelessWidget {
  const UploadStatusOverlay({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // We use Get.find here because it's registered as a permanent instance in DI
    final controller = Get.find<BackgroundUploadController>();

    return Obx(() {
      // If not actively uploading and no final status to show, hide
      if (!controller.isUploading.value && 
          !controller.isSuccess.value && 
          !controller.hasError.value) {
        return const SizedBox.shrink();
      }

      final bool isFailed = controller.hasError.value;
      final bool isSuccess = controller.isSuccess.value;

      return Positioned(
        bottom: 16,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppSizes.radiusM),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: isFailed 
                    ? AppColors.error.withOpacity(0.3) 
                    : isSuccess 
                        ? AppColors.green.withOpacity(0.3) 
                        : AppColors.shimmerBase,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        controller.statusMessage.value,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: AppSizes.fontM,
                          color: isFailed ? AppColors.error : AppColors.textDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      isFailed 
                          ? Icons.error_outline 
                          : isSuccess 
                              ? Icons.check_circle_outline 
                              : Icons.cloud_upload_outlined,
                      color: isFailed 
                          ? AppColors.error 
                          : AppColors.green,
                      size: 20,
                    ),
                  ],
                ),
                if (!isSuccess && !isFailed) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppSizes.radiusS),
                    child: LinearProgressIndicator(
                      value: controller.uploadProgress.value > 0 
                          ? controller.uploadProgress.value 
                          : null,
                      backgroundColor: AppColors.shimmerBase,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.green),
                      minHeight: 6,
                    ),
                  ),
                  if (controller.uploadProgress.value > 0) ...[
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${(controller.uploadProgress.value * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: AppSizes.fontS,
                          color: AppColors.textGrey,
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      );
    });
  }
}
