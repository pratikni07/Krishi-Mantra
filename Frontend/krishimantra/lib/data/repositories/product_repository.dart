// ignore_for_file: unnecessary_null_comparison

import 'package:dio/dio.dart';
import '../models/product_model.dart';
import '../services/api_service.dart';
import '../../core/constants/api_constants.dart';
import '../../core/utils/language_helper.dart';

class ProductRepository {
  final ApiService _apiService;

  ProductRepository(this._apiService);

  /// Get all products with translation support
  Future<List<ProductModel>> getAllProducts() async {
    try {
      final response = await _apiService.get('/api/main/products');
      final List<dynamic> productsJson = response.data['data'] ?? [];
      final List<ProductModel> products =
          productsJson.map((json) => ProductModel.fromJson(json)).toList();

      // Apply translations to products
      return await _translateProducts(products);
    } catch (e) {
      throw Exception('Failed to load products: $e');
    }
  }

  /// Get a product by ID with translation support
  Future<ProductModel> getProductById(String id) async {
    try {
      final response = await _apiService.get('/api/main/products/$id');
      final productJson = response.data['data'];
      if (productJson == null) {
        throw Exception('Product not found');
      }

      final product = ProductModel.fromJson(productJson);

      // Apply translation to the single product
      return await _translateProduct(product);
    } catch (e) {
      throw Exception('Failed to load product: $e');
    }
  }

  /// Translate a list of products
  Future<List<ProductModel>> _translateProducts(
      List<ProductModel> products) async {
    // Fields that need translation
    const fieldsToTranslate = [
      'name',
      'description',
      'category',
      'usage',
    ];

    final List<Map<String, dynamic>> productsJson =
        products.map((p) => p.toJson()).toList();

    // Use the language helper to translate all products at once
    final translatedJson = await LanguageHelper.translateApiResponse(
        productsJson,
        fieldsToTranslate: fieldsToTranslate);

    // Convert back to model objects
    return List<Map<String, dynamic>>.from(translatedJson)
        .map((json) => ProductModel.fromJson(json))
        .toList();
  }

  /// Translate a single product
  Future<ProductModel> _translateProduct(ProductModel product) async {
    // Fields that need translation
    const fieldsToTranslate = [
      'name',
      'description',
      'category',
      'usage',
    ];

    final productJson = product.toJson();

    // Translate the product
    final translatedJson = await LanguageHelper.translateApiResponse(
        productJson,
        fieldsToTranslate: fieldsToTranslate);

    // Convert back to model object
    return ProductModel.fromJson(translatedJson);
  }
}
