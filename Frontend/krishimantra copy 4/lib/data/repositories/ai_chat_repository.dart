// lib/data/repositories/ai_chat_repository.dart
import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:krishimantra/data/models/ai_chat_message.dart';
import '../models/ai_chat.dart';
import '../services/api_service.dart';

class AIChatRepository {
  final ApiService _apiService;

  AIChatRepository(this._apiService);

  // Retry a request with exponential backoff for connection issues
  Future<T> _retryWithBackoff<T>(
    Future<T> Function() requestFn, {
    int maxRetries = 3,
    Duration initialDelay = const Duration(seconds: 1),
  }) async {
    int attempts = 0;
    Duration delay = initialDelay;

    while (true) {
      try {
        return await requestFn();
      } catch (error) {
        attempts++;

        // Check if we should retry (only for connection/server issues)
        final shouldRetry = _isRetriableError(error) && attempts < maxRetries;

        if (!shouldRetry) {
          // We're out of retries or it's not a retriable error
          rethrow;
        }

        // Wait with exponential backoff before retrying
        await Future.delayed(delay);

        // Increase delay for next retry with some randomness to avoid thundering herd
        delay = Duration(
            milliseconds:
                (delay.inMilliseconds * 1.5 + math.Random().nextInt(500))
                    .toInt());
      }
    }
  }

  bool _isRetriableError(dynamic error) {
    if (error is DioException) {
      // Connection errors
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.connectionError) {
        return true;
      }

      // Server errors (5xx)
      if (error.response?.statusCode != null &&
          error.response!.statusCode! >= 500 &&
          error.response!.statusCode! < 600) {
        // Special handling for 503 Service Unavailable and 502 Bad Gateway
        // These are very likely to be temporary
        return true;
      }
    }

