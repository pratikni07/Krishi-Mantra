import 'package:dio/dio.dart';
import '../models/product_model.dart';
import '../services/api_service.dart';

class ProductRepository {
  final ApiService _apiService;

  ProductRepository(this._apiService);

  Future<List<ProductModel>> getAllProducts() async {
    try {
      final response = await _apiService.get('/api/main/products');
      if (response.data['status'] == 'success') {
        final List<dynamic> data = response.data['data'] ?? [];
        return data.map((json) => ProductModel.fromJson(json)).where((product) {
          // Filter out products with null required fields
          return product.name != null && 
                 product.image != null && 
                 product.company.name != null && 
                 product.company.logo != null;
        }).toList();
      }
      throw Exception('Failed to fetch products: ${response.data['message'] ?? 'Unknown error'}');
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      rethrow;
    }
  }

  Future<ProductModel> getProductById(String id) async {
    try {
      final response = await _apiService.get('/api/main/products/$id');
      if (response.data['status'] == 'success') {
        final product = ProductModel.fromJson(response.data['data']);
        // Verify required fields are not null
        if (product.name == null || 
            product.image == null || 
            product.company.name == null || 
            product.company.logo == null) {
          throw Exception('Invalid product data: Missing required fields');
        }
        return product;
      }
      throw Exception('Failed to fetch product: ${response.data['message'] ?? 'Unknown error'}');
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      rethrow;
    }
  }
} 