import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/constants/colors.dart';
import '../../../../data/models/farm_profile.dart';
import '../../../controllers/farm_profile_controller.dart';
import '../onboarding_ui.dart';

class OnboardingCropsStep extends StatefulWidget {
  const OnboardingCropsStep({super.key});

  @override
  State<OnboardingCropsStep> createState() => _OnboardingCropsStepState();
}

class _OnboardingCropsStepState extends State<OnboardingCropsStep> {
  late final FarmProfileController _c;

  @override
  void initState() {
    super.initState();
    _c = Get.find<FarmProfileController>();
  }

  Future<void> _openCropPicker({CropEntry? editing, int? index}) async {
    final result = await showModalBottomSheet<CropEntry>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CropEditorSheet(initial: editing),
    );
    if (result == null) return;
    if (index != null) {
      _c.replaceCropInDraft(index, result);
    } else {
      _c.addCropToDraft(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final crops = _c.draft.value.crops;
      return Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const OnboardingSectionTitle(
                  title: 'Your crops',
                  subtitle:
                      'Add every crop you currently grow. The AI narrows advice to these when relevant.',
                ),
                if (crops.isEmpty)
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Icon(Icons.eco, size: 36, color: AppColors.green),
                          const SizedBox(height: 8),
                          const Text(
                            'No crops added yet',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap "Add crop" to begin.',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...crops.asMap().entries.map((entry) {
                    final i = entry.key;
                    final c = entry.value;
                    final daysSince = DateTime.now().difference(c.sowingDate).inDays;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: AppColors.faintGreen,
                          child: Icon(Icons.grass, color: AppColors.green),
                        ),
                        title: Text(c.cropName),
                        subtitle: Text(
                          '${c.area} ${c.areaUnit} · ${c.growthStage} · sown $daysSince days ago',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              onPressed: () =>
                                  _openCropPicker(editing: c, index: i),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  size: 18, color: Colors.red),
                              onPressed: () => _c.removeCropFromDraft(i),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _openCropPicker(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add crop'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.green,
                    minimumSize: const Size.fromHeight(44),
                    side: const BorderSide(color: AppColors.green),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: OnboardingStepFooter(
              primaryLabel: 'Next',
              onPrimary: crops.isEmpty
                  ? null
                  : () => _c.nextStep(),
            ),
          ),
        ],
      );
    });
  }
}

class _CropEditorSheet extends StatefulWidget {
  final CropEntry? initial;
  const _CropEditorSheet({this.initial});

  @override
  State<_CropEditorSheet> createState() => _CropEditorSheetState();
}

class _CropEditorSheetState extends State<_CropEditorSheet> {
  late final FarmProfileController _c;
  final _varietyCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  MasterCrop? _selectedCrop;
  String _areaUnit = 'acre';
  DateTime? _sowingDate;
  String _growthStage = 'vegetative';
  String? _plantingMethod;
  String? _irrigationMethod;

  final _searchResults = <MasterCrop>[].obs;
  final _searching = false.obs;

