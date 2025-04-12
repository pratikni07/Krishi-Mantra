import 'crop_model.dart';
import '../services/language_service.dart';

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

  // Cached translations
  String? _translatedGrowthStage;
  List<String>? _translatedTips;
  List<String>? _translatedNextMonthPreparation;

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

  // Get translated growth stage
  Future<String> getTranslatedGrowthStage() async {
    if (_translatedGrowthStage != null) return _translatedGrowthStage!;
    
    final languageService = await LanguageService.getInstance();
    _translatedGrowthStage = await languageService.translate(growthStage);
    return _translatedGrowthStage!;
  }

  // Get translated tips
  Future<List<String>> getTranslatedTips() async {
    if (_translatedTips != null) return _translatedTips!;
    
    final languageService = await LanguageService.getInstance();
    _translatedTips = await Future.wait(
      tips.map((tip) => languageService.translate(tip))
    );
    return _translatedTips!;
  }

  // Get translated next month preparation
  Future<List<String>> getTranslatedNextMonthPreparation() async {
    if (_translatedNextMonthPreparation != null) return _translatedNextMonthPreparation!;
    
    final languageService = await LanguageService.getInstance();
    _translatedNextMonthPreparation = await Future.wait(
      nextMonthPreparation.map((prep) => languageService.translate(prep))
    );
    return _translatedNextMonthPreparation!;
  }

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

  // Cached translations
  String? _translatedRainfall;
  String? _translatedHumidity;

  WeatherConsiderations({
    required this.idealTemperature,
    required this.rainfall,
    required this.humidity,
  });

  // Get translated rainfall
  Future<String> getTranslatedRainfall() async {
    if (_translatedRainfall != null) return _translatedRainfall!;
    
    final languageService = await LanguageService.getInstance();
    _translatedRainfall = await languageService.translate(rainfall);
    return _translatedRainfall!;
  }

  // Get translated humidity
  Future<String> getTranslatedHumidity() async {
    if (_translatedHumidity != null) return _translatedHumidity!;
    
    final languageService = await LanguageService.getInstance();
    _translatedHumidity = await languageService.translate(humidity);
    return _translatedHumidity!;
  }

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

  // Cached translations
  String? _translatedGrowth;
  List<String>? _translatedSigns;

  ExpectedOutcomes({required this.growth, required this.signs});

  // Get translated growth
  Future<String> getTranslatedGrowth() async {
    if (_translatedGrowth != null) return _translatedGrowth!;
    
    final languageService = await LanguageService.getInstance();
    _translatedGrowth = await languageService.translate(growth);
    return _translatedGrowth!;
  }

  // Get translated signs
  Future<List<String>> getTranslatedSigns() async {
    if (_translatedSigns != null) return _translatedSigns!;
    
    final languageService = await LanguageService.getInstance();
    _translatedSigns = await Future.wait(
      signs.map((sign) => languageService.translate(sign))
    );
    return _translatedSigns!;
  }

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

  // Cached translation
  String? _translatedInstructions;
  String? _translatedImportance;

  Activity({
    required this.timing,
    this.activityId,
    required this.instructions,
    required this.importance,
    required this.id,
  });

  // Get translated instructions
  Future<String> getTranslatedInstructions() async {
    if (_translatedInstructions != null) return _translatedInstructions!;
    
    final languageService = await LanguageService.getInstance();
    _translatedInstructions = await languageService.translate(instructions);
    return _translatedInstructions!;
  }

  // Get translated importance
  Future<String> getTranslatedImportance() async {
    if (_translatedImportance != null) return _translatedImportance!;
    
    final languageService = await LanguageService.getInstance();
    _translatedImportance = await languageService.translate(importance);
    return _translatedImportance!;
  }

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

  // Cached translation
  String? _translatedRecommendedTime;

  Timing({required this.week, required this.recommendedTime});

  // Get translated recommended time
  Future<String> getTranslatedRecommendedTime() async {
    if (_translatedRecommendedTime != null) return _translatedRecommendedTime!;
    
    final languageService = await LanguageService.getInstance();
    _translatedRecommendedTime = await languageService.translate(recommendedTime);
    return _translatedRecommendedTime!;
  }

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

  // Cached translations
  String? _translatedProblem;
  String? _translatedSolution;
  List<String>? _translatedPreventiveMeasures;

  PossibleIssue({
    required this.problem,
    required this.solution,
    required this.preventiveMeasures,
    required this.id,
  });

  // Get translated problem
  Future<String> getTranslatedProblem() async {
    if (_translatedProblem != null) return _translatedProblem!;
    
    final languageService = await LanguageService.getInstance();
    _translatedProblem = await languageService.translate(problem);
    return _translatedProblem!;
  }

  // Get translated solution
  Future<String> getTranslatedSolution() async {
    if (_translatedSolution != null) return _translatedSolution!;
    
    final languageService = await LanguageService.getInstance();
    _translatedSolution = await languageService.translate(solution);
    return _translatedSolution!;
  }

  // Get translated preventive measures
  Future<List<String>> getTranslatedPreventiveMeasures() async {
    if (_translatedPreventiveMeasures != null) return _translatedPreventiveMeasures!;
    
    final languageService = await LanguageService.getInstance();
    _translatedPreventiveMeasures = await Future.wait(
      preventiveMeasures.map((measure) => languageService.translate(measure))
    );
    return _translatedPreventiveMeasures!;
  }

  factory PossibleIssue.fromJson(Map<String, dynamic> json) {
    return PossibleIssue(
      problem: json['problem'],
      solution: json['solution'],
      preventiveMeasures: List<String>.from(json['preventiveMeasures']),
      id: json['_id'],
    );
  }
} 