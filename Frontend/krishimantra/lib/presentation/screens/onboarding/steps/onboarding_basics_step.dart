import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';

import '../../../../core/constants/colors.dart';
import '../../../../data/models/farm_profile.dart';
import '../../../controllers/farm_profile_controller.dart';
import '../onboarding_ui.dart';

class OnboardingBasicsStep extends StatefulWidget {
  const OnboardingBasicsStep({super.key});

  @override
  State<OnboardingBasicsStep> createState() => _OnboardingBasicsStepState();
}

class _OnboardingBasicsStepState extends State<OnboardingBasicsStep> {
  final _formKey = GlobalKey<FormState>();
  late final FarmProfileController _c;
  final _ageCtrl = TextEditingController();
  final _villageCtrl = TextEditingController();
  final _talukaCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  String? _gender;
  bool _fetchingLocation = false;

  @override
  void initState() {
    super.initState();
    _c = Get.find<FarmProfileController>();
    final d = _c.draft.value;
    _ageCtrl.text = d.age?.toString() ?? '';
    _gender = d.gender;
    _villageCtrl.text = d.address?.village ?? '';
    _talukaCtrl.text = d.address?.taluka ?? '';
    _districtCtrl.text = d.address?.district ?? '';
    _stateCtrl.text = d.address?.state ?? '';
    _pincodeCtrl.text = d.address?.pincode ?? '';
  }

  @override
  void dispose() {
    _ageCtrl.dispose();
    _villageCtrl.dispose();
    _talukaCtrl.dispose();
    _districtCtrl.dispose();
    _stateCtrl.dispose();
    _pincodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _getLocation() async {
    setState(() => _fetchingLocation = true);
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied ||
            requested == LocationPermission.deniedForever) {
          throw Exception('Location permission denied');
        }
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      _c.updateDraft(
        (c) => c.copyWith(latitude: pos.latitude, longitude: pos.longitude),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Location saved: ${pos.latitude.toStringAsFixed(2)}, ${pos.longitude.toStringAsFixed(2)}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not get location: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _fetchingLocation = false);
    }
  }

  void _next() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final d = _c.draft.value;
    if (d.latitude == null || d.longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set your location first.')),
      );
      return;
    }

    _c.updateDraft(
      (c) => c.copyWith(
        age: int.tryParse(_ageCtrl.text.trim()),
        gender: _gender,
        address: (c.address ?? const FarmAddress()).copyWith(
          village: _villageCtrl.text.trim().isEmpty ? null : _villageCtrl.text.trim(),
          taluka: _talukaCtrl.text.trim().isEmpty ? null : _talukaCtrl.text.trim(),
          district: _districtCtrl.text.trim().isEmpty ? null : _districtCtrl.text.trim(),
          state: _stateCtrl.text.trim().isEmpty ? null : _stateCtrl.text.trim(),
          pincode: _pincodeCtrl.text.trim().isEmpty ? null : _pincodeCtrl.text.trim(),
        ),
      ),
    );
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
            title: 'About you',
            subtitle: 'Helps us tailor advice to your experience and location.',
          ),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _ageCtrl,
                  keyboardType: TextInputType.number,
                  decoration: onboardingInput('Age (optional)'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final n = int.tryParse(v.trim());
                    if (n == null || n < 10 || n > 120) return 'Enter 10–120';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _gender,
                  decoration: onboardingInput('Gender (optional)'),
                  items: const [
                    DropdownMenuItem(value: 'male', child: Text('Male')),
                    DropdownMenuItem(value: 'female', child: Text('Female')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                    DropdownMenuItem(
                        value: 'prefer_not_to_say',
                        child: Text('Prefer not to say')),
                  ],
                  onChanged: (v) => setState(() => _gender = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const OnboardingSectionTitle(
            title: 'Location',
            subtitle: 'We use this for ±3-day weather and regional advice. Stored securely.',
          ),
          Obx(() {
            final d = _c.draft.value;
            final hasLoc = d.latitude != null && d.longitude != null;
            return Card(
              child: ListTile(
                leading: Icon(
                  hasLoc ? Icons.check_circle : Icons.location_off,
                  color: hasLoc ? AppColors.green : Colors.grey,
                ),
                title: Text(hasLoc
                    ? '${d.latitude!.toStringAsFixed(3)}, ${d.longitude!.toStringAsFixed(3)}'
                    : 'No location set'),
                trailing: _fetchingLocation
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : TextButton.icon(
                        onPressed: _getLocation,
                        icon: const Icon(Icons.my_location),
                        label: Text(hasLoc ? 'Refresh' : 'Use GPS'),
                      ),
              ),
            );
          }),
          const SizedBox(height: 16),
          TextFormField(
            controller: _villageCtrl,
            decoration: onboardingInput('Village (optional)'),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: _talukaCtrl,
                decoration: onboardingInput('Taluka'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _districtCtrl,
                decoration: onboardingInput('District'),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: _stateCtrl,
                decoration: onboardingInput('State'),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 140,
              child: TextFormField(
                controller: _pincodeCtrl,
                keyboardType: TextInputType.number,
                decoration: onboardingInput('Pincode'),
              ),
            ),
          ]),
          const SizedBox(height: 32),
          OnboardingStepFooter(
            primaryLabel: 'Next',
            onPrimary: _next,
          ),
        ],
      ),
    );
  }
}