  @override
  void initState() {
    super.initState();
    _c = Get.find<FarmProfileController>();
    final init = widget.initial;
    if (init != null) {
      _selectedCrop = MasterCrop(id: init.cropId, name: init.cropName);
      _searchCtrl.text = init.cropName;
      _varietyCtrl.text = init.variety ?? '';
      _areaCtrl.text = init.area.toString();
      _areaUnit = init.areaUnit;
      _sowingDate = init.sowingDate;
      _growthStage = init.growthStage;
      _plantingMethod = init.plantingMethod;
      _irrigationMethod = init.irrigationMethod;
    } else {
      _doSearch('');
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _varietyCtrl.dispose();
    _areaCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _doSearch(String q) async {
    _searching.value = true;
    try {
      final results = await _c.searchMasterCrops(q);
      _searchResults.assignAll(results);
    } finally {
      _searching.value = false;
    }
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _doSearch(v));
  }

  Future<void> _pickSowingDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
      initialDate: _sowingDate ?? now.subtract(const Duration(days: 14)),
    );
    if (picked != null) setState(() => _sowingDate = picked);
  }

  void _save() {
    if (_selectedCrop == null) {
      Get.snackbar(
        'Choose a crop',
        'Type to search and tap one of the chips below the search box.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    final area = double.tryParse(_areaCtrl.text.trim());
    if (area == null || area <= 0) {
      Get.snackbar('Enter area', 'Area must be a positive number.',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (_sowingDate == null) {
      Get.snackbar('Pick sowing date', 'Tap "Choose" to select the date.',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    final entry = CropEntry(
      id: widget.initial?.id,
      cropId: _selectedCrop!.id,
      cropName: _selectedCrop!.name,
      variety: _varietyCtrl.text.trim().isEmpty ? null : _varietyCtrl.text.trim(),
      area: area,
      areaUnit: _areaUnit,
      sowingDate: _sowingDate!,
      growthStage: _growthStage,
      plantingMethod: _plantingMethod,
      irrigationMethod: _irrigationMethod,
    );
    Navigator.of(context).pop(entry);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        builder: (_, scroll) => Container(
          padding: const EdgeInsets.all(16),
          child: ListView(
            controller: scroll,
            children: [
              Row(children: [
                Text(
                  widget.initial == null ? 'Add crop' : 'Edit crop',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ]),
              const SizedBox(height: 8),
              TextField(
                controller: _searchCtrl,
                decoration: onboardingInput('Search crop', hint: 'e.g. tomato'),
                onChanged: _onSearchChanged,
              ),
              const SizedBox(height: 8),
              Obx(() {
                if (_searching.value) {
                  return const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (_searchResults.isEmpty) {
                  final err = _c.errorMessage.value;
                  return Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(err.isNotEmpty
                            ? 'Search failed: $err'
                            : 'No crops matched your search.'),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () => _doSearch(_searchCtrl.text.trim()),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry search'),
                        ),
                      ],
                    ),
                  );
                }
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _searchResults.map((c) {
                    final selected = _selectedCrop?.id == c.id;
                    return ChoiceChip(
                      label: Text(c.name),
                      selected: selected,
                      onSelected: (_) => setState(() => _selectedCrop = c),
                      selectedColor: AppColors.green.withOpacity(0.2),
                    );
                  }).toList(),
                );
              }),
              const SizedBox(height: 16),
              TextField(
                controller: _varietyCtrl,
                decoration: onboardingInput('Variety (optional)'),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _areaCtrl,
                    keyboardType: TextInputType.number,
                    decoration: onboardingInput('Area'),
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
                          child: Text('hectare',
                              overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(
                          value: 'bigha',
                          child: Text('bigha',
                              overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(
                          value: 'gunta',
                          child: Text('gunta',
                              overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (v) => setState(() => _areaUnit = v ?? 'acre'),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: Text(_sowingDate == null
                    ? 'Pick sowing date'
                    : 'Sown: ${_sowingDate!.toIso8601String().split('T').first}'),
                trailing: TextButton(
                  onPressed: _pickSowingDate,
                  child: const Text('Choose'),
                ),
              ),
              DropdownButtonFormField<String>(
                value: _growthStage,
                decoration: onboardingInput('Current growth stage'),
                items: const [
                  DropdownMenuItem(value: 'pre_sowing', child: Text('Pre-sowing')),
                  DropdownMenuItem(value: 'germination', child: Text('Germination')),
                  DropdownMenuItem(value: 'seedling', child: Text('Seedling')),
                  DropdownMenuItem(value: 'vegetative', child: Text('Vegetative')),
                  DropdownMenuItem(value: 'flowering', child: Text('Flowering')),
                  DropdownMenuItem(value: 'fruiting', child: Text('Fruiting')),
                  DropdownMenuItem(value: 'maturity', child: Text('Maturity')),
                  DropdownMenuItem(value: 'harvested', child: Text('Harvested')),
                ],
                onChanged: (v) => setState(() => _growthStage = v ?? 'vegetative'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _plantingMethod,
                decoration: onboardingInput('Planting method (optional)'),
                items: const [
                  DropdownMenuItem(value: 'direct_sowing', child: Text('Direct sowing')),
                  DropdownMenuItem(value: 'transplanting', child: Text('Transplanting')),
                  DropdownMenuItem(value: 'broadcasting', child: Text('Broadcasting')),
                  DropdownMenuItem(value: 'line_sowing', child: Text('Line sowing')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (v) => setState(() => _plantingMethod = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _irrigationMethod,
                decoration: onboardingInput('Irrigation method (optional)'),
                items: const [
                  DropdownMenuItem(value: 'rainfed', child: Text('Rainfed')),
                  DropdownMenuItem(value: 'drip', child: Text('Drip')),
                  DropdownMenuItem(value: 'sprinkler', child: Text('Sprinkler')),
                  DropdownMenuItem(value: 'flood', child: Text('Flood')),
                  DropdownMenuItem(value: 'furrow', child: Text('Furrow')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (v) => setState(() => _irrigationMethod = v),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.green,
                  foregroundColor: AppColors.white,
                  minimumSize: const Size.fromHeight(44),
                ),
                child: const Text('Save crop'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
