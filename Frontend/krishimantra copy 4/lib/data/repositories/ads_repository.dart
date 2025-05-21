import '../../core/utils/api_helper.dart';
import '../services/api_service.dart';

class AdsRepository {
  final ApiService _apiService;

  AdsRepository(this._apiService);

  Future<List<dynamic>> getHomeScreenAds() async {
    try {
      final response = await _apiService.get('/api/main/ads/home-screen-ads');
      return ApiHelper.handleResponse(response);
    } catch (error) {
      throw ApiHelper.handleError(error);
    }
  }

  Future<dynamic> getHomeScreenAdById(String id) async {
    try {
      final response =
          await _apiService.get('/api/main/ads/home-screen-ads/$id');
      return ApiHelper.handleResponse(response);
    } catch (error) {
      throw ApiHelper.handleError(error);
    }
  }

  Future<List<dynamic>> getSplashAds() async {
    try {
      final response = await _apiService.get('/api/main/ads/splash-modal');
      return ApiHelper.handleResponse(response);
    } catch (error) {
      throw ApiHelper.handleError(error);
    }
  }

  Future<List<dynamic>> getHomeScreenSlider() async {
    try {
      final response = await _apiService.get('/api/main/ads/home-ads');
      final List<dynamic> ads = ApiHelper.handleResponse(response);
      // Sort ads by priority
      ads.sort((a, b) => (a['prority'] as int).compareTo(b['prority'] as int));
      return ads;
    } catch (error) {
      throw ApiHelper.handleError(error);
    }
  }

  Future<List<dynamic>> getFeedAds() async {
    try {
      final response = await _apiService.get('/api/main/ads/feed-ads');
      return ApiHelper.handleResponse(response);
    } catch (error) {
      throw ApiHelper.handleError(error);
    }
  }

  Future<List<dynamic>> getReelAds() async {
    try {
      final response = await _apiService.get('/api/main/ads/reel-ads');
      return ApiHelper.handleResponse(response);
    } catch (error) {
      throw ApiHelper.handleError(error);
    }
  }

  Future<void> trackReelAdView(String adId, String userId, int duration) async {
    try {
      await _apiService.post('/api/main/ads/reel-ads/$adId/view',
          data: {'userId': userId, 'duration': duration});
    } catch (error) {
      throw ApiHelper.handleError(error);
    }
  }
}
