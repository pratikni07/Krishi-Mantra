// crop_repository.dart
import 'package:dio/dio.dart';
import '../models/crop_model.dart';
import '../services/api_service.dart';
import '../models/crop_calendar_model.dart';

class CropRepository {
  final ApiService _apiService;

  CropRepository(this._apiService);

  Future<List<CropModel>> getAllCrops() async {
    try {
      final response = await _apiService.get('/api/main/crop-calendar/crops');
      
      // Handle both array response and object with success property
      if (response.data is List) {
        // Direct array response
        final List<dynamic> data = response.data;
        return data.map((json) => CropModel.fromJson(json)).toList();
      } else if (response.data is Map) {
        // Response with success property
        if (response.data['success'] == true) {
          final List<dynamic> data = response.data['data'] ?? [];
          return data.map((json) => CropModel.fromJson(json)).toList();
        }
        throw Exception(
            'Failed to fetch crops: ${response.data['message'] ?? 'Unknown error'}');
      }
      
      throw Exception('Unexpected response format');
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      rethrow;
    }
  }

  Future<CropCalendarModel> getCropCalendar(String cropId, {int? month}) async {
    try {
      // Default to the current month so the calendar reflects "what's happening
      // now" rather than the previously hardcoded June.
      final int resolvedMonth = month ?? DateTime.now().month;
      final response = await _apiService
          .get('/api/main/crop-calendar/calendar/$cropId/$resolvedMonth');

      // Defensive parse — refuse to feed non-Map payloads to fromJson which
      // assumes a dynamic-keyed map. The previous code assumed any non-data
      // shape was the calendar itself and would explode inside fromJson with
      // a hard-to-debug type error if the gateway returned a plain string
      // (timeouts, 502 HTML pages, etc.).
      final raw = response.data;
      if (raw is! Map) {
        throw Exception('Unexpected crop calendar response format');
      }
      final asMap = Map<String, dynamic>.from(raw);

      if (asMap.containsKey('data')) {
        if (asMap['success'] == true) {
          final data = asMap['data'];
          if (data is! Map) throw Exception('No crop data found');
          return CropCalendarModel.fromJson(Map<String, dynamic>.from(data));
        }
        throw Exception(
            'Failed to fetch crop calendar: ${asMap['message'] ?? 'Unknown error'}');
      }

      // Direct response (no envelope) — only valid if it actually looks
      // like a calendar payload.
      return CropCalendarModel.fromJson(asMap);
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      rethrow;
    }
  }

  Future<List<CropModel>> searchCrops({
    required String search,
    required String season,
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final response = await _apiService.get(
        '/api/main/crop-calendar/search',
        queryParameters: {
          'search': search,
          'season': season,
          'page': page,
          'limit': limit,
        },
      );
      
      // Handle both formats
      if (response.data is List) {
        // Direct array response
        final List<dynamic> data = response.data;
        return data.map((json) => CropModel.fromJson(json)).toList();
      } else if (response.data is Map) {
        // Response with success property
        if (response.data['success'] == true) {
          final data = response.data['data'];
          if (data is Map && data.containsKey('crops')) {
            final List<dynamic> crops = data['crops'] ?? [];
            return crops.map((json) => CropModel.fromJson(json)).toList();
          } else if (data is List) {
            return data.map((json) => CropModel.fromJson(json)).toList();
          }
        }
        throw Exception(
            'Failed to search crops: ${response.data['message'] ?? 'Unknown error'}');
      }
      
      throw Exception('Unexpected response format');
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      rethrow;
    }
  }
}
