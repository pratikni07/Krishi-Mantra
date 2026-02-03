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

  // Cached translations
  String? _translatedName;
  String? _translatedScientificName;
  String? _translatedDescription;

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
    if (_translatedName != null) return _translatedName!;

    final languageService = await LanguageService.getInstance();
    _translatedName = await languageService.translate(name);
    return _translatedName!;
  }

  // Get translated scientific name
  Future<String> getTranslatedScientificName() async {
    if (_translatedScientificName != null) return _translatedScientificName!;

    final languageService = await LanguageService.getInstance();
    _translatedScientificName = await languageService.translate(scientificName);
    return _translatedScientificName!;
  }

  // Get translated description
  Future<String> getTranslatedDescription() async {
    if (_translatedDescription != null) return _translatedDescription!;

    final languageService = await LanguageService.getInstance();
    _translatedDescription = await languageService.translate(description);
    return _translatedDescription!;
  }

  factory CropModel.fromJson(Map<String, dynamic> json) {
    return CropModel(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      scientificName: json['scientificName'] ?? '',
      description: json['description'] ?? '',
      growingPeriod: json['growingPeriod'] ?? 0,
      seasons: json['seasons'] != null
          ? (json['seasons'] as List)
              .map((season) => Season.fromJson(season))
              .toList()
          : [],
      imageUrl: json['imageUrl'] ?? '',
      status: json['status'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
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
