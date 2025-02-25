// chat_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ChatService {
  final String baseUrl = 'http://localhost:3004/api';
  final String _token = 'your_token';
  final String userId = "67554c6e9fd16ef80ae96828";
  final String userName = "Pratik Nikat";
  final String profilePhoto =
      'https://play-lh.googleusercontent.com/vco-LT_M58j9DIAxlS1Cv9uvzbRhB6cYIZJS7ocZksWRqoEPat_QXb6fVFi77lciJZQ=w526-h296-rw';

  Future<http.Response> createDirectChat(int participantId,
      String participantName, String participantProfilePhoto) async {
    final url = Uri.parse('$baseUrl/chat/direct');
    return await http.post(
      url,
      headers: _getHeaders(),
      body: jsonEncode({
        'userId': userId,
        'userName': userName,
        'participantId': participantId.toString(),
        'participantName': participantName,
        'profilePhoto': profilePhoto,
        'participantProfilePhoto': participantProfilePhoto
      }),
    );
  }

  Future<http.Response> getChatMessages(String chatId,
      {int page = 1, int limit = 50}) async {
    final url =
        Uri.parse('$baseUrl/chat/$chatId/messages?page=$page&limit=$limit');
    // print url);
    return await http.post(
      url,
      headers: _getHeaders(),
      body: jsonEncode({
        'userId': userId,
      }),
    );
  }

  Future<http.Response> markMessageAsRead(String messageId) async {
    final url = Uri.parse('$baseUrl/message/$messageId/read');
    return await http.post(
      url,
      headers: _getHeaders(),
      body: jsonEncode({
        'userId': userId,
      }),
    );
  }

  Future<http.Response> getChatList({int page = 1, int limit = 20}) async {
    final url = Uri.parse('$baseUrl/chat/list?page=$page&limit=$limit');
    return await http.post(
      url,
      headers: _getHeaders(),
      body: jsonEncode({
        'userId': userId,
      }),
    );
  }

  Future<http.Response> sendMessage(String chatId, String content,
      {String? mediaUrl}) async {
    final url = Uri.parse('$baseUrl/message/send');
    final body = {
      'userId': userId,
      'chatId': chatId,
      'content': content,
      'mediaType': mediaUrl != null ? _getMediaType(mediaUrl) : 'text',
    };
    if (mediaUrl != null) {
      body['mediaUrl'] = mediaUrl;
    }
    return await http.post(
      url,
      headers: _getHeaders(),
      body: jsonEncode(body),
    );
  }

  // Group-related methods
  Future<http.Response> createGroup({
    required String name,
    String? description,
    bool onlyAdminCanMessage = false,
    required List<Map<String, String>> participants,
  }) async {
    final url = Uri.parse('$baseUrl/group/create');
    return await http.post(
      url,
      headers: _getHeaders(),
      body: jsonEncode({
        'userId': userId,
        'userName': userName,
        'profilePhoto': profilePhoto,
        'name': name,
        'description': description,
        'participants': participants,
        'onlyAdminCanMessage': onlyAdminCanMessage,
      }),
    );
  }

  Future<http.Response> addGroupParticipants({
    required String groupId,
    required List<Map<String, String>> participants,
  }) async {
    final url = Uri.parse('$baseUrl/group/$groupId/participants');
    return await http.post(
      url,
      headers: _getHeaders(),
      body: jsonEncode({
        'userId': userId,
        'participants': participants,
      }),
    );
  }

  Future<http.Response> joinGroupViaInvite({
    required String inviteUrl,
  }) async {
    final url = Uri.parse('$baseUrl/group/join/$inviteUrl');
    return await http.post(
      url,
      headers: _getHeaders(),
      body: jsonEncode({
        'userId': userId,
        'userName': userName,
        'profilePhoto': profilePhoto,
      }),
    );
  }

  Future<http.Response> updateGroupSettings({
    required String groupId,
    String? name,
    String? description,
    bool? onlyAdminCanMessage,
  }) async {
    final url = Uri.parse('$baseUrl/group/$groupId/settings');
    return await http.put(
      url,
      headers: _getHeaders(),
      body: jsonEncode({
        'userId': userId,
        'name': name,
        'description': description,
        'onlyAdminCanMessage': onlyAdminCanMessage,
      }),
    );
  }

  Future<http.Response> deleteMessage(String messageId) async {
    final url = Uri.parse('$baseUrl/message/$messageId');
    return await http.delete(
      url,
      headers: _getHeaders(),
      body: jsonEncode({
        'userId': userId,
      }),
    );
  }

  // Media upload method (placeholder - implement based on your backend)
  Future<String?> uploadMedia(File file) async {
    // Implement media upload logic
    // This would typically involve:
    // 1. Sending the file to a file upload endpoint
    // 2. Receiving a URL or identifier for the uploaded file
    // 3. Returning the media URL
    return null;
  }

  // Helper method to get media type (already exists in your code)
  String _getMediaType(String url) {
    final extension = url.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif'].contains(extension)) return 'image';
    if (['mp4', 'mov', 'avi'].contains(extension)) return 'video';
    return 'file';
  }

  // Helper method to get headers (already exists in your code)
  Map<String, String> _getHeaders() => {
        'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
}
