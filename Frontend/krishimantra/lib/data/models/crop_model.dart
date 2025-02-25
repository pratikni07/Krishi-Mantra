// crop_model.dart
import 'dart:convert';

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

  factory CropModel.fromJson(Map<String, dynamic> json) {
    return CropModel(
      id: json['_id'] as String,
      name: json['name'] as String,
      scientificName: json['scientificName'] as String,
      description: json['description'] as String,
      growingPeriod: json['growingPeriod'] as int,
      seasons: (json['seasons'] as List)
          .map((season) => Season.fromJson(season))
          .toList(),
      imageUrl: json['imageUrl'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
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
      type: json['type'] as String,
      startMonth: json['startMonth'] as int,
      endMonth: json['endMonth'] as int,
      id: json['_id'] as String,
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
