// lib/data/repositories/ai_chat_repository.dart
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:krishimantra/data/models/ai_chat_message.dart';
import '../models/ai_chat.dart';
import '../services/api_service.dart';

class AIChatRepository {
  final ApiService _apiService;

  AIChatRepository(this._apiService);

  Future<Map<String, dynamic>> getChatHistory({
    required String userId,
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final response = await _apiService.get(
        '/api/messages/api/ai/history',
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
      final response =
          await _apiService.post('/api/messages/api/ai/chat', data: {
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
    try {
      FormData formData = FormData.fromMap({
        'userId': userId,
        'userName': userName,
        'userProfilePhoto': userProfilePhoto,
        if (chatId != null) 'chatId': chatId,
        'image': await MultipartFile.fromFile(
          image.path,
          filename: 'crop_image.jpg',
          contentType: MediaType('image', 'jpeg'),
        ),
        'preferredLanguage': preferredLanguage,
        'location': location.toJson(),
        'weather': weather.toJson(),
      });

      final response = await _apiService.post(
        '/api/messages/api/ai/analyze-image',
        data: formData,
      );

      if (!response.data.containsKey('analysis')) {
        throw Exception('Invalid response: missing analysis data');
      }

      return {
        'chatId': response.data['chatId'],
        'analysis': response.data['analysis'],
        'context': response.data['context'],
        'history': response.data['history'],
      };
    } catch (error) {
      throw _handleError(error);
    }
  }

  Future<AIChat> getChatById(String userId, String chatId) async {
    try {
      final response = await _apiService.get(
        '/api/messages/api/ai/chat/$chatId',
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
        '/api/messages/api/ai/chat/$chatId/title',
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
        '/api/messages/api/ai/chat/$chatId',
        data: {'userId': userId},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete chat');
      }
    } catch (error) {
      throw _handleError(error);
    }
  }

  Future<String> generateChatTitle(String chatId, String userId) async {
    try {
      final chat = await getChatById(userId, chatId);

      // If there are less than 2 messages, use a default title
      if (chat.messages.length < 2) {
        return "New Conversation";
      }

      // Extract the first user message for the title
      final firstUserMessage = chat.messages.firstWhere(
        (msg) => msg.role == 'user',
        orElse: () => AIChatMessage(
          role: 'user',
          content: 'New Conversation',
          timestamp: DateTime.now(),
        ),
      );

      // Truncate the message if it's too long
      String title = firstUserMessage.content;
      if (title.length > 40) {
        title = title.substring(0, 40) + "...";
      }

      return title;
    } catch (e) {
      print('Error generating chat title: $e');
      return "New Conversation";
    }
  }

  Exception _handleError(dynamic error) {
    if (error is DioException) {
      final response = error.response;
      if (response != null) {
        final errorMessage = response.data is Map
            ? response.data['error'] ?? 'API request failed'
            : 'API request failed';
        return Exception(errorMessage);
      }
      return Exception(error.message ?? 'Network error occurred');
    }
    return error is Exception ? error : Exception(error.toString());
  }
}
