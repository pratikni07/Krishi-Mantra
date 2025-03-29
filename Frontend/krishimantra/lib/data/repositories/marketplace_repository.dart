import '../../core/utils/api_helper.dart';
import '../services/api_service.dart';

class MarketplaceRepository {
  final ApiService _apiService;

  MarketplaceRepository(this._apiService);

  Future<List<dynamic>> getMarketplaceProducts() async {
    try {
      final response = await _apiService.get('/api/main/marketplace');
      return ApiHelper.handleResponse(response)['data'];
    } catch (error) {
      throw ApiHelper.handleError(error);
    }
  }

  Future<dynamic> getMarketplaceProductById(String id) async {
    try {
      final response = await _apiService.get('/api/main/marketplace/$id');
      return ApiHelper.handleResponse(response)['data'];
    } catch (error) {
      throw ApiHelper.handleError(error);
    }
  }

  Future<dynamic> addMarketplaceProduct(Map<String, dynamic> data) async {
    try {
      final response = await _apiService.post('/api/main/marketplace', data: data);
      return ApiHelper.handleResponse(response);
    } catch (error) {
      throw ApiHelper.handleError(error);
    }
  }

  Future<Map<String, dynamic>> getProductComments(String productId, int page) async {
    try {
      final response = await _apiService.get('/api/main/marketplace/$productId/comments?page=$page');
      return ApiHelper.handleResponse(response);
    } catch (error) {
      throw ApiHelper.handleError(error);
    }
  }

  Future<Map<String, dynamic>> addComment(String productId, String text) async {
    try {
      final response = await _apiService.post(
        '/api/main/marketplace/$productId/comment',
        data: {'text': text},
      );
      return ApiHelper.handleResponse(response);
    } catch (error) {
      throw ApiHelper.handleError(error);
    }
  }

  Future<Map<String, dynamic>> addReply(String productId, String commentId, String text) async {
    try {
      final response = await _apiService.post(
        '/api/main/marketplace/$productId/comment/$commentId/reply',
        data: {'text': text},
      );
      return ApiHelper.handleResponse(response);
    } catch (error) {
      throw ApiHelper.handleError(error);
    }
  }

  Future<Map<String, dynamic>> getProductDetails(String productId) async {
    try {
      final response = await _apiService.get('/api/main/marketplace/$productId');
      return ApiHelper.handleResponse(response);
    } catch (error) {
      throw ApiHelper.handleError(error);
    }
  }
} 