import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/api_constants.dart';
import 'api_service.dart';

/// Lightweight remote-config wrapper. Backend serves the same flags for the
/// whole tenant today (env-driven). Cohort splits later become a server-side
/// detail; the mobile contract stays identical.
///
/// Flags are read from SharedPreferences on construction (so the splash
/// screen can route immediately), then refreshed in the background after
/// login. Defaults match the backend defaults so a fresh install behaves
/// like a logged-in user with an empty cache.
class FeatureFlagService extends GetxService {
  static const String _cacheKey = 'feature_flags_cache_v1';
  static const Duration _ttl = Duration(minutes: 30);

  final RxMap<String, bool> _flags = <String, bool>{
    'NEW_AI_ENABLED': false,
    'ONBOARDING_V2_ENABLED': true,
    'AI_STREAMING_ENABLED': true,
    'EDIT_FARM_ENABLED': true,
    'WEATHER_VIA_BACKEND': true,
    'VOICE_CHAT_ENABLED': false,
  }.obs;
  DateTime? _refreshedAt;

  RxMap<String, bool> get flags => _flags;

  bool get newAiEnabled => _flags['NEW_AI_ENABLED'] ?? false;
  bool get onboardingV2Enabled => _flags['ONBOARDING_V2_ENABLED'] ?? true;
  bool get aiStreamingEnabled => _flags['AI_STREAMING_ENABLED'] ?? true;
  bool get editFarmEnabled => _flags['EDIT_FARM_ENABLED'] ?? true;
  bool get weatherViaBackend => _flags['WEATHER_VIA_BACKEND'] ?? true;
  bool get voiceChatEnabled => _flags['VOICE_CHAT_ENABLED'] ?? false;

  Future<FeatureFlagService> init() async {
    await _loadFromCache();
    return this;
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final cached = json['flags'] as Map<String, dynamic>?;
      if (cached != null) {
        for (final entry in cached.entries) {
          _flags[entry.key] = entry.value == true;
        }
      }
      final ts = json['refreshedAt']?.toString();
      if (ts != null) _refreshedAt = DateTime.tryParse(ts);
    } catch (e) {
      debugPrint('feature-flag cache read failed: $e');
    }
  }

  Future<void> refresh({bool force = false}) async {
    if (!force && _refreshedAt != null) {
      final age = DateTime.now().difference(_refreshedAt!);
      if (age < _ttl) return;
    }
    if (!Get.isRegistered<ApiService>()) return;
    final api = Get.find<ApiService>();
    try {
      final response = await api.get(ApiConstants.FEATURE_FLAGS);
      if (response.statusCode != 200 || response.data is! Map) return;
      final data = Map<String, dynamic>.from(response.data as Map);
      if (data['success'] != true) return;
      final raw = data['flags'];
      if (raw is Map) {
        for (final entry in raw.entries) {
          _flags[entry.key.toString()] = entry.value == true;
        }
      }
      _refreshedAt = DateTime.now();
      await _persist(data);
    } catch (e) {
      debugPrint('feature-flag refresh failed: $e');
    }
  }

  Future<void> _persist(Map<String, dynamic> raw) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(raw));
    } catch (_) {}
  }
}
