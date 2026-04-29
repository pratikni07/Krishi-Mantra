import '../services/language_service.dart';

class CropModel {
  final String id;
  final String name;
  final String scientificName;
  final String description;
  final int growingPeriod;
  final List<Season> seasons;
  final String imageUrl;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Cached translations. Each cache stores both the translated string AND
  // the LanguageService version it was translated under; getters compare
  // against the current version and re-translate if the user has switched
  // languages since the value was cached.
  String? _translatedName;
  int? _translatedNameVersion;
  String? _translatedScientificName;
  int? _translatedScientificNameVersion;
  String? _translatedDescription;
  int? _translatedDescriptionVersion;

  CropModel({
    required this.id,
    required this.name,
    required this.scientificName,
    required this.description,
    required this.growingPeriod,
    required this.seasons,
    required this.imageUrl,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  // Get translated name
  Future<String> getTranslatedName() async {
    final languageService = await LanguageService.getInstance();
    if (_translatedName != null &&
        _translatedNameVersion == languageService.languageVersion) {
      return _translatedName!;
    }
    final translated = await languageService.translate(name);
    _translatedName = translated;
    _translatedNameVersion = languageService.languageVersion;
    return translated;
  }

  // Get translated scientific name
  Future<String> getTranslatedScientificName() async {
    final languageService = await LanguageService.getInstance();
    if (_translatedScientificName != null &&
        _translatedScientificNameVersion == languageService.languageVersion) {
      return _translatedScientificName!;
    }
    final translated = await languageService.translate(scientificName);
    _translatedScientificName = translated;
    _translatedScientificNameVersion = languageService.languageVersion;
    return translated;
  }

  // Get translated description
  Future<String> getTranslatedDescription() async {
    final languageService = await LanguageService.getInstance();
    if (_translatedDescription != null &&
        _translatedDescriptionVersion == languageService.languageVersion) {
      return _translatedDescription!;
    }
    final translated = await languageService.translate(description);
    _translatedDescription = translated;
    _translatedDescriptionVersion = languageService.languageVersion;
    return translated;
  }

  /// Parse a server-provided ISO date string. Forces a UTC interpretation
  /// when the string is bare (no `Z` and no offset) so the calendar isn't
  /// shifted by the device's local timezone — a Europe-region user used to
  /// see "yesterday's" stage on early-morning fetches because backend dates
  /// without a tz suffix were interpreted as local time.
  static DateTime _parseServerDate(dynamic raw) {
    if (raw == null) return DateTime.now().toUtc();
    if (raw is! String || raw.isEmpty) return DateTime.now().toUtc();
    final hasTz = raw.endsWith('Z') ||
        RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(raw);
    final input = hasTz ? raw : '${raw}Z';
    try {
      return DateTime.parse(input).toUtc();
    } catch (_) {
      return DateTime.now().toUtc();
    }
  }

  factory CropModel.fromJson(Map<String, dynamic> json) {
    return CropModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      scientificName: (json['scientificName'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      growingPeriod: (json['growingPeriod'] is int)
          ? json['growingPeriod'] as int
          : int.tryParse('${json['growingPeriod'] ?? ''}') ?? 0,
      seasons: json['seasons'] is List
          ? (json['seasons'] as List)
              .whereType<Map>()
              .map((season) =>
                  Season.fromJson(Map<String, dynamic>.from(season)))
              .toList()
          : <Season>[],
      imageUrl: (json['imageUrl'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      createdAt: _parseServerDate(json['createdAt']),
      updatedAt: _parseServerDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'scientificName': scientificName,
      'description': description,
      'growingPeriod': growingPeriod,
      'seasons': seasons.map((season) => season.toJson()).toList(),
      'imageUrl': imageUrl,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

class Season {
  final String type;
  final int startMonth;
  final int endMonth;
  final String id;

  Season({
    required this.type,
    required this.startMonth,
    required this.endMonth,
    required this.id,
  });

  factory Season.fromJson(Map<String, dynamic> json) {
    return Season(
      type: json['type'] ?? '',
      startMonth: json['startMonth'] ?? 1,
      endMonth: json['endMonth'] ?? 12,
      id: json['_id'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'startMonth': startMonth,
      'endMonth': endMonth,
      '_id': id,
    };
  }
}
