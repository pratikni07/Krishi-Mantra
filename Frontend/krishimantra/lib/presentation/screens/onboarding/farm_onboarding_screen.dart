import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/colors.dart';
import '../../controllers/farm_profile_controller.dart';
import 'steps/onboarding_basics_step.dart';
import 'steps/onboarding_crops_step.dart';
import 'steps/onboarding_farm_step.dart';
import 'steps/onboarding_review_step.dart';

/// Four-step farm onboarding. Each step is a self-contained widget that talks
/// to the shared FarmProfileController. Swipe-back is disabled — users must
/// use the in-UI back button so the controller can commit the current step.
class FarmOnboardingScreen extends StatelessWidget {
  const FarmOnboardingScreen({super.key});

  static const List<String> stepLabels = ['Basics', 'Farm', 'Crops', 'Review'];

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<FarmProfileController>();

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        appBar: AppBar(
          backgroundColor: AppColors.green,
          foregroundColor: AppColors.white,
          title: const Text('Your Farm Profile'),
          automaticallyImplyLeading: false,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Obx(() => _StepHeader(current: controller.currentStep.value)),
          ),
        ),
        body: Obx(() {
          switch (controller.currentStep.value) {
            case 0:
              return const OnboardingBasicsStep();
            case 1:
              return const OnboardingFarmStep();
            case 2:
              return const OnboardingCropsStep();
            case 3:
              return const OnboardingReviewStep();
            default:
              return const SizedBox.shrink();
          }
        }),
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  final int current;
  const _StepHeader({required this.current});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: List.generate(FarmOnboardingScreen.stepLabels.length, (i) {
          final active = i == current;
          final done = i < current;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: done || active ? AppColors.white : Colors.white38,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    FarmOnboardingScreen.stepLabels[i],
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 11,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
