import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/consultant_model.dart';
import '../models/message_model.dart';
import '../services/api_service.dart';

class MessageRepository {
  final ApiService _apiService;

  MessageRepository(this._apiService);

  Future<Message> sendMessage({
    required String userId,
    required String chatId,
    required String content,
    required String mediaType,
    String? mediaUrl,
  }) async {
    try {
      final response =
          await _apiService.post('/api/messages/api/message/send', data: {
        'userId': userId,
        'chatId': chatId,
        'content': content,
        'mediaType': mediaType,
        if (mediaUrl != null) 'mediaUrl': mediaUrl,
      });

      return Message.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }

  Future<Message> markMessageAsRead({
    required String messageId,
    required String userId,
  }) async {
    try {
      final response = await _apiService.put(
        '/api/messages/api/message/$messageId/read',
        data: {'userId': userId},
      );

      return Message.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to mark message as read: $e');
    }
  }

  Future<Chat> createDirectChat({
    required String userId,
    required String userName,
    required String participantId,
    required String participantName,
    required String profilePhoto,
    required String participantProfilePhoto,
  }) async {
    try {
      final response =
          await _apiService.post('/api/messages/api/chat/direct', data: {
        'userId': userId,
        'userName': userName,
        'participantId': participantId,
        'participantName': participantName,
      });

      return Chat.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to create direct chat: $e');
    }
  }

  Future<List<Message>> getMessagesByChatId({
    required String chatId,
    required String userId,
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final response = await _apiService.post(
        '/api/messages/api/chat/$chatId/messages',
        data: {
          'userId': userId,
          'page': page,
          'limit': limit,
        },
      );

      if (response.data == null) {
        throw Exception('Response data is null');
      }

      if (response.data is! List) {
        throw Exception('Expected List but got ${response.data.runtimeType}');
      }

      return (response.data as List)
          .map((message) => Message.fromJson(message))
          .toList();
    } catch (e, stackTrace) {
      throw Exception('Failed to get messages: $e');
    }
  }

  Future<List<Chat>> getUserChats({
    required String userId,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _apiService.post(
        '/api/messages/api/chat/list',
        data: {
          'userId': userId,
          'page': page,
          'limit': limit,
        },
      );

      return (response.data as List)
          .map((chat) => Chat.fromJson(chat))
          .toList();
    } catch (e) {
      throw Exception('Failed to get user chats: $e');
    }
  }

  Future<GroupChat> createGroup({
    required String userId,
    required String userName,
    required String name,
    required String description,
    required List<String> participants,
    bool onlyAdminCanMessage = false,
  }) async {
    try {
      final response =
          await _apiService.post('/api/messages/api/group/create', data: {
        'userId': userId,
        'userName': userName,
        'name': name,
        'description': description,
        'participants': participants,
        'onlyAdminCanMessage': onlyAdminCanMessage,
      });

      if (response.data == null) {
        throw Exception('Failed to create group: Empty response');
      }

      return GroupChat.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to create group: $e');
    }
  }

  Future<void> addGroupParticipants({
    required String groupId,
    required List<String> participants,
  }) async {
    try {
      await _apiService.post(
        '/api/messages/api/group/$groupId/participants',
        data: {'participants': participants},
      );
    } catch (e) {
      throw Exception('Failed to add group participants: $e');
    }
  }

  Future<void> joinGroup({
    required String inviteUrl,
    required String userId,
  }) async {
    try {
      await _apiService.post(
        '/api/messages/api/group/join/$inviteUrl',
        data: {'userId': userId},
      );
    } catch (e) {
      throw Exception('Failed to join group: $e');
    }
  }

  Future<void> leaveGroup({
    required String groupId,
    required String userId,
  }) async {
    try {
      await _apiService.post('/api/messages/api/group/$groupId/leave', data: {
        'userId': userId,
      });
    } catch (e) {
      throw Exception('Failed to leave group: $e');
    }
  }

  Future<List<Consultant>> getConsultants(
      // {
      // double latitude,
      // double longitude,
      // }
      ) async {
    try {
      final response = await _apiService.get(
        '/api/main/user/consultant',
        // data: {
        //   'latitude': latitude,
        //   'longitude': longitude,
        // },
      );

      if (response.data == null) {
        throw Exception('Response data is null');
      }

      final consultantsData = response.data['consultants'] as List;
      return consultantsData
          .map((consultant) => Consultant.fromJson(consultant))
          .toList();
    } catch (e) {
      throw Exception('Failed to get consultants: $e');
    }
  }
}
