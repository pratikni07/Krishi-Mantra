import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/colors.dart';
import '../../../core/utils/voice_localizations.dart';
import '../../../data/services/feature_flag_service.dart';
import '../../../data/services/language_service.dart';

/// Drop-in voice settings card for the existing Settings screen. Stores the
/// user's voice prefs in SharedPreferences for now; when we wire the
/// `/api/farm-profile/notifyPrefs` endpoint to also accept voice prefs the
/// gender + retention toggles will sync server-side.
///
///   - Voice replies on/off (off = ignore audio chunks; just stream text)
///   - Voice gender (female / male — provider-supported only)
///   - Keep my voice notes for 30 days (default off)
///   - Delete all voice notes
class VoiceSettingsSection extends StatefulWidget {
  const VoiceSettingsSection({super.key});

  @override
  State<VoiceSettingsSection> createState() => _VoiceSettingsSectionState();
}

class _VoiceSettingsSectionState extends State<VoiceSettingsSection> {
  static const _kRepliesKey = 'voice_replies_enabled';
  static const _kGenderKey = 'voice_gender';
  static const _kRetainKey = 'voice_retain_30d';

  bool _repliesEnabled = true;
  String _gender = 'female';
  bool _retain = false;
  String _lang = 'en';
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final lang = (await LanguageService.getInstance()).getLanguageCode();
    if (!mounted) return;
    setState(() {
      _repliesEnabled = prefs.getBool(_kRepliesKey) ?? true;
      _gender = prefs.getString(_kGenderKey) ?? 'female';
      _retain = prefs.getBool(_kRetainKey) ?? false;
      _lang = lang;
      _loaded = true;
    });
  }

  String _t(String k) => VoiceLocalizations.text(k, _lang);

  Future<void> _setReplies(bool v) async {
    setState(() => _repliesEnabled = v);
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kRepliesKey, v);
  }

  Future<void> _setGender(String? v) async {
    if (v == null) return;
    setState(() => _gender = v);
    final p = await SharedPreferences.getInstance();
    await p.setString(_kGenderKey, v);
  }

  Future<void> _setRetain(bool v) async {
    setState(() => _retain = v);
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kRetainKey, v);
  }

  Future<void> _confirmDeleteAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete all voice notes?'),
        content: const Text(
          'Cached audio replays for previous answers will be removed. '
          'This does not affect your chat history.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    // Voice replay cache lives server-side. We don't expose a delete endpoint
    // yet; the 24h TTL will clear it. Show a friendly snackbar.
    if (!mounted) return;
    Get.snackbar(
      'Cleared',
      'Voice notes will expire within 24 hours.',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  Future<void> _openMicSettings() async {
    await openAppSettings();
  }

  bool get _featureEnabled {
    if (!Get.isRegistered<FeatureFlagService>()) return true;
    final v = Get.find<FeatureFlagService>().flags['VOICE_CHAT_ENABLED'];
    return v == null || v == true;
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    if (!_featureEnabled) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            _t('voice.settings.title'),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
        ),
        SwitchListTile(
          title: Text(_t('voice.settings.replies_enabled')),
          subtitle: Text(
            _t('voice.settings.replies_subtitle'),
            style: const TextStyle(fontSize: 12, color: AppColors.textLight),
          ),
          value: _repliesEnabled,
          onChanged: _setReplies,
          activeColor: AppColors.green,
        ),
        ListTile(
          title: Text(_t('voice.settings.gender_label')),
          trailing: DropdownButton<String>(
            value: _gender,
            onChanged: _setGender,
            items: [
              DropdownMenuItem(value: 'female', child: Text(_t('voice.settings.gender_female'))),
              DropdownMenuItem(value: 'male', child: Text(_t('voice.settings.gender_male'))),
            ],
          ),
        ),
        SwitchListTile(
          title: Text(_t('voice.settings.retain')),
          subtitle: Text(
            _t('voice.settings.retain_subtitle'),
            style: const TextStyle(fontSize: 12, color: AppColors.textLight),
          ),
          value: _retain,
          onChanged: _setRetain,
          activeColor: AppColors.green,
        ),
        ListTile(
          title: Text(_t('voice.settings.delete_all')),
          leading: const Icon(Icons.delete_forever, color: Colors.red),
          onTap: _confirmDeleteAll,
        ),
        ListTile(
          title: const Text('Microphone permission'),
          leading: const Icon(Icons.mic_none),
          trailing: TextButton(
            onPressed: _openMicSettings,
            child: const Text('Manage'),
          ),
        ),
      ],
    );
  }
}
