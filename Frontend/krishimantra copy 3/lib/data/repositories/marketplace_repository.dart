import '../../core/utils/api_helper.dart';
import '../services/UserService.dart';
import '../services/api_service.dart';


class MarketplaceRepository {
  final ApiService _apiService;
  final UserService _userService;

  MarketplaceRepository(this._apiService, this._userService);

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
      final response =
          await _apiService.post('/api/main/marketplace', data: data);
      return ApiHelper.handleResponse(response);
    } catch (error) {
      throw ApiHelper.handleError(error);
    }
  }

  Future<Map<String, dynamic>> getComments(String productId, int page) async {
    try {
      final response = await _apiService.get(
        '/api/main/marketplace/$productId/comments',
        queryParameters: {'page': page, 'limit': 5},
      );
      return response.data;
    } catch (error) {
      throw error;
    }
  }

  Future<Map<String, dynamic>> addComment(String productId, String text) async {
    try {
      final userId = await _userService.getUserId();

      final response = await _apiService.post(
        '/api/main/marketplace/$productId/comment',
        data: {
          'userId': userId,
          'text': text,
        },
      );
      return response.data;
    } catch (error) {
      throw error;
    }
  }

  Future<Map<String, dynamic>> addReply(
      String productId, String commentId, String text) async {
    try {
      final userId = await _userService.getUserId();

      final response = await _apiService.post(
        '/api/main/marketplace/$productId/comment/$commentId/reply',
        data: {
          'userId': userId,
          'text': text,
        },
      );
      return response.data;
    } catch (error) {
      throw error;
    }
  }

  Future<Map<String, dynamic>> getProductDetails(String productId) async {
    try {
      final response =
          await _apiService.get('/api/main/marketplace/$productId');
      return ApiHelper.handleResponse(response);
    } catch (error) {
      throw ApiHelper.handleError(error);
    }
  }

  Future<Map<String, dynamic>> searchProducts({
    String? keyword,
    String? category,
    double? minPrice,
    double? maxPrice,
    String? condition,
    List<String>? tags,
  }) async {
    try {
      final queryParams = {
        if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
        if (category != null && category.isNotEmpty) 'category': category,
        if (minPrice != null) 'minPrice': minPrice.toString(),
        if (maxPrice != null) 'maxPrice': maxPrice.toString(),
        if (condition != null && condition.isNotEmpty) 'condition': condition,
        if (tags != null && tags.isNotEmpty) 'tags': tags.join(','),
      };

      final response = await _apiService.get(
        '/api/main/marketplace/search',
        queryParameters: queryParams,
      );
      return response.data;
    } catch (error) {
      throw error;
    }
  }
}
