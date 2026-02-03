import 'package:dio/dio.dart';
import '../models/company_model.dart';
import '../services/api_service.dart';

class CompanyRepository {
  final ApiService _apiService;

  // Cache keys for offline support
  static const String _companiesEndpoint = '/api/main/companies';
  static const String _companiesCacheKey = 'companies_all';

  CompanyRepository(this._apiService);

  Future<List<CompanyModel>> getAllCompanies() async {
    try {
      // Use caching with a long duration to serve content when offline
      final response = await _apiService.get(
        _companiesEndpoint,
        cacheDuration: const Duration(hours: 6),
      );

      if (response.data['status'] == 'success') {
        final List<dynamic> data = response.data['data'] ?? [];
        return data.map((json) => CompanyModel.fromJson(json)).toList();
      }
      throw Exception('Failed to fetch companies: ${response.data['message'] ?? 'Unknown error'}');
    } catch (e) {
      print('Error fetching companies: $e');

      // Try to get cached data if the request fails
      try {
        final cacheResponse = await _apiService.getCachedResponse(
          _companiesEndpoint,
          cacheKey: _companiesCacheKey,
        );

        if (cacheResponse != null && cacheResponse.data != null) {
          if (cacheResponse.data['status'] == 'success') {
            final List<dynamic> data = cacheResponse.data['data'] ?? [];
            return data.map((json) => CompanyModel.fromJson(json)).toList();
          }
        }
      } catch (cacheError) {
        print('Error fetching companies from cache: $cacheError');
      }

      // Return empty list when offline with no cache
      return [];
    }
  }

  Future<CompanyModel?> getCompanyById(String id) async {
    final cacheKey = 'company_$id';

    try {
      final response = await _apiService.get(
        '$_companiesEndpoint/$id',
        cacheDuration: const Duration(hours: 6),
      );

      if (response.data['status'] == 'success') {
        final data = response.data['data'];
        if (data == null) throw Exception('No company data found');
        return CompanyModel.fromJson(data);
      }
      throw Exception('Failed to fetch company: ${response.data['message'] ?? 'Unknown error'}');
    } catch (e) {
      print('Error fetching company $id: $e');

      // Try to get cached data if the request fails
      try {
        final cacheResponse = await _apiService.getCachedResponse(
          '$_companiesEndpoint/$id',
          cacheKey: cacheKey,
        );

        if (cacheResponse != null && cacheResponse.data != null) {
          if (cacheResponse.data['status'] == 'success') {
            final data = cacheResponse.data['data'];
            if (data != null) {
              return CompanyModel.fromJson(data);
            }
          }
        }
      } catch (cacheError) {
        print('Error fetching company from cache: $cacheError');
      }

      // Return null when offline with no cache
      return null;
    }
  }
}
