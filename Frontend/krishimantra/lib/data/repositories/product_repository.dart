// ignore_for_file: unnecessary_null_comparison

import 'package:dio/dio.dart';
import '../models/product_model.dart';
import '../services/api_service.dart';
import '../../core/constants/api_constants.dart';
import '../../core/utils/language_helper.dart';

class ProductRepository {
  final ApiService _apiService;

  // Cache keys for offline support
  static const String _productsEndpoint = '/api/main/products';
  static const String _productsCacheKey = 'products_all';

  ProductRepository(this._apiService);

  /// Get all products with translation support and offline caching
  Future<List<ProductModel>> getAllProducts() async {
    try {
      // Use caching with a long duration to serve content when offline
      final response = await _apiService.get(
        _productsEndpoint,
        cacheDuration: const Duration(hours: 6),
      );

      final List<dynamic> productsJson = response.data['data'] ?? [];
      final List<ProductModel> products = [];

      // Parse each product individually to handle errors gracefully
      for (final json in productsJson) {
        try {
          products.add(ProductModel.fromJson(json));
        } catch (e) {
          print('Error parsing product: $e');
          // Skip invalid products
          continue;
        }
      }

      // Apply translations to products (skip if list is empty)
      if (products.isEmpty) return products;

      try {
        return await _translateProducts(products);
      } catch (e) {
        print('Error translating products: $e');
        // Return untranslated products if translation fails
        return products;
      }
    } catch (e) {
      print('Error fetching products: $e');

      // Try to get cached data if the request fails
      try {
        final cacheResponse = await _apiService.getCachedResponse(
          _productsEndpoint,
          cacheKey: _productsCacheKey,
        );

        if (cacheResponse != null && cacheResponse.data != null) {
          final List<dynamic> productsJson = cacheResponse.data['data'] ?? [];
          final List<ProductModel> products =
              productsJson.map((json) => ProductModel.fromJson(json)).toList();

          // Apply translations to products
          return await _translateProducts(products);
        }
      } catch (cacheError) {
        print('Error fetching products from cache: $cacheError');
      }

      // Return empty list when offline with no cache
      return [];
    }
  }

  /// Get a product by ID with translation support and offline caching
  Future<ProductModel?> getProductById(String id) async {
    final cacheKey = 'product_$id';

    try {
      final response = await _apiService.get(
        '$_productsEndpoint/$id',
        cacheDuration: const Duration(hours: 6),
      );

      final productJson = response.data['data'];
      if (productJson == null) {
        throw Exception('Product not found');
      }

      final product = ProductModel.fromJson(productJson);

      // Apply translation to the single product
      return await _translateProduct(product);
    } catch (e) {
      print('Error fetching product $id: $e');

      // Try to get cached data if the request fails
      try {
        final cacheResponse = await _apiService.getCachedResponse(
          '$_productsEndpoint/$id',
          cacheKey: cacheKey,
        );

        if (cacheResponse != null && cacheResponse.data != null) {
          final productJson = cacheResponse.data['data'];
          if (productJson != null) {
            final product = ProductModel.fromJson(productJson);
            return await _translateProduct(product);
          }
        }
      } catch (cacheError) {
        print('Error fetching product from cache: $cacheError');
      }

      // Return null when offline with no cache
      return null;
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

    // Convert back to model objects safely
    final List<ProductModel> translatedProducts = [];
    for (final json in List<Map<String, dynamic>>.from(translatedJson)) {
      try {
        translatedProducts.add(ProductModel.fromJson(json));
      } catch (e) {
        print('Error parsing translated product: $e');
        // Skip invalid products
        continue;
      }
    }
    return translatedProducts;
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
