// ignore_for_file: avoid_print

import 'package:dio/dio.dart';
import '../../core/constants/api_constants.dart';

class ApiService {
  final Dio _dio;

  ApiService(this._dio) {
    _dio.options.baseUrl = ApiConstants.BASE_URL;
    _dio.options.connectTimeout = const Duration(seconds: 15);
    _dio.options.receiveTimeout = const Duration(seconds: 10);

    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (obj) => print('🌐 Dio: $obj'),
    ));
  }

  Future<Response> get(String path,
      {Map<String, dynamic>? queryParameters}) async {
    try {
      return await _dio.get(path, queryParameters: queryParameters);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> post(String path, {dynamic data}) async {
    try {
      final response = await _dio.post(path, data: data);
      if (response.data == null) {
        throw Exception('Received null response data');
      }
      return response;
    } catch (e, stackTrace) {
      throw _handleError(e);
    }
  }

  Future<Response> put(String path, {dynamic data}) async {
    try {
      final response = await _dio.put(path, data: data);
      if (response.data == null) {
        throw Exception('Received null response data');
      }
      return response;
    } catch (e, stackTrace) {
      throw _handleError(e);
    }
  }

  Future<Response> delete(String path, {dynamic data}) async {
    try {
      final response = await _dio.delete(path, data: data);
      if (response.data == null) {
        throw Exception('Received null response data');
      }
      return response;
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> patch(String path, {dynamic data}) async {
    try {
      final response = await _dio.patch(path, data: data);
      if (response.data == null) {
        throw Exception('Received null response data');
      }
      return response;
    } catch (e) {
      throw _handleError(e);
    }
  }

  Exception _handleError(dynamic error) {
    if (error is DioException) {
      print('🔍 DioError type: ${error.type}');
    }
    return Exception('API request failed: ${error.toString()}');
  }
}
