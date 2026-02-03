import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:translator/translator.dart';
import '../../core/config/app_config.dart';
import '../../core/utils/app_logger.dart';

/// Supported languages in the app
enum AppLanguage {
  english('English', 'en'),
  hindi('Hindi', 'hi'),
  marathi('Marathi', 'mr'),
  gujarati('Gujarati', 'gu'),
  bengali('Bengali', 'bn'),
  tamil('Tamil', 'ta'),
  telugu('Telugu', 'te'),
  kannada('Kannada', 'kn'),
  punjabi('Punjabi', 'pa'),
  malayalam('Malayalam', 'ml');

  final String displayName;
  final String code;

  const AppLanguage(this.displayName, this.code);

  static AppLanguage fromCode(String code) {
    return AppLanguage.values.firstWhere(
      (lang) => lang.code == code,
      orElse: () => AppLanguage.english,
    );
  }

  static AppLanguage fromName(String name) {
    return AppLanguage.values.firstWhere(
      (lang) => lang.displayName == name,
      orElse: () => AppLanguage.english,
    );
  }
}

/// Translation cache entry with timestamp
class TranslationCacheEntry {
  final String translatedText;
  final DateTime timestamp;

  TranslationCacheEntry(this.translatedText, this.timestamp);

  bool get isExpired {
    final expiryDuration = AppConfig.instance.translationCacheDuration;
    return DateTime.now().difference(timestamp) > expiryDuration;
  }

  Map<String, dynamic> toJson() => {
        'text': translatedText,
        'timestamp': timestamp.toIso8601String(),
      };

  factory TranslationCacheEntry.fromJson(Map<String, dynamic> json) {
    return TranslationCacheEntry(
      json['text'] as String,
      DateTime.parse(json['timestamp'] as String),
    );
  }
}

/// Enhanced Translation Service with caching and offline support
class TranslationService {
  static const String _languageKey = 'preferred_language';
  static const String _cacheKey = 'translation_cache';

  static TranslationService? _instance;

  final SharedPreferences _prefs;
  final GoogleTranslator _translator = GoogleTranslator();

  // In-memory cache for fast access
  final Map<String, Map<String, TranslationCacheEntry>> _memoryCache = {};

  // Current language
  AppLanguage _currentLanguage = AppLanguage.english;

  // Track if cache has been loaded
  bool _cacheLoaded = false;

  TranslationService._(this._prefs);

  /// Get singleton instance
  static Future<TranslationService> getInstance() async {
    if (_instance == null) {
      final prefs = await SharedPreferences.getInstance();
      _instance = TranslationService._(prefs);
      await _instance!._initialize();
    }
    return _instance!;
  }

  /// Initialize the service
  Future<void> _initialize() async {
    await _loadLanguage();
    await _loadCache();
  }

  /// Load saved language preference
  Future<void> _loadLanguage() async {
    final savedLanguage = _prefs.getString(_languageKey);
    if (savedLanguage != null) {
      _currentLanguage = AppLanguage.fromName(savedLanguage);
    }
  }

  /// Load translation cache from storage
  Future<void> _loadCache() async {
    if (_cacheLoaded) return;

    try {
      final cacheJson = _prefs.getString(_cacheKey);
      if (cacheJson != null) {
        final Map<String, dynamic> cacheData = jsonDecode(cacheJson);

        cacheData.forEach((langCode, translations) {
          _memoryCache[langCode] = {};
          if (translations is Map) {
            translations.forEach((key, value) {
              if (value is Map<String, dynamic>) {
                final entry = TranslationCacheEntry.fromJson(value);
                if (!entry.isExpired) {
                  _memoryCache[langCode]![key] = entry;
                }
              }
            });
          }
        });

        logger.d('Loaded ${_getTotalCacheEntries()} translation cache entries', tag: 'Translation');
      }
    } catch (e) {
      logger.w('Failed to load translation cache: $e', tag: 'Translation');
    }

    _cacheLoaded = true;
  }

  /// Save cache to storage
  Future<void> _saveCache() async {
    try {
      final Map<String, dynamic> cacheData = {};

      _memoryCache.forEach((langCode, translations) {
        cacheData[langCode] = {};
        translations.forEach((key, entry) {
          if (!entry.isExpired) {
            (cacheData[langCode] as Map)[key] = entry.toJson();
          }
        });
      });

      await _prefs.setString(_cacheKey, jsonEncode(cacheData));
    } catch (e) {
      logger.w('Failed to save translation cache: $e', tag: 'Translation');
    }
  }

  int _getTotalCacheEntries() {
    int total = 0;
    _memoryCache.forEach((_, translations) {
      total += translations.length;
    });
    return total;
  }

  /// Get current language
  AppLanguage get currentLanguage => _currentLanguage;

  /// Get current language code
  String get languageCode => _currentLanguage.code;

  /// Get current language display name
  String get languageName => _currentLanguage.displayName;

  /// Check if current language is English (no translation needed)
  bool get isEnglish => _currentLanguage == AppLanguage.english;

