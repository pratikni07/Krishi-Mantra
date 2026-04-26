import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/colors.dart';
import '../../../data/models/farm_profile.dart';
import '../../../data/repositories/farm_profile_repository.dart';
import '../../controllers/farm_profile_controller.dart';
import 'onboarding_ui.dart';
import 'steps/onboarding_crops_step.dart';

/// Post-onboarding edit screen. Three tabs (Basics, Farm, Crops) that commit
/// every change directly into the controller's draft, then a single SAVE
/// in the AppBar pushes everything to the server via the partial-update
/// endpoint. Crops are added/edited inline through the same bottom-sheet
/// editor used during onboarding, but here each save also persists to the
/// server immediately so the user doesn't lose data on accidental exit.
class EditFarmScreen extends StatefulWidget {
  const EditFarmScreen({super.key});

  @override
  State<EditFarmScreen> createState() => _EditFarmScreenState();
}

class _EditFarmScreenState extends State<EditFarmScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  late final FarmProfileController _c;
  final _saving = false.obs;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _c = Get.find<FarmProfileController>();
    _c.loadFromServer();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final repo = Get.find<FarmProfileRepository>();
    _saving.value = true;
    try {
      await repo.patchProfile(_c.draft.value.toServerPayload());
      Get.snackbar(
        'Saved',
        'Your farm details have been updated.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.green,
        colorText: AppColors.white,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: AppColors.white,
      );
    } finally {
      _saving.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.green,
        foregroundColor: AppColors.white,
        title: const Text('Edit Farm Profile'),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AppColors.white,
          labelColor: AppColors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Basics'),
            Tab(text: 'Farm'),
            Tab(text: 'Crops'),
          ],
        ),
        actions: [
          Obx(() {
            final busy = _saving.value || _c.isSaving.value;
            return busy
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    ),
                  )
                : TextButton(
                    onPressed: _save,
                    child: const Text(
                      'SAVE',
                      style: TextStyle(color: AppColors.white),
                    ),
                  );
          }),
        ],
      ),
      body: Obx(() {
        if (_c.isLoading.value && _c.profile.value == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return TabBarView(
          controller: _tab,
          children: const [
            _BasicsTabBody(),
            _FarmTabBody(),
            _CropsTabBody(),
          ],
        );
      }),
    );
  }
}

// ============================================================================
// Basics tab
// ============================================================================

class _BasicsTabBody extends StatefulWidget {
  const _BasicsTabBody();
  @override
  State<_BasicsTabBody> createState() => _BasicsTabBodyState();
}

class _BasicsTabBodyState extends State<_BasicsTabBody> {
  late final FarmProfileController _c;
  final _ageCtrl = TextEditingController();
  final _villageCtrl = TextEditingController();
  final _talukaCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _c = Get.find<FarmProfileController>();
    final d = _c.draft.value;
    _ageCtrl.text = d.age?.toString() ?? '';
    _villageCtrl.text = d.address?.village ?? '';
    _talukaCtrl.text = d.address?.taluka ?? '';
    _districtCtrl.text = d.address?.district ?? '';
    _stateCtrl.text = d.address?.state ?? '';
    _pincodeCtrl.text = d.address?.pincode ?? '';
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ageCtrl.dispose();
    _villageCtrl.dispose();
    _talukaCtrl.dispose();
    _districtCtrl.dispose();
    _stateCtrl.dispose();
    _pincodeCtrl.dispose();
    super.dispose();
  }

  void _commitDebounced() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      _c.updateDraft(
        (c) => c.copyWith(
          age: int.tryParse(_ageCtrl.text.trim()),
          address: (c.address ?? const FarmAddress()).copyWith(
            village: _villageCtrl.text.trim().isEmpty ? null : _villageCtrl.text.trim(),
            taluka: _talukaCtrl.text.trim().isEmpty ? null : _talukaCtrl.text.trim(),
            district: _districtCtrl.text.trim().isEmpty ? null : _districtCtrl.text.trim(),
            state: _stateCtrl.text.trim().isEmpty ? null : _stateCtrl.text.trim(),
            pincode: _pincodeCtrl.text.trim().isEmpty ? null : _pincodeCtrl.text.trim(),
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const OnboardingSectionTitle(title: 'About you'),
        TextField(
          controller: _ageCtrl,
          keyboardType: TextInputType.number,
          decoration: onboardingInput('Age (optional)'),
          onChanged: (_) => _commitDebounced(),
        ),
        const SizedBox(height: 12),
        Obx(() => DropdownButtonFormField<String>(
              value: _c.draft.value.gender,
              decoration: onboardingInput('Gender (optional)'),
              items: const [
                DropdownMenuItem(value: 'male', child: Text('Male')),
                DropdownMenuItem(value: 'female', child: Text('Female')),
                DropdownMenuItem(value: 'other', child: Text('Other')),
                DropdownMenuItem(
                    value: 'prefer_not_to_say', child: Text('Prefer not to say')),
              ],
              onChanged: (v) =>
                  _c.updateDraft((c) => c.copyWith(gender: v)),
            )),
        const SizedBox(height: 24),
        const OnboardingSectionTitle(
          title: 'Location',
          subtitle: 'GPS coordinates power weather + regional advice.',
        ),
        Obx(() {
          final d = _c.draft.value;
          final has = d.latitude != null && d.longitude != null;
          return Card(
            child: ListTile(
              leading: Icon(
                has ? Icons.check_circle : Icons.location_off,
                color: has ? AppColors.green : Colors.grey,
              ),
              title: Text(has
                  ? '${d.latitude!.toStringAsFixed(3)}, ${d.longitude!.toStringAsFixed(3)}'
                  : 'No location set'),
              subtitle: const Text('Use the onboarding screen to refresh GPS.'),
            ),
          );
        }),
        const SizedBox(height: 16),
        TextField(
          controller: _villageCtrl,
          decoration: onboardingInput('Village'),
          onChanged: (_) => _commitDebounced(),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _talukaCtrl,
              decoration: onboardingInput('Taluka'),
              onChanged: (_) => _commitDebounced(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _districtCtrl,
              decoration: onboardingInput('District'),
              onChanged: (_) => _commitDebounced(),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _stateCtrl,
              decoration: onboardingInput('State'),
              onChanged: (_) => _commitDebounced(),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 140,
            child: TextField(
              controller: _pincodeCtrl,
              keyboardType: TextInputType.number,
              decoration: onboardingInput('Pincode'),
              onChanged: (_) => _commitDebounced(),
            ),
          ),
        ]),
      ],
    );
  }
}

