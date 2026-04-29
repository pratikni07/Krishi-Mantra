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

  // Monotonic counter incremented every time the user picks a different
  // language. Per-model translation caches read this on translate, store
  // it alongside the cached string, and invalidate when it shifts. Without
  // this, switching from Hindi to Marathi at runtime left every cached
  // model holding stale Hindi strings until the app restarted.
  int _languageVersion = 0;
  int get languageVersion => _languageVersion;

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

  // Save selected language. Bumping the version is what tells per-model
  // translation caches to re-translate; do it whenever the saved value
  // actually changes so callers that idempotently re-save the current
  // language don't churn caches.
  Future<void> saveLanguage(String language) async {
    final previous = _prefs.getString(LANGUAGE_KEY);
    await _prefs.setString(LANGUAGE_KEY, language);
    if (previous != language) {
      _languageVersion++;
    }
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

  /// Translate a list of strings in one pass, returning translations in the
  /// same order. De-duplicates identical inputs so a list of 10 tips with
  /// 3 unique strings only does 3 network round-trips. Pretranslated
  /// entries are served from the in-memory cache without hitting the
  /// network at all. Use this anywhere you'd otherwise call `translate`
  /// inside a `.map` — fire-and-await N requests is the I8 anti-pattern.
  Future<List<String>> translateBatch(List<String> texts) async {
    if (texts.isEmpty) return const [];
    if (getLanguage() == 'English') return List<String>.from(texts);

    // Map each unique non-empty source string to a single translation
    // future; reuse it across duplicate slots in the input list.
    final futures = <String, Future<String>>{};
    for (final t in texts) {
      if (t.trim().isEmpty) continue;
      futures.putIfAbsent(t, () => translate(t));
    }
    final entries = await Future.wait(futures.entries.map(
      (e) async => MapEntry(e.key, await e.value),
    ));
    final lookup = Map.fromEntries(entries);
    return texts.map((t) => lookup[t] ?? t).toList();
  }
}
