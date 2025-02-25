import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  final String baseUrl = 'http://localhost:3005/reels';

  // Default user data
  final Map<String, String> defaultUserData = {
    "userId": "67554c6e9fd16ef80ae96828",
    "userName": "John Doe",
    "profilePhoto":
        "https://images.ctfassets.net/h6goo9gw1hh6/2sNZtFAWOdP1lmQ33VwRN3/24e953b920a9cd0ff2e1d587742a2472/1-intro-photo-final.jpg?w=1200&h=992&fl=progressive&q=70&fm=jpg",
  };

  // Headers
  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  // Get reels with pagination
  Future<http.Response> getReels({int page = 1, int limit = 10}) async {
    final Uri url = Uri.parse('$baseUrl?page=$page&limit=$limit');
    return await http.get(url, headers: _headers);
  }

  // Get trending tags
  Future<http.Response> getTrendingTags() async {
    final Uri url = Uri.parse('$baseUrl/tags/trending');
    return await http.get(url, headers: _headers);
  }

  // Get reels by tag name
  Future<http.Response> getReelsByTag(String tagName) async {
    final Uri url = Uri.parse('$baseUrl/tags/$tagName');
    return await http.get(url, headers: _headers);
  }

  // Get trending reels
  Future<http.Response> getTrendingReels() async {
    final Uri url = Uri.parse('$baseUrl/trending');
    return await http.get(url, headers: _headers);
  }

  // Like reel
  Future<http.Response> likeReel(String reelId,
      {Map<String, String>? userData}) async {
    final Uri url = Uri.parse('$baseUrl/$reelId/like');

    // Use provided userData or fall back to default
    final Map<String, String> likeData = userData ?? defaultUserData;

    return await http.post(
      url,
      headers: _headers,
      body: jsonEncode(likeData),
    );
  }

  // Add comment to reel
  Future<http.Response> addComment(String reelId, String content,
      {Map<String, String>? userData}) async {
    final Uri url = Uri.parse('$baseUrl/$reelId/comments');

    // Use provided userData or fall back to default
    final Map<String, String> commentData = {
      ...defaultUserData,
      ...?userData,
      'content': content,
    };

    return await http.post(
      url,
      headers: _headers,
      body: jsonEncode(commentData),
    );
  }

  // Delete comment
  Future<http.Response> deleteComment(String commentId,
      {String? userId}) async {
    final Uri url = Uri.parse('$baseUrl/comments/$commentId');

    final Map<String, String> deleteData = {
      'userId': userId ?? defaultUserData['userId']!,
    };

    return await http.delete(
      url,
      headers: _headers,
      body: jsonEncode(deleteData),
    );
  }

  // Helper method to handle API responses
  dynamic handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    } else {
      throw Exception('API Error: ${response.statusCode} - ${response.body}');
    }
  }

  Future<http.Response> getComments(String reelId) async {
    final Uri url = Uri.parse('$baseUrl/$reelId/comments');
    return await http.get(url, headers: _headers);
  }
}