// ============================================================================
// Farm tab
// ============================================================================

class _FarmTabBody extends StatefulWidget {
  const _FarmTabBody();
  @override
  State<_FarmTabBody> createState() => _FarmTabBodyState();
}

class _FarmTabBodyState extends State<_FarmTabBody> {
  late final FarmProfileController _c;
  final _areaCtrl = TextEditingController();
  final _expCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _c = Get.find<FarmProfileController>();
    final d = _c.draft.value;
    _areaCtrl.text = d.totalArea?.toString() ?? '';
    _expCtrl.text = d.experienceYears > 0 ? d.experienceYears.toString() : '';
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _areaCtrl.dispose();
    _expCtrl.dispose();
    super.dispose();
  }

  void _commitDebounced() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      _c.updateDraft((c) => c.copyWith(
            totalArea: double.tryParse(_areaCtrl.text.trim()),
            experienceYears: int.tryParse(_expCtrl.text.trim()) ?? 0,
          ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const OnboardingSectionTitle(title: 'Your farm'),
        Row(children: [
          Expanded(
            flex: 2,
            child: TextField(
              controller: _areaCtrl,
              keyboardType: TextInputType.number,
              decoration: onboardingInput('Total area'),
              onChanged: (_) => _commitDebounced(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Obx(() => DropdownButtonFormField<String>(
                  value: _c.draft.value.totalAreaUnit,
                  decoration: onboardingInput('Unit'),
                  items: const [
                    DropdownMenuItem(value: 'acre', child: Text('acre')),
                    DropdownMenuItem(value: 'hectare', child: Text('hectare')),
                    DropdownMenuItem(value: 'bigha', child: Text('bigha')),
                    DropdownMenuItem(value: 'gunta', child: Text('gunta')),
                  ],
                  onChanged: (v) => _c.updateDraft(
                      (c) => c.copyWith(totalAreaUnit: v ?? 'acre')),
                )),
          ),
        ]),
        const SizedBox(height: 16),
        Obx(() => DropdownButtonFormField<String>(
              value: _c.draft.value.ownership,
              decoration: onboardingInput('Ownership'),
              items: const [
                DropdownMenuItem(value: 'owned', child: Text('Owned')),
                DropdownMenuItem(value: 'leased', child: Text('Leased')),
                DropdownMenuItem(value: 'shared', child: Text('Shared')),
                DropdownMenuItem(value: 'mixed', child: Text('Mixed')),
              ],
              onChanged: (v) =>
                  _c.updateDraft((c) => c.copyWith(ownership: v)),
            )),
        const SizedBox(height: 16),
        TextField(
          controller: _expCtrl,
          keyboardType: TextInputType.number,
          decoration: onboardingInput('Experience (years)'),
          onChanged: (_) => _commitDebounced(),
        ),
        const SizedBox(height: 24),
        const OnboardingSectionTitle(title: 'Soil types'),
        Obx(() => MultiSelectChips(
              options: const [
                'sandy', 'loam', 'clay', 'black', 'red', 'laterite', 'alluvial', 'silty'
              ],
              selected: _c.draft.value.soilTypes,
              onChanged: (v) =>
                  _c.updateDraft((c) => c.copyWith(soilTypes: v)),
            )),
        const SizedBox(height: 24),
        const OnboardingSectionTitle(title: 'Irrigation sources'),
        Obx(() => MultiSelectChips(
              options: const [
                'borewell', 'canal', 'river', 'pond', 'rainfed', 'drip', 'sprinkler'
              ],
              selected: _c.draft.value.irrigationSources,
              onChanged: (v) =>
                  _c.updateDraft((c) => c.copyWith(irrigationSources: v)),
            )),
        const SizedBox(height: 32),
      ],
    );
  }
}

// ============================================================================
// Crops tab — reuses the onboarding crops step verbatim. Onboarding's "Next"
// footer is harmless here (it triggers controller.nextStep but EditFarm
// ignores the step counter), but to keep the UX clean we surface the same
// crop list and editor without a Next-button shim.
// ============================================================================

class _CropsTabBody extends StatelessWidget {
  const _CropsTabBody();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const OnboardingCropsStep(),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.scaffoldBackground.withOpacity(0.95),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.info_outline,
                      size: 14, color: AppColors.textLight),
                  SizedBox(width: 6),
                  Text(
                    'Tap SAVE in the top bar to apply changes',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textLight,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
