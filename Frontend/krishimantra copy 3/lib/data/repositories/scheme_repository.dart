import 'package:dio/dio.dart';
import '../services/api_service.dart';
import '../models/scheme_model.dart';

class SchemeRepository {
  final ApiService _apiService;

  SchemeRepository(this._apiService);

  Future<List<SchemeModel>> getAllSchemes() async {
    try {
      final response = await _apiService.get('/api/main/schemes/schemes');
      if (response.data != null) {
        final List<dynamic> data = response.data;
        return data.map((json) => SchemeModel.fromJson(json)).toList();
      }
      throw Exception('Failed to fetch schemes: No data received');
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      rethrow;
    }
  }

  Future<SchemeModel> getSchemeById(String id) async {
    try {
      final response = await _apiService.get('/api/main/schemes/schemes/$id');
      if (response.data != null) {
        return SchemeModel.fromJson(response.data);
      }
      throw Exception('Failed to fetch scheme: No data received');
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      rethrow;
    }
  }
}
