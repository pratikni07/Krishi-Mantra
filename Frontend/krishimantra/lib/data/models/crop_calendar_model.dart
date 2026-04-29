import 'crop_model.dart';
import '../services/language_service.dart';

/// Tiny helper that pairs a cached translation with the LanguageService
/// version it was produced under, and re-translates when the version is
/// stale. Centralised so each model class doesn't have to repeat the
/// version-check boilerplate around every cached field.
class _VersionedTranslation {
  String? _value;
  int? _version;

  Future<String> resolve(LanguageService svc, String source) async {
    if (_value != null && _version == svc.languageVersion) return _value!;
    final translated = await svc.translate(source);
    _value = translated;
    _version = svc.languageVersion;
    return translated;
  }
}

/// List variant — translates the whole batch at once and invalidates on
/// language change. Backed by `translateBatch` so a list of N strings does
/// at most N unique-string requests (often far fewer with duplicates).
class _VersionedTranslationList {
  List<String>? _value;
  int? _version;

  Future<List<String>> resolve(
      LanguageService svc, List<String> source) async {
    if (_value != null && _version == svc.languageVersion) return _value!;
    final translated = await svc.translateBatch(source);
    _value = translated;
    _version = svc.languageVersion;
    return translated;
  }
}

class CropCalendarModel {
  final WeatherConsiderations weatherConsiderations;
  final ExpectedOutcomes expectedOutcomes;
  final String id;
  final CropModel cropId;
  final int month;
  final String growthStage;
  final List<Activity> activities;
  final List<PossibleIssue> possibleIssues;
  final List<String> tips;
  final List<String> nextMonthPreparation;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Cached translations. Each entry pairs the cached value with the
  // LanguageService version it was translated under, so a runtime language
  // switch invalidates them automatically.
  final _growthStageCache = _VersionedTranslation();
  final _tipsCache = _VersionedTranslationList();
  final _nextMonthPrepCache = _VersionedTranslationList();

  CropCalendarModel({
    required this.weatherConsiderations,
    required this.expectedOutcomes,
    required this.id,
    required this.cropId,
    required this.month,
    required this.growthStage,
    required this.activities,
    required this.possibleIssues,
    required this.tips,
    required this.nextMonthPreparation,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  Future<String> getTranslatedGrowthStage() async =>
      _growthStageCache.resolve(await LanguageService.getInstance(), growthStage);

  Future<List<String>> getTranslatedTips() async =>
      _tipsCache.resolve(await LanguageService.getInstance(), tips);

  Future<List<String>> getTranslatedNextMonthPreparation() async =>
      _nextMonthPrepCache.resolve(
          await LanguageService.getInstance(), nextMonthPreparation);

  factory CropCalendarModel.fromJson(Map<String, dynamic> json) {
    return CropCalendarModel(
      weatherConsiderations: WeatherConsiderations.fromJson(json['weatherConsiderations']),
      expectedOutcomes: ExpectedOutcomes.fromJson(json['expectedOutcomes']),
      id: json['_id'],
      cropId: CropModel.fromJson(json['cropId']),
      month: json['month'],
      growthStage: json['growthStage'],
      activities: (json['activities'] as List).map((e) => Activity.fromJson(e)).toList(),
      possibleIssues: (json['possibleIssues'] as List).map((e) => PossibleIssue.fromJson(e)).toList(),
      tips: List<String>.from(json['tips']),
      nextMonthPreparation: List<String>.from(json['nextMonthPreparation']),
      status: json['status'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }
}

class WeatherConsiderations {
  final IdealTemperature idealTemperature;
  final String rainfall;
  final String humidity;

  // Cached translations — invalidated on language switch via _Versioned*.
  final _rainfallCache = _VersionedTranslation();
  final _humidityCache = _VersionedTranslation();

  WeatherConsiderations({
    required this.idealTemperature,
    required this.rainfall,
    required this.humidity,
  });

  Future<String> getTranslatedRainfall() async =>
      _rainfallCache.resolve(await LanguageService.getInstance(), rainfall);

  Future<String> getTranslatedHumidity() async =>
      _humidityCache.resolve(await LanguageService.getInstance(), humidity);

  factory WeatherConsiderations.fromJson(Map<String, dynamic> json) {
    return WeatherConsiderations(
      idealTemperature: IdealTemperature.fromJson(json['idealTemperature']),
      rainfall: json['rainfall'],
      humidity: json['humidity'],
    );
  }
}

class IdealTemperature {
  final int min;
  final int max;

  IdealTemperature({required this.min, required this.max});

  factory IdealTemperature.fromJson(Map<String, dynamic> json) {
    return IdealTemperature(
      min: json['min'],
      max: json['max'],
    );
  }
}

class ExpectedOutcomes {
  final String growth;
  final List<String> signs;

  // Cached translations — invalidated on language switch via _Versioned*.
  final _growthCache = _VersionedTranslation();
  final _signsCache = _VersionedTranslationList();

  ExpectedOutcomes({required this.growth, required this.signs});

  Future<String> getTranslatedGrowth() async =>
      _growthCache.resolve(await LanguageService.getInstance(), growth);

  Future<List<String>> getTranslatedSigns() async =>
      _signsCache.resolve(await LanguageService.getInstance(), signs);

  factory ExpectedOutcomes.fromJson(Map<String, dynamic> json) {
    return ExpectedOutcomes(
      growth: json['growth'],
      signs: List<String>.from(json['signs']),
    );
  }
}

class Activity {
  final Timing timing;
  final ActivityId? activityId; // Change from String? to ActivityId?
  final String instructions;
  final String importance;
  final String id;

  // Cached translations — invalidated on language switch via _Versioned*.
  final _instructionsCache = _VersionedTranslation();
  final _importanceCache = _VersionedTranslation();

  Activity({
    required this.timing,
    this.activityId,
    required this.instructions,
    required this.importance,
    required this.id,
  });

  Future<String> getTranslatedInstructions() async =>
      _instructionsCache.resolve(
          await LanguageService.getInstance(), instructions);

  Future<String> getTranslatedImportance() async =>
      _importanceCache.resolve(
          await LanguageService.getInstance(), importance);

  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      timing: Timing.fromJson(json['timing']),
      activityId: json['activityId'] != null ? ActivityId.fromJson(json['activityId']) : null,
      instructions: json['instructions'],
      importance: json['importance'],
      id: json['_id'],
    );
  }
}

class ActivityId {
  final String id;
  final String name;

  ActivityId({
    required this.id,
    required this.name,
  });

  factory ActivityId.fromJson(Map<String, dynamic> json) {
    return ActivityId(
      id: json['_id'],
      name: json['name'],
    );
  }
}

class Timing {
  final int week;
  final String recommendedTime;

  // Cached translation — invalidated on language switch via _Versioned*.
  final _recommendedTimeCache = _VersionedTranslation();

  Timing({required this.week, required this.recommendedTime});

  Future<String> getTranslatedRecommendedTime() async =>
      _recommendedTimeCache.resolve(
          await LanguageService.getInstance(), recommendedTime);

  factory Timing.fromJson(Map<String, dynamic> json) {
    return Timing(
      week: json['week'],
      recommendedTime: json['recommendedTime'],
    );
  }
}

class PossibleIssue {
  final String problem;
  final String solution;
  final List<String> preventiveMeasures;
  final String id;

  // Cached translations — invalidated on language switch via _Versioned*.
  final _problemCache = _VersionedTranslation();
  final _solutionCache = _VersionedTranslation();
  final _preventiveMeasuresCache = _VersionedTranslationList();

  PossibleIssue({
    required this.problem,
    required this.solution,
    required this.preventiveMeasures,
    required this.id,
  });

  Future<String> getTranslatedProblem() async =>
      _problemCache.resolve(await LanguageService.getInstance(), problem);

  Future<String> getTranslatedSolution() async =>
      _solutionCache.resolve(await LanguageService.getInstance(), solution);

  Future<List<String>> getTranslatedPreventiveMeasures() async =>
      _preventiveMeasuresCache.resolve(
          await LanguageService.getInstance(), preventiveMeasures);

  factory PossibleIssue.fromJson(Map<String, dynamic> json) {
    return PossibleIssue(
      problem: json['problem'],
      solution: json['solution'],
      preventiveMeasures: List<String>.from(json['preventiveMeasures']),
      id: json['_id'],
    );
  }
} 