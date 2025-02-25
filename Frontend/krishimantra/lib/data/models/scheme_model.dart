class SchemeModel {
  final String id;
  final String title;
  final String category;
  final String description;
  final List<String> eligibility;
  final List<String> benefits;
  final String lastDate;
  final String status;
  final String applicationUrl;
  final List<String> documentRequired;

  SchemeModel({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.eligibility,
    required this.benefits,
    required this.lastDate,
    required this.status,
    required this.applicationUrl,
    required this.documentRequired,
  });

  factory SchemeModel.fromJson(Map<String, dynamic> json) {
    return SchemeModel(
      id: json['_id'] ?? '',
      title: json['title'] ?? '',
      category: json['category'] ?? '',
      description: json['description'] ?? '',
      eligibility: List<String>.from(json['eligibility'] ?? []),
      benefits: List<String>.from(json['benefits'] ?? []),
      lastDate: json['lastDate'] ?? '',
      status: json['status'] ?? '',
      applicationUrl: json['applicationUrl'] ?? '',
      documentRequired: List<String>.from(json['documentRequired'] ?? []),
    );
  }
}