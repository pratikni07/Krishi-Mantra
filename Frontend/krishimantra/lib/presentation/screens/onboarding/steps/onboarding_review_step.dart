import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/constants/colors.dart';
import '../../../controllers/farm_profile_controller.dart';
import '../onboarding_ui.dart';

class OnboardingReviewStep extends StatelessWidget {
  const OnboardingReviewStep({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<FarmProfileController>();
    return Obx(() {
      final d = c.draft.value;
      final addr = d.address;
      return Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const OnboardingSectionTitle(
                  title: 'Review',
                  subtitle:
                      'Double-check your details. You can edit them later from "Edit Farm".',
                ),
                _Section(title: 'About', children: [
                  _Row('Age', d.age?.toString() ?? '—'),
                  _Row('Gender', d.gender ?? '—'),
                  _Row('Language', d.preferredLanguage),
                ]),
                _Section(title: 'Location', children: [
                  _Row(
                    'Coordinates',
                    d.latitude != null && d.longitude != null
                        ? '${d.latitude!.toStringAsFixed(3)}, ${d.longitude!.toStringAsFixed(3)}'
                        : 'Not set',
                  ),
                  _Row('Village', addr?.village ?? '—'),
                  _Row('Taluka', addr?.taluka ?? '—'),
                  _Row('District', addr?.district ?? '—'),
                  _Row('State', addr?.state ?? '—'),
                  _Row('Pincode', addr?.pincode ?? '—'),
                ]),
                _Section(title: 'Farm', children: [
                  _Row(
                    'Total area',
                    d.totalArea != null
                        ? '${d.totalArea} ${d.totalAreaUnit}'
                        : '—',
                  ),
                  _Row('Ownership', d.ownership ?? '—'),
                  _Row(
                    'Soils',
                    d.soilTypes.isEmpty ? '—' : d.soilTypes.join(', '),
                  ),
                  _Row(
                    'Irrigation',
                    d.irrigationSources.isEmpty
                        ? '—'
                        : d.irrigationSources.join(', '),
                  ),
                  _Row(
                    'Experience',
                    d.experienceYears > 0 ? '${d.experienceYears} years' : '—',
                  ),
                ]),
                _Section(
                  title: 'Crops (${d.crops.length})',
                  children: d.crops.isEmpty
                      ? [const _Row('Crops', 'None added')]
                      : d.crops.map((c) {
                          final days =
                              DateTime.now().difference(c.sowingDate).inDays;
                          return _Row(
                            c.cropName,
                            '${c.area} ${c.areaUnit} · ${c.growthStage} · sown $days days ago',
                          );
                        }).toList(),
                ),
                Obx(() {
                  final err = c.errorMessage.value;
                  if (err.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      err,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  );
                }),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Obx(() => OnboardingStepFooter(
                  primaryLabel: 'Submit',
                  isSaving: c.isSaving.value,
                  onPrimary: () async {
                    final ok = await c.submitOnboarding();
                    if (!ok) return;
                    if (Get.context != null) {
                      ScaffoldMessenger.of(Get.context!).showSnackBar(
                        const SnackBar(
                          content: Text('Farm profile saved. AI now personalised.'),
                        ),
                      );
                    }
                    Get.back<void>(result: true);
                  },
                )),
          ),
        ],
      );
    });
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textLight, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
