import 'package:dio/dio.dart';
import '../models/company_model.dart';
import '../services/api_service.dart';

class CompanyRepository {
  final ApiService _apiService;

  CompanyRepository(this._apiService);

  Future<List<CompanyModel>> getAllCompanies() async {
    try {
      final response = await _apiService.get('/api/main/companies');
      if (response.data['status'] == 'success') {
        final List<dynamic> data = response.data['data'] ?? [];
        return data.map((json) => CompanyModel.fromJson(json)).toList();
      }
      throw Exception('Failed to fetch companies: ${response.data['message'] ?? 'Unknown error'}');
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      rethrow;
    }
  }

  Future<CompanyModel> getCompanyById(String id) async {
    try {
      final response = await _apiService.get('/api/main/companies/$id');
      if (response.data['status'] == 'success') {
        final data = response.data['data'];
        if (data == null) throw Exception('No company data found');
        return CompanyModel.fromJson(data);
      }
      throw Exception('Failed to fetch company: ${response.data['message'] ?? 'Unknown error'}');
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      rethrow;
    }
  }
}
