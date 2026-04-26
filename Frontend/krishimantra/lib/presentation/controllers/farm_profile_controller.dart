import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/farm_profile.dart';
import '../../data/repositories/farm_profile_repository.dart';

/// Holds the in-progress onboarding state across the 4 steps, persists a
/// local draft to SharedPreferences so users can resume if they close the app,
/// and exposes CRUD hooks to the repository.
class FarmProfileController extends GetxController {
  static const String draftKey = 'farm_profile_draft_v1';

  final FarmProfileRepository _repo;

  FarmProfileController(this._repo);

  // Remote-backed state
  final profile = Rxn<FarmProfile>();
  final isLoading = false.obs;
  final isSaving = false.obs;
  final errorMessage = ''.obs;

  // Onboarding draft
  final draft = FarmProfile.empty().obs;
  final currentStep = 0.obs;
  final maxStep = 3.obs; // 0..3 = 4 steps

  // Master-crop search cache
  final cropResults = <MasterCrop>[].obs;
  final cropQuery = ''.obs;

  @override
  void onInit() {
    super.onInit();
    _loadDraft();
  }

  Future<void> loadFromServer() async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final p = await _repo.getMyProfile();
      profile.value = p;
      if (p != null && p.onboardingStatus != 'completed') {
        // Merge server state with any newer local draft, preferring local.
        draft.value = draft.value.copyWith(
          age: draft.value.age ?? p.age,
          gender: draft.value.gender ?? p.gender,
          preferredLanguage:
              draft.value.preferredLanguage.isNotEmpty
                  ? draft.value.preferredLanguage
                  : p.preferredLanguage,
          latitude: draft.value.latitude ?? p.latitude,
          longitude: draft.value.longitude ?? p.longitude,
          address: draft.value.address ?? p.address,
          totalArea: draft.value.totalArea ?? p.totalArea,
          totalAreaUnit: draft.value.totalAreaUnit,
          ownership: draft.value.ownership ?? p.ownership,
          soilTypes:
              draft.value.soilTypes.isNotEmpty ? draft.value.soilTypes : p.soilTypes,
          irrigationSources: draft.value.irrigationSources.isNotEmpty
              ? draft.value.irrigationSources
              : p.irrigationSources,
          experienceYears:
              draft.value.experienceYears > 0 ? draft.value.experienceYears : p.experienceYears,
          crops: draft.value.crops.isNotEmpty ? draft.value.crops : p.crops,
        );
      }
    } catch (e) {
      errorMessage.value = _readable(e);
    } finally {
      isLoading.value = false;
    }
  }

  void updateDraft(FarmProfile Function(FarmProfile current) fn) {
    draft.value = fn(draft.value);
    _persistDraftDebounced();
  }

  void setStep(int step) {
    currentStep.value = step.clamp(0, maxStep.value);
  }

  void nextStep() {
    if (currentStep.value < maxStep.value) currentStep.value += 1;
  }

  void previousStep() {
    if (currentStep.value > 0) currentStep.value -= 1;
  }

  void addCropToDraft(CropEntry crop) {
    final next = [...draft.value.crops, crop];
    updateDraft((c) => c.copyWith(crops: next));
  }

  void removeCropFromDraft(int index) {
    final next = [...draft.value.crops];
    if (index >= 0 && index < next.length) {
      next.removeAt(index);
      updateDraft((c) => c.copyWith(crops: next));
    }
  }

  void replaceCropInDraft(int index, CropEntry crop) {
    final next = [...draft.value.crops];
    if (index >= 0 && index < next.length) {
      next[index] = crop;
      updateDraft((c) => c.copyWith(crops: next));
    }
  }

  Future<List<MasterCrop>> searchMasterCrops(String q) async {
    cropQuery.value = q;
    try {
      final results = await _repo.searchCrops(query: q);
      cropResults.assignAll(results);
      return results;
    } catch (e) {
      errorMessage.value = _readable(e);
      return const [];
    }
  }

  /// Submit the draft: PUT /me, then POST each crop individually (the upsert
  /// endpoint intentionally doesn't batch crops to keep the payload bounded).
  Future<bool> submitOnboarding() async {
    if (draft.value.latitude == null || draft.value.longitude == null) {
      errorMessage.value = 'Location is required';
      return false;
    }
    isSaving.value = true;
    errorMessage.value = '';
    try {
      final toSubmit = draft.value.copyWith(onboardingStatus: 'completed');
      final saved = await _repo.upsertProfile(toSubmit);
      // Persist crops that have no id yet (new ones)
      final savedCrops = <CropEntry>[];
      for (final c in draft.value.crops) {
        if (c.id == null) {
          final created = await _repo.addCrop(c);
          savedCrops.add(created);
        } else {
          savedCrops.add(c);
        }
      }
      profile.value = saved.copyWith(
        crops: savedCrops,
        onboardingStatus: 'completed',
      );
      await _clearDraft();
      return true;
    } catch (e) {
      errorMessage.value = _readable(e);
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  // --- Local draft persistence ---

  Future<void> _loadDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(draftKey);
      if (raw == null) return;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      draft.value = FarmProfile.fromDraftJson(json);
      currentStep.value =
          (json['currentStep'] as num?)?.toInt().clamp(0, maxStep.value) ?? 0;
    } catch (e) {
      debugPrint('farm_profile draft load failed: $e');
    }
  }

  Future<void> _persistDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = {
        ...draft.value.toDraftJson(),
        'currentStep': currentStep.value,
      };
      await prefs.setString(draftKey, jsonEncode(payload));
    } catch (e) {
      debugPrint('farm_profile draft save failed: $e');
    }
  }

  Worker? _draftDebounce;
  void _persistDraftDebounced() {
    // Write-through debounce (300ms) so every field tick doesn't touch disk
    _draftDebounce?.dispose();
    _draftDebounce = debounce<FarmProfile>(
      draft,
      (_) => _persistDraft(),
      time: const Duration(milliseconds: 300),
    );
  }

  Future<void> _clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(draftKey);
    } catch (_) {}
    draft.value = FarmProfile.empty();
    currentStep.value = 0;
  }

  String _readable(Object e) {
    final msg = e.toString();
    if (msg.contains('SocketException')) return 'Network unavailable';
    return msg.replaceFirst('Exception: ', '');
  }

  @override
  void onClose() {
    _draftDebounce?.dispose();
    super.onClose();
  }
}
