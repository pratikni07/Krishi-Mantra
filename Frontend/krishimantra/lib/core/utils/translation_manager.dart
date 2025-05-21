import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../data/services/language_service.dart';

/// A global manager for translations and language changes
/// This allows for app-wide language switching and notification of changes
class TranslationManager extends GetxController {
  // Observable for current language
  final Rx<String> currentLanguage = 'English'.obs;

  // Observable for language code
  final Rx<String> currentLanguageCode = 'en'.obs;

  // List of language change listeners
  final List<Function()> _listeners = [];

  // Singleton pattern
  static TranslationManager? _instance;
  static TranslationManager get instance {
    _instance ??= TranslationManager._();
    return _instance!;
  }

  TranslationManager._();

  @override
  void onInit() {
    super.onInit();
    _loadCurrentLanguage();
  }

  /// Initialize by loading current language setting
  Future<void> _loadCurrentLanguage() async {
    final languageService = await LanguageService.getInstance();
    final language = languageService.getLanguage();
    currentLanguage.value = language;
    currentLanguageCode.value = languageService.getLanguageCode();
  }

  /// Static method to translate text
  static Future<String> translate(String text) async {
    final languageService = await LanguageService.getInstance();
    return await languageService.translate(text);
  }

  /// Change the app language
  Future<void> changeLanguage(String language) async {
    try {
      final languageService = await LanguageService.getInstance();
      await languageService.saveLanguage(language);

      currentLanguage.value = language;
      currentLanguageCode.value = languageService.getLanguageCode();

      // Notify all listeners of language change
      _notifyListeners();

      // Show a brief confirmation toast
      Get.snackbar(
        'Language Changed',
        'The app language has been changed to $language',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.green.withOpacity(0.7),
        colorText: Colors.white,
      );
    } catch (e) {
      debugPrint('Error changing language: $e');
    }
  }

  /// Add a language change listener
  void addLanguageChangeListener(Function() listener) {
    if (!_listeners.contains(listener)) {
      _listeners.add(listener);
    }
  }

  /// Remove a previously added language change listener
  void removeLanguageChangeListener(Function() listener) {
    _listeners.remove(listener);
  }

  /// Notify all listeners of language change
  void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }
}
