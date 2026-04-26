import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../data/models/farm_profile.dart';
import '../../../controllers/farm_profile_controller.dart';
import '../onboarding_ui.dart';

class OnboardingFarmStep extends StatefulWidget {
  const OnboardingFarmStep({super.key});

  @override
  State<OnboardingFarmStep> createState() => _OnboardingFarmStepState();
}

class _OnboardingFarmStepState extends State<OnboardingFarmStep> {
  final _formKey = GlobalKey<FormState>();
  late final FarmProfileController _c;
  final _areaCtrl = TextEditingController();
  final _expCtrl = TextEditingController();
  String _areaUnit = 'acre';
  String? _ownership;
  List<String> _soils = const [];
  List<String> _irrigation = const [];

  @override
  void initState() {
    super.initState();
    _c = Get.find<FarmProfileController>();
    final d = _c.draft.value;
    _areaCtrl.text = d.totalArea?.toString() ?? '';
    _areaUnit = d.totalAreaUnit;
    _expCtrl.text = d.experienceYears > 0 ? d.experienceYears.toString() : '';
    _ownership = d.ownership;
    _soils = [...d.soilTypes];
    _irrigation = [...d.irrigationSources];
  }

  @override
  void dispose() {
    _areaCtrl.dispose();
    _expCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _c.updateDraft((c) => c.copyWith(
          totalArea: double.tryParse(_areaCtrl.text.trim()),
          totalAreaUnit: _areaUnit,
          ownership: _ownership,
          soilTypes: _soils,
          irrigationSources: _irrigation,
          experienceYears: int.tryParse(_expCtrl.text.trim()) ?? 0,
        ));
    _c.nextStep();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const OnboardingSectionTitle(
            title: 'Your farm',
            subtitle: 'Gives the AI context for area-scaled recommendations.',
          ),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _areaCtrl,
                  keyboardType: TextInputType.number,
                  decoration: onboardingInput('Total area'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final n = double.tryParse(v.trim());
                    if (n == null || n < 0) return 'Enter a positive number';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _areaUnit,
                  isExpanded: true,
                  decoration: onboardingInput('Unit'),
                  items: const [
                    DropdownMenuItem(
                        value: 'acre',
                        child: Text('acre', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(
                        value: 'hectare',
                        child:
                            Text('hectare', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(
                        value: 'bigha',
                        child: Text('bigha', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(
                        value: 'gunta',
                        child: Text('gunta', overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) => setState(() => _areaUnit = v ?? 'acre'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _ownership,
            decoration: onboardingInput('Ownership (optional)'),
            items: const [
              DropdownMenuItem(value: 'owned', child: Text('Owned')),
              DropdownMenuItem(value: 'leased', child: Text('Leased')),
              DropdownMenuItem(value: 'shared', child: Text('Shared')),
              DropdownMenuItem(value: 'mixed', child: Text('Mixed')),
            ],
            onChanged: (v) => setState(() => _ownership = v),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _expCtrl,
            keyboardType: TextInputType.number,
            decoration: onboardingInput('Experience (years)'),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return null;
              final n = int.tryParse(v.trim());
              if (n == null || n < 0 || n > 100) return '0–100';
              return null;
            },
          ),
          const SizedBox(height: 24),
          const OnboardingSectionTitle(
            title: 'Soil types',
            subtitle: 'Select all that apply on your farm.',
          ),
          MultiSelectChips(
            options: const [
              'sandy', 'loam', 'clay', 'black', 'red', 'laterite', 'alluvial', 'silty'
            ],
            selected: _soils,
            onChanged: (v) => setState(() => _soils = v),
          ),
          const SizedBox(height: 24),
          const OnboardingSectionTitle(
            title: 'Irrigation sources',
            subtitle: 'Helps the AI recommend water-smart practices.',
          ),
          MultiSelectChips(
            options: const [
              'borewell', 'canal', 'river', 'pond', 'rainfed', 'drip', 'sprinkler'
            ],
            selected: _irrigation,
            onChanged: (v) => setState(() => _irrigation = v),
          ),
          const SizedBox(height: 32),
          OnboardingStepFooter(primaryLabel: 'Next', onPrimary: _next),
        ],
      ),
    );
  }
}
