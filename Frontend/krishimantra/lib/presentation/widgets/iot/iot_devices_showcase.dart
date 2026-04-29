import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../routes/app_routes.dart';

/// Widget to showcase IoT devices for registration
class IoTDevicesShowcase extends StatelessWidget {
  const IoTDevicesShowcase({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);

    return Container(
      margin: EdgeInsets.symmetric(vertical: AppSizes.paddingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSizes.paddingL),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'IoT Devices',
                  // Use the actual app token, not the never-defined
                  // `AppColors.textPrimary` that the rest of the codebase
                  // doesn't have — that mismatch is what made this widget
                  // a colour island when first added.
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const Text(
                  'Register Now',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Device Cards
          SizedBox(
            height: 200,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: AppSizes.paddingM),
              children: [
                _buildDeviceCard(
                  context,
                  title: 'Auto Pump Starter',
                  subtitle: 'Smart Irrigation',
                  icon: '💧',
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4A90E2), Color(0xFF357ABD)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  deviceType: 'auto_pump',
                ),
                const SizedBox(width: 12),
                _buildDeviceCard(
                  context,
                  title: 'Krishi Doctor',
                  subtitle: 'Crop Health Monitor',
                  icon: '🌾',
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  deviceType: 'krishi_doctor',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String icon,
    required Gradient gradient,
    required String deviceType,
  }) {
    return GestureDetector(
      onTap: () {
        Get.toNamed(
          AppRoutes.DEVICE_REGISTRATION,
          arguments: deviceType,
        );
      },
      child: Container(
        width: 260,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          // Use the centralised shadow tokens — `withOpacity` is deprecated
          // for precision-loss reasons in the Color API.
          boxShadow: AppShadows.medium,
        ),
        child: Stack(
          children: [
            // Background pattern
            Positioned(
              right: -20,
              top: -20,
              child: Opacity(
                opacity: 0.1,
                child: Text(
                  icon,
                  style: const TextStyle(fontSize: 120),
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      icon,
                      style: const TextStyle(fontSize: 32),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Subtitle
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  const Spacer(),

                  // CTA
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 16,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Register Interest',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward,
                                size: 16,
                                color: Color(0xFF1F2937),
                              ),
                            ],
                          ),
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
  }
}
