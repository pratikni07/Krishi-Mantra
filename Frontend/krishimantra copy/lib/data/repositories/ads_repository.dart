import 'package:dio/dio.dart';
import '../../core/utils/api_helper.dart';
import '../services/api_service.dart';

class AdsRepository {
  final ApiService _apiService;

  AdsRepository(this._apiService);

  Future<List<dynamic>> getHomeScreenAds() async {
    try {
      final response = await _apiService.get('/ads/home-screen-ads');
      return ApiHelper.handleResponse(response);
    } catch (error) {
      throw ApiHelper.handleError(error);
    }
  }

  Future<dynamic> getHomeScreenAdById(String id) async {
    try {
      final response = await _apiService.get('/ads/home-screen-ads/$id');
      return ApiHelper.handleResponse(response);
    } catch (error) {
      throw ApiHelper.handleError(error);
    }
  }

  Future<List<dynamic>> getSplashAds() async {
    try {
      final response = await _apiService.get('/ads/splash-modal');
      return ApiHelper.handleResponse(response);
    } catch (error) {
      throw ApiHelper.handleError(error);
    }
  }
}