  /// Save selected language
  Future<void> setLanguage(AppLanguage language) async {
    _currentLanguage = language;
    await _prefs.setString(_languageKey, language.displayName);
    logger.i('Language changed to ${language.displayName}', tag: 'Translation');
  }

  /// Translate text with caching
  Future<String> translate(String text) async {
    // Skip translation for English or empty text
    if (isEnglish || text.isEmpty) {
      return text;
    }

    // Check cache first
    final cacheKey = _generateCacheKey(text);
    final cachedEntry = _getFromCache(cacheKey);

    if (cachedEntry != null && !cachedEntry.isExpired) {
      TranslationLogger.cacheHit(text);
      return cachedEntry.translatedText;
    }

    TranslationLogger.cacheMiss(text);

    // Translate using API
    try {
      final translation = await _translator.translate(
        text,
        from: 'en',
        to: languageCode,
      );

      final translatedText = translation.text;

      // Cache the result
      await _addToCache(cacheKey, translatedText);

      TranslationLogger.translate(text, translatedText, languageName);

      return translatedText;
    } catch (e) {
      TranslationLogger.error(text, e);
      // Return original text if translation fails
      return text;
    }
  }

  /// Batch translate multiple texts (more efficient)
  Future<List<String>> translateBatch(List<String> texts) async {
    if (isEnglish || texts.isEmpty) {
      return texts;
    }

    final results = <String>[];
    final textsToTranslate = <int, String>{};

    // Check cache for each text
    for (int i = 0; i < texts.length; i++) {
      final text = texts[i];
      if (text.isEmpty) {
        results.add(text);
        continue;
      }

      final cacheKey = _generateCacheKey(text);
      final cachedEntry = _getFromCache(cacheKey);

      if (cachedEntry != null && !cachedEntry.isExpired) {
        results.add(cachedEntry.translatedText);
      } else {
        results.add(''); // Placeholder
        textsToTranslate[i] = text;
      }
    }

    // Translate remaining texts in parallel
    if (textsToTranslate.isNotEmpty) {
      try {
        final futures = textsToTranslate.entries.map((entry) async {
          final translated = await translate(entry.value);
          return MapEntry(entry.key, translated);
        });

        final translatedEntries = await Future.wait(futures);

        for (final entry in translatedEntries) {
          results[entry.key] = entry.value;
        }
      } catch (e) {
        logger.e('Batch translation failed: $e', tag: 'Translation');
        // Fill remaining with original texts
        for (final entry in textsToTranslate.entries) {
          if (results[entry.key].isEmpty) {
            results[entry.key] = entry.value;
          }
        }
      }
    }

    return results;
  }

  /// Translate a map of key-value pairs
  Future<Map<String, String>> translateMap(Map<String, String> textMap) async {
    if (isEnglish || textMap.isEmpty) {
      return textMap;
    }

    final keys = textMap.keys.toList();
    final values = textMap.values.toList();
    final translatedValues = await translateBatch(values);

    final result = <String, String>{};
    for (int i = 0; i < keys.length; i++) {
      result[keys[i]] = translatedValues[i];
    }

    return result;
  }

  String _generateCacheKey(String text) {
    // Use a simple hash for the cache key
    return text.hashCode.toString();
  }

  TranslationCacheEntry? _getFromCache(String key) {
    return _memoryCache[languageCode]?[key];
  }

  Future<void> _addToCache(String key, String translatedText) async {
    _memoryCache[languageCode] ??= {};
    _memoryCache[languageCode]![key] = TranslationCacheEntry(
      translatedText,
      DateTime.now(),
    );

    // Enforce cache size limit
    await _enforceCacheLimit();

    // Periodically save cache to storage
    if (_getTotalCacheEntries() % 10 == 0) {
      await _saveCache();
    }
  }

  Future<void> _enforceCacheLimit() async {
    final maxEntries = AppConfig.instance.maxTranslationCacheEntries;

    if (_getTotalCacheEntries() > maxEntries) {
      // Remove oldest entries
      _memoryCache.forEach((langCode, translations) {
        final entries = translations.entries.toList()
          ..sort((a, b) => a.value.timestamp.compareTo(b.value.timestamp));

        final toRemove = entries.take(translations.length ~/ 4).map((e) => e.key);
        for (final key in toRemove) {
          translations.remove(key);
        }
      });
    }
  }

  /// Clear all cache
  Future<void> clearCache() async {
    _memoryCache.clear();
    await _prefs.remove(_cacheKey);
    logger.i('Translation cache cleared', tag: 'Translation');
  }

  /// Get cache statistics
  Map<String, int> getCacheStats() {
    final stats = <String, int>{};
    _memoryCache.forEach((langCode, translations) {
      stats[langCode] = translations.length;
    });
    return stats;
  }
}

/// Global convenience function
Future<String> tr(String text) async {
  final service = await TranslationService.getInstance();
  return service.translate(text);
}