    // Check the error message for common network issues
    final errorMsg = error.toString().toLowerCase();
    return errorMsg.contains('econnreset') ||
        errorMsg.contains('connection reset') ||
        errorMsg.contains('socket') ||
        errorMsg.contains('timeout') ||
        errorMsg.contains('unavailable');
  }

  Future<Map<String, dynamic>> getChatHistory({
    required String userId,
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final response = await _apiService.get(
        '/api/ai/history',
        queryParameters: {
          'userId': userId,
          'page': page,
          'limit': limit,
        },
      );

      if (response.data != null) {
        final data = response.data;
        return {
          'chats': (data['chats'] as List)
              .map((chat) => AIChat.fromJson(chat))
              .toList(),
          'pagination': {
            'total': data['pagination']['total'],
            'page': data['pagination']['page'],
            'pages': data['pagination']['pages'],
          }
        };
      }
      return {
        'chats': [],
        'pagination': {'total': 0, 'page': 1, 'pages': 0}
      };
    } catch (error) {
      throw _handleError(error);
    }
  }

  Future<Map<String, dynamic>?> sendMessage({
    required String userId,
    required String userName,
    required String userProfilePhoto,
    String? chatId,
    required String message,
    required String preferredLanguage,
    required Map<String, dynamic> location,
    required Map<String, dynamic> weather,
  }) async {
    try {
      final response = await _apiService.post('/api/ai/chat', data: {
        'userId': userId,
        'userName': userName,
        'userProfilePhoto': userProfilePhoto,
        if (chatId != null) 'chatId': chatId,
        'message': message,
        'preferredLanguage': preferredLanguage,
        'location': location,
        'weather': weather,
      });

      if (response.statusCode == 429) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'chatId': response.data['chatId'] ?? chatId,
          'message': response.data['message'] ?? response.data['content'],
          'context': response.data['context'],
          'history': response.data['history'],
          'rateLimit': response.data['rateLimit'],
        };
      }
      throw Exception('Invalid response format');
    } catch (error) {
      throw _handleError(error);
    }
  }

  Future<Map<String, dynamic>> analyzeCropImage({
    required String userId,
    required String userName,
    required String userProfilePhoto,
    String? chatId,
    required File image,
    required String preferredLanguage,
    required Location location,
    required Weather weather,
  }) async {
    return _retryWithBackoff(() async {
      try {
        // Log the upload attempt to help with debugging
        print('Preparing to upload image from path: ${image.path}');
        print(
            'File exists: ${image.existsSync()}, file size: ${await image.length()} bytes');

        // Create FormData with image
        final formData = FormData.fromMap({
          'userId': userId,
          'userName': userName,
          'userProfilePhoto': userProfilePhoto,
          if (chatId != null) 'chatId': chatId,
          'preferredLanguage': preferredLanguage,
          'location': jsonEncode({'lat': location.lat, 'lon': location.lon}),
          'weather': jsonEncode({
            'temperature': weather.temperature,
            'humidity': weather.humidity
          }),
          'image': await MultipartFile.fromFile(
            image.path,
            contentType: MediaType('image', 'jpeg'),
            filename: 'image_${DateTime.now().millisecondsSinceEpoch}.jpg',
          ),
        });

        // Create options with increased timeouts
        final options = Options(
          contentType: 'multipart/form-data',
          headers: {'Accept': 'application/json'},
          // Increase timeouts for image uploads
          sendTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 60),
        );

        print('Sending multipart request to /api/ai/analyze-image');
        print(
            'FormData fields: ${formData.fields.map((e) => '${e.key}: ${e.value.length > 50 ? '${e.value.substring(0, 50)}...' : e.value}').join(', ')}');
        print(
            'FormData files: ${formData.files.length} (${formData.files.first.key}: ${formData.files.first.value.filename})');

        final response = await _apiService.post(
          '/api/ai/analyze-image',
          data: formData,
          options: options,
        );

        print('Response status code: ${response.statusCode}');

        if (response.statusCode == 200 || response.statusCode == 201) {
          return {
            'chatId': response.data['chatId'] ?? chatId,
            'analysis': response.data['analysis'],
            'context': response.data['context'],
            'history': response.data['history'],
            'limitInfo': response.data['limitInfo'],
          };
        }
        throw Exception('Invalid response format');
      } catch (error) {
        print('Error during image upload: $error');
        if (error.toString().contains('No image provided') ||
            error.toString().contains('Invalid image format')) {
          // Special handling for image format errors
          print('Image error detected: $error');
          throw Exception(
              'The image could not be processed. Please try a different image.');
        }
        throw _handleError(error);
      }
    }, maxRetries: 3, initialDelay: const Duration(seconds: 2));
  }

  // Method to handle multiple images upload and analysis
  Future<Map<String, dynamic>> analyzeMultipleImages({
    required String userId,
    required String userName,
    required String userProfilePhoto,
    String? chatId,
    required List<File> images,
    String? message,
    required String preferredLanguage,
    required Location location,
    required Weather weather,
  }) async {
    return _retryWithBackoff(() async {
      try {
        // Check if images are provided
        if (images.isEmpty) {
          throw Exception('No images provided');
        }

        // Check if all image files exist and have content
        for (var image in images) {
          if (!image.existsSync() || await image.length() == 0) {
            throw Exception('Invalid image file: ${image.path}');
          }
        }

        // Create form data
        final formData = FormData();

        // Add text fields with proper encoding
        formData.fields.add(MapEntry('userId', userId));
        formData.fields.add(MapEntry('userName', userName));
        formData.fields.add(MapEntry('userProfilePhoto', userProfilePhoto));
        if (chatId != null) formData.fields.add(MapEntry('chatId', chatId));
        if (message != null) formData.fields.add(MapEntry('message', message));
        formData.fields.add(MapEntry('preferredLanguage', preferredLanguage));
        formData.fields.add(MapEntry('location',
            jsonEncode({'lat': location.lat, 'lon': location.lon})));
        formData.fields.add(MapEntry(
            'weather',
            jsonEncode({
              'temperature': weather.temperature,
              'humidity': weather.humidity
            })));

        // Add all images to form data
        for (int i = 0; i < images.length; i++) {
          print(
              'Adding image ${i + 1}/${images.length} - path: ${images[i].path}, size: ${await images[i].length()} bytes');
          formData.files.add(MapEntry(
            'images',
            await MultipartFile.fromFile(
              images[i].path,
              contentType: MediaType('image', 'jpeg'),
              filename:
                  'image_${i}_${DateTime.now().millisecondsSinceEpoch}.jpg',
            ),
          ));
        }

        // Configure additional options for the request
        final options = Options(
          contentType: 'multipart/form-data',
          headers: {'Accept': 'application/json'},
          // Increase timeouts for multiple image uploads
          sendTimeout: const Duration(seconds: 120),
          receiveTimeout: const Duration(seconds: 120),
        );

        // Send request to multi-image analysis endpoint
        final response = await _apiService.post(
          '/api/ai/analyze-multi-images',
          data: formData,
          options: options,
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          return {
            'chatId': response.data['chatId'] ?? chatId,
            'analysis': response.data['analysis'],
            'context': response.data['context'],
            'history': response.data['history'],
            'limitInfo': response.data['limitInfo'],
          };
        }
        throw Exception('Invalid response format');
      } catch (error) {
        if (error.toString().contains('No image') ||
            error.toString().contains('Invalid image')) {
          // Special handling for image format errors
          print('Image error detected: $error');
          throw Exception(
              'One or more images could not be processed. Please try different images.');
        }
        throw _handleError(error);
      }
    }, maxRetries: 3, initialDelay: const Duration(seconds: 2));
  }

  Future<AIChat> getChatById(String userId, String chatId) async {
    try {
      final response = await _apiService.get(
        '/api/ai/chat/$chatId',
        queryParameters: {'userId': userId},
      );

      if (response.data == null) {
        throw Exception('Chat not found');
      }

      return AIChat.fromJson(response.data);
    } catch (error) {
      throw _handleError(error);
    }
  }

  Future<AIChat> updateChatTitle(
    String chatId,
    String userId,
    String title,
  ) async {
    try {
      final response = await _apiService.patch(
        '/api/ai/chat/$chatId/title',
        data: {
          'userId': userId,
          'title': title,
        },
      );

      if (!response.data.containsKey('chat')) {
        throw Exception('Invalid response: missing chat data');
      }

      return AIChat.fromJson(response.data['chat']);
    } catch (error) {
      throw _handleError(error);
    }
  }

  Future<void> deleteChat(String chatId, String userId) async {
    try {
      final response = await _apiService.delete(
        '/api/ai/chat/$chatId',
        data: {'userId': userId},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete chat');
      }
    } catch (error) {
      throw _handleError(error);
    }
  }

  Exception _handleError(dynamic error) {
    if (error is DioException) {
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        return Exception('Network timeout. Please check your connection.');
      } else if (error.response != null) {
        // Special handling for 502 errors and message service unavailability
        if (error.response!.statusCode == 502) {
          final responseData = error.response!.data;
          if (responseData is Map &&
              responseData['message'] == 'Message Service unavailable') {
            return Exception(
                'The message analysis service is currently unavailable. Please try again later.');
          }
          return Exception(
              'Server is temporarily unavailable. Please try again later.');
        } else if (error.response!.statusCode == 429) {
          return Exception('Rate limited. Please try again later.');
        }
        return Exception(error.response!.data['message'] ?? 'Server error');
      } else if (error.error != null) {
        // Handle ECONNRESET and other socket errors
        final errorString = error.error.toString().toLowerCase();
        if (errorString.contains('econnreset') ||
            errorString.contains('connection reset')) {
          return Exception(
              'Connection was reset. The server might be overloaded or restarting.');
        } else if (errorString.contains('socketexception')) {
          return Exception(
              'Network connection error. Please check your internet connection.');
        }
      }
    }
    return Exception(error.toString());
  }
}
