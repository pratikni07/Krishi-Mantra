import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:translator/translator.dart';

class LanguageService {
  // ignore: constant_identifier_names
  static const String LANGUAGE_KEY = 'preferred_language';
  final SharedPreferences _prefs;
  final translator = GoogleTranslator();
  static const String _pretranslatedAssetPath =
      'assets/translations/pretranslated_labels.json';
  Map<String, dynamic> _pretranslatedLabels = {};

  // Singleton pattern
  static LanguageService? _instance;
  static Future<LanguageService> getInstance() async {
    if (_instance == null) {
      final prefs = await SharedPreferences.getInstance();
      _instance = LanguageService._(prefs);
      await _instance!._loadPretranslatedLabels();
    }
    return _instance!;
  }

  LanguageService._(this._prefs);

  Future<void> _loadPretranslatedLabels() async {
    try {
      final jsonString = await rootBundle.loadString(_pretranslatedAssetPath);
      final decoded = json.decode(jsonString);
      if (decoded is Map<String, dynamic>) {
        _pretranslatedLabels = decoded;
      }
    } catch (_) {
      _pretranslatedLabels = {};
    }
  }

  String? _getPretranslatedText(String text, String targetCode) {
    final item = _pretranslatedLabels[text];
    if (item is Map<String, dynamic>) {
      final translated = item[targetCode];
      if (translated is String && translated.trim().isNotEmpty) {
        return translated;
      }
    }
    return null;
  }

  // Language codes for translation
  static const Map<String, String> languageCodes = {
    'English': 'en',
    'Hindi': 'hi',
    'Marathi': 'mr',
    'Gujarati': 'gu',
    'Bengali': 'bn',
    'Tamil': 'ta',
  };

  // Save selected language
  Future<void> saveLanguage(String language) async {
    await _prefs.setString(LANGUAGE_KEY, language);
  }

  // Get saved language
  String getLanguage() {
    return _prefs.getString(LANGUAGE_KEY) ?? 'English';
  }

  // Get language code for translation
  String getLanguageCode() {
    final language = getLanguage();
    return languageCodes[language] ?? 'en';
  }

  // Translate text
  Future<String> translate(String text) async {
    if (text.trim().isEmpty) return text;
    if (getLanguage() == 'English') return text;

    final targetCode = getLanguageCode();
    final pretranslated = _getPretranslatedText(text, targetCode);
    if (pretranslated != null) {
      return pretranslated;
    }

    try {
      final translation = await translator.translate(
        text,
        from: 'en',
        to: targetCode,
      );
      final translatedText = translation.text;
      if (translatedText.trim().isNotEmpty) {
        _pretranslatedLabels[text] = {
          ...((_pretranslatedLabels[text] as Map<String, dynamic>?) ?? {}),
          'en': text,
          targetCode: translatedText,
        };
      }
      return translatedText;
    } catch (e) {
      return text; // Return original text if translation fails
    }
  }
}
