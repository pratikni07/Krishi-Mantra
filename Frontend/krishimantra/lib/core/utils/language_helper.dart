import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../data/services/language_service.dart';

/// A helper class to manage translations and language support throughout the app.
/// This provides common functionality to simplify the implementation of
/// translations in all screens, including dynamic data from API responses.
class LanguageHelper {
  /// Translates a list of texts in a batch for better performance
  /// Returns a list of translated strings in the same order
  static Future<List<String>> batchTranslate(List<String> texts) async {
    final languageService = await LanguageService.getInstance();
    final translations =
        await Future.wait(texts.map((text) => languageService.translate(text)));
    return translations;
  }

  /// Translates a map of key-value pairs, preserving the keys
  /// This is useful for translating form labels, button texts, etc.
  static Future<Map<String, String>> translateMap(
      Map<String, String> textMap) async {
    final languageService = await LanguageService.getInstance();
    final Map<String, String> result = {};

    // Create a list of translation futures
    final keys = textMap.keys.toList();
    final values = textMap.values.toList();

    final translatedValues = await Future.wait(
        values.map((text) => languageService.translate(text)));

    // Rebuild the map with translated values
    for (int i = 0; i < keys.length; i++) {
      result[keys[i]] = translatedValues[i];
    }

    return result;
  }

  /// Translates a dynamic API response, handling nested structures
  /// This is particularly useful for translating API responses with text content
  static Future<dynamic> translateApiResponse(dynamic data,
      {List<String> fieldsToTranslate = const []}) async {
    if (data == null) return null;

    final languageService = await LanguageService.getInstance();

    // Handle lists
    if (data is List) {
      return Future.wait(data.map((item) =>
          translateApiResponse(item, fieldsToTranslate: fieldsToTranslate)));
    }

    // Handle maps/objects
    if (data is Map) {
      Map<String, dynamic> translatedData = {};

      for (final entry in data.entries) {
        final key = entry.key.toString();
        final value = entry.value;

        // Check if this field should be translated
        if (value is String &&
            (fieldsToTranslate.isEmpty || fieldsToTranslate.contains(key))) {
          translatedData[key] = await languageService.translate(value);
        } else if (value is Map || value is List) {
          // Recursively translate nested structures
          translatedData[key] = await translateApiResponse(value,
              fieldsToTranslate: fieldsToTranslate);
        } else {
          // Keep other values as is
          translatedData[key] = value;
        }
      }

      return translatedData;
    }

    // Return non-translatable values as is
    return data;
  }

  /// Creates a reusable mixin to add translation capabilities to any StatefulWidget
  static Widget getLoadingWidget() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  /// Shows a translated error message
  static Future<void> showTranslatedError(
      BuildContext context, String message) async {
    final languageService = await LanguageService.getInstance();
    final translatedMessage = await languageService.translate(message);
    final translatedErrorTitle = await languageService.translate('Error');

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(translatedMessage),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red[700],
        ),
      );
    }
  }

  /// Get the current language code
  static Future<String> getCurrentLanguageCode() async {
    final languageService = await LanguageService.getInstance();
    return languageService.getLanguageCode();
  }
}

/// A mixin that can be added to any State<T> class to easily implement translations
mixin TranslationMixin<T extends StatefulWidget> on State<T> {
  late LanguageService _languageService;
  bool _isTranslating = false;

  // Store all text that needs translation
  final Map<String, String> _translations = {};

  @override
  void initState() {
    super.initState();
    _initializeLanguage();
  }

  /// Initialize the language service
  Future<void> _initializeLanguage() async {
    _languageService = await LanguageService.getInstance();
    await updateTranslations();
  }

  /// Register text for translation
  void registerTranslation(String key, String defaultText) {
    _translations[key] = defaultText;
  }

  /// Get a translated text by key
  String getTranslation(String key) {
    return _translations[key] ?? key;
  }

  /// Update all translations
  Future<void> updateTranslations() async {
    if (_isTranslating) return;
    _isTranslating = true;

    try {
      final entries = _translations.entries.toList();
      final keys = entries.map((e) => e.key).toList();
      final values = entries.map((e) => e.value).toList();

      final translatedValues = await Future.wait(
          values.map((text) => _languageService.translate(text)));

      // Update the translations map
      for (int i = 0; i < keys.length; i++) {
        _translations[keys[i]] = translatedValues[i];
      }

      if (mounted) {
        setState(() {});
      }
    } finally {
      _isTranslating = false;
    }
  }

  /// Translate a single text
  Future<String> translate(String text) async {
    return await _languageService.translate(text);
  }

  /// Translate a list of API items with specific fields
  Future<List<Map<String, dynamic>>> translateItems(
      List<Map<String, dynamic>> items, List<String> fieldsToTranslate) async {
    final result = await LanguageHelper.translateApiResponse(items,
        fieldsToTranslate: fieldsToTranslate);
    return List<Map<String, dynamic>>.from(result);
  }
}
