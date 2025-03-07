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
      if (response.data['success'] == true) {
        final List<dynamic> data = response.data['data'] ?? [];
        return data.map((json) => CropModel.fromJson(json)).toList();
      }
      throw Exception(
          'Failed to fetch crops: ${response.data['message'] ?? 'Unknown error'}');
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      rethrow;
    }
  }

  Future<CropCalendarModel> getCropCalendar(String cropId) async {
    try {
      final response =
          await _apiService.get('/api/main/crop-calendar/calendar/$cropId/6');
      if (response.data['success'] == true) {
        final data = response.data['data'];
        if (data == null) throw Exception('No crop data found');
        return CropCalendarModel.fromJson(data);
      }
      throw Exception(
          'Failed to fetch crop calendar: ${response.data['message'] ?? 'Unknown error'}');
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
      if (response.data['success'] == true) {
        final List<dynamic> data = response.data['data']['crops'] ?? [];
        return data.map((json) => CropModel.fromJson(json)).toList();
      }
      throw Exception(
          'Failed to search crops: ${response.data['message'] ?? 'Unknown error'}');
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      rethrow;
    }
  }
}
