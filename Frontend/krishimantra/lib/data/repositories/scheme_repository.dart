import 'package:dio/dio.dart';
import '../services/api_service.dart';
import '../models/scheme_model.dart';

class SchemeRepository {
  final ApiService _apiService;

  // Cache keys for offline support
  static const String _schemesEndpoint = '/api/main/schemes/schemes';
  static const String _schemesCacheKey = 'schemes_all';

  SchemeRepository(this._apiService);

  Future<List<SchemeModel>> getAllSchemes() async {
    try {
      // Use caching with a long duration to serve content when offline
      final response = await _apiService.get(
        _schemesEndpoint,
        cacheDuration: const Duration(hours: 6),
      );

      if (response.data != null) {
        final List<dynamic> data = response.data;
        return data.map((json) => SchemeModel.fromJson(json)).toList();
      }
      throw Exception('Failed to fetch schemes: No data received');
    } catch (e) {
      print('Error fetching schemes: $e');

      // Try to get cached data if the request fails
      try {
        final cacheResponse = await _apiService.getCachedResponse(
          _schemesEndpoint,
          cacheKey: _schemesCacheKey,
        );

        if (cacheResponse != null && cacheResponse.data != null) {
          final List<dynamic> data = cacheResponse.data;
          return data.map((json) => SchemeModel.fromJson(json)).toList();
        }
      } catch (cacheError) {
        print('Error fetching schemes from cache: $cacheError');
      }

      // Return empty list when offline with no cache
      return [];
    }
  }

  Future<SchemeModel?> getSchemeById(String id) async {
    final cacheKey = 'scheme_$id';

    try {
      final response = await _apiService.get(
        '$_schemesEndpoint/$id',
        cacheDuration: const Duration(hours: 6),
      );

      if (response.data != null) {
        return SchemeModel.fromJson(response.data);
      }
      throw Exception('Failed to fetch scheme: No data received');
    } catch (e) {
      print('Error fetching scheme $id: $e');

      // Try to get cached data if the request fails
      try {
        final cacheResponse = await _apiService.getCachedResponse(
          '$_schemesEndpoint/$id',
          cacheKey: cacheKey,
        );

        if (cacheResponse != null && cacheResponse.data != null) {
          return SchemeModel.fromJson(cacheResponse.data);
        }
      } catch (cacheError) {
        print('Error fetching scheme from cache: $cacheError');
      }

      // Return null when offline with no cache
      return null;
    }
  }
}
