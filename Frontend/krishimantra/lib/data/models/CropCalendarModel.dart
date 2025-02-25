// lib/data/models/crop_calendar_model.dart

class CropCalendarModel {
  final WeatherConsiderations weatherConsiderations;
  final ExpectedOutcomes expectedOutcomes;
  final String id;
  final CropId cropId;
  final int month;
  final String growthStage;
  final List<Activity> activities;
  final List<PossibleIssue> possibleIssues;
  final List<String> tips;
  final List<String> nextMonthPreparation;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

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

  factory CropCalendarModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? json; // Handle both direct and nested response
    return CropCalendarModel(
      weatherConsiderations:
          WeatherConsiderations.fromJson(data['weatherConsiderations']),
      expectedOutcomes: ExpectedOutcomes.fromJson(data['expectedOutcomes']),
      id: data['_id'],
      cropId: CropId.fromJson(data['cropId']),
      month: data['month'],
      growthStage: data['growthStage'],
      activities: (data['activities'] as List)
          .map((e) => Activity.fromJson(e))
          .toList(),
      possibleIssues: (data['possibleIssues'] as List)
          .map((e) => PossibleIssue.fromJson(e))
          .toList(),
      tips: List<String>.from(data['tips']),
      nextMonthPreparation: List<String>.from(data['nextMonthPreparation']),
      status: data['status'],
      createdAt: DateTime.parse(data['createdAt']),
      updatedAt: DateTime.parse(data['updatedAt']),
    );
  }
}

class CropId {
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

  CropId({
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

  factory CropId.fromJson(Map<String, dynamic> json) {
    return CropId(
      id: json['_id'],
      name: json['name'],
      scientificName: json['scientificName'],
      description: json['description'],
      growingPeriod: json['growingPeriod'],
      seasons:
          (json['seasons'] as List).map((e) => Season.fromJson(e)).toList(),
      imageUrl: json['imageUrl'],
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

  WeatherConsiderations({
    required this.idealTemperature,
    required this.rainfall,
    required this.humidity,
  });

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

  IdealTemperature({
    required this.min,
    required this.max,
  });

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

  ExpectedOutcomes({
    required this.growth,
    required this.signs,
  });

  factory ExpectedOutcomes.fromJson(Map<String, dynamic> json) {
    return ExpectedOutcomes(
      growth: json['growth'],
      signs: List<String>.from(json['signs']),
    );
  }
}

class Activity {
  final Timing timing;
  final String? activityId;
  final String instructions;
  final String importance;
  final String id;

  Activity({
    required this.timing,
    this.activityId,
    required this.instructions,
    required this.importance,
    required this.id,
  });

  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      timing: Timing.fromJson(json['timing']),
      activityId: json['activityId'],
      instructions: json['instructions'],
      importance: json['importance'],
      id: json['_id'],
    );
  }
}

class Timing {
  final int week;
  final String recommendedTime;

  Timing({
    required this.week,
    required this.recommendedTime,
  });

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

  PossibleIssue({
    required this.problem,
    required this.solution,
    required this.preventiveMeasures,
    required this.id,
  });

  factory PossibleIssue.fromJson(Map<String, dynamic> json) {
    return PossibleIssue(
      problem: json['problem'],
      solution: json['solution'],
      preventiveMeasures: List<String>.from(json['preventiveMeasures']),
      id: json['_id'],
    );
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
      type: json['type'],
      startMonth: json['startMonth'],
      endMonth: json['endMonth'],
      id: json['_id'],
    );
  }
}
