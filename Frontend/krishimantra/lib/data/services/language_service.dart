import 'package:shared_preferences/shared_preferences.dart';
import 'package:translator/translator.dart';

class LanguageService {
  static const String LANGUAGE_KEY = 'preferred_language';
  final SharedPreferences _prefs;
  final translator = GoogleTranslator();

  // Singleton pattern
  static LanguageService? _instance;
  static Future<LanguageService> getInstance() async {
    if (_instance == null) {
      final prefs = await SharedPreferences.getInstance();
      _instance = LanguageService._(prefs);
    }
    return _instance!;
  }

  LanguageService._(this._prefs);

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
    if (getLanguage() == 'English') return text;

    try {
      final translation = await translator.translate(
        text,
        from: 'en',
        to: getLanguageCode(),
      );
      return translation.text;
    } catch (e) {
      return text; // Return original text if translation fails
    }
  }
}
