// models/api_response.dart
import 'package:krishi_mantra/screens/features/company/models/modal.dart';

class ApiResponse {
  final String status;
  final int results;
  final List<Company> data;

  ApiResponse({
    required this.status,
    required this.results,
    required this.data,
  });

  factory ApiResponse.fromJson(Map<String, dynamic> json) {
    return ApiResponse(
      status: json['status'],
      results: json['results'],
      data: (json['data'] as List)
          .map((company) => Company.fromJson(company))
          .toList(),
    );
  }
}
