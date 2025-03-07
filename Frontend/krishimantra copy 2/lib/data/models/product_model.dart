import 'crop_model.dart';

class ProductModel {
  final String id;
  final String name;
  final String image;
  final String usage;
  final CompanyModel company;
  final CropModel usedFor;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProductModel({
    required this.id,
    required this.name,
    required this.image,
    required this.usage,
    required this.company,
    required this.usedFor,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      image: json['image'] ?? '',
      usage: json['usage'] ?? '',
      company: CompanyModel.fromJson(json['company'] ?? {}),
      usedFor: CropModel.fromJson(json['usedFor'] ?? {}),
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}

class CompanyModel {
  final String id;
  final String name;
  final String logo;

  CompanyModel({
    required this.id,
    required this.name,
    required this.logo,
  });

  factory CompanyModel.fromJson(Map<String, dynamic> json) {
    return CompanyModel(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      logo: json['logo'] ?? '',
    );
  }
} 