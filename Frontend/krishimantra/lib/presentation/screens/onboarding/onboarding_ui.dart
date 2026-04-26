import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/colors.dart';
import '../../controllers/farm_profile_controller.dart';

/// Shared visual primitives for onboarding steps. Kept in one file so the
/// steps themselves stay focused on data flow.

InputDecoration onboardingInput(String label, {String? hint, Widget? suffix}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    isDense: true,
    filled: true,
    fillColor: AppColors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.green, width: 2),
    ),
    suffixIcon: suffix,
  );
}

class OnboardingSectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  const OnboardingSectionTitle({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textLight,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class OnboardingStepFooter extends StatelessWidget {
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final bool isLast;
  final bool isSaving;

  const OnboardingStepFooter({
    super.key,
    required this.primaryLabel,
    required this.onPrimary,
    this.isLast = false,
    this.isSaving = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = Get.find<FarmProfileController>();
    return Row(
      children: [
        Obx(() {
          final canGoBack = c.currentStep.value > 0;
          return TextButton(
            onPressed: canGoBack ? c.previousStep : null,
            child: const Text('Back'),
          );
        }),
        const Spacer(),
        ElevatedButton(
          onPressed: isSaving ? null : onPrimary,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.green,
            foregroundColor: AppColors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
          ),
          child: isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child:
                      CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(primaryLabel),
        ),
      ],
    );
  }
}

class MultiSelectChips extends StatelessWidget {
  final List<String> options;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;
  final String Function(String)? labelBuilder;

  const MultiSelectChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.labelBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final isSelected = selected.contains(opt);
        return FilterChip(
          label: Text(labelBuilder?.call(opt) ?? opt),
          selected: isSelected,
          onSelected: (_) {
            final next = [...selected];
            if (isSelected) {
              next.remove(opt);
            } else {
              next.add(opt);
            }
            onChanged(next);
          },
          selectedColor: AppColors.green.withOpacity(0.2),
          checkmarkColor: AppColors.green,
        );
      }).toList(),
    );
  }
}
