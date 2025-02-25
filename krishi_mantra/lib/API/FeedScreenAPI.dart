import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  final String baseUrl = 'http://localhost:3003/feeds';
  final String baseUrl2 = 'http://localhost:3003';
  final String _token = 'your_token';

  // API endpoints
  final String _GET_FEED_BY_ID = '/{id}?page={page}&limit={limit}';
  final String _POST_LIKE = '/{id}/like';
  final String _POST_COMMENT = '/{id}/comment';
  final String _GET_RANDOM_FEEDS = '/feeds/random?page={page}&limit={limit}';
  final String _POST_USER_INTEREST = '/user/interest';
  final String _POST_USER_INTERACTION = '/user/interaction';
  final String _GET_RECOMMENDED_FEEDS =
      '/recommended/{userId}?page={page}&limit={limit}';

  Future<http.Response> createFeed(Map<String, dynamic> data) async {
    final Uri _url = Uri.parse('$baseUrl');

    final headers = {
      'Authorization': 'Bearer $_token',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final http.Response response = await http.post(
      _url,
      headers: headers,
      body: json.encode(data),
    );

    return response;
  }

  // 1. GET: Get feed by ID
  Future<http.Response> getFeedById(String feedId, int page, int limit) async {
    final Uri _url = Uri.parse('$baseUrl$feedId?page=$page&limit=$limit');

    final headers = {
      'Authorization': 'Bearer $_token',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final http.Response response = await http.get(
      _url,
      headers: headers,
    );
    return response;
  }

  // 2. POST: Like a feed
  Future<http.Response> likeFeed(
      String feedId, Map<String, dynamic> data) async {
    final Uri _url = Uri.parse('$baseUrl$feedId/like');

    final headers = {
      'Authorization': 'Bearer $_token',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final http.Response response = await http.post(
      _url,
      headers: headers,
      body: json.encode(data),
    );

    return response;
  }

  // 3. POST: Comment on a feed
  Future<http.Response> commentOnFeed(
      String feedId, Map<String, dynamic> data) async {
    final Uri _url = Uri.parse('$baseUrl/$feedId/comment');

    final headers = {
      'Authorization': 'Bearer $_token',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final requestData = {
      ...data,
      'feedId': feedId,
    };

    try {
      final http.Response response = await http.post(
        _url,
        headers: headers,
        body: json.encode(requestData),
      );

      return response;
    } catch (e, stackTrace) {
      print('API error stack trace: $stackTrace');
      rethrow;
    }
  }

  // 4. GET: Get random feeds
  Future<http.Response> getRandomFeeds(int page, int limit) async {
    final Uri _url = Uri.parse('$baseUrl/feeds/random?page=$page&limit=$limit');

    final headers = {
      'Authorization': 'Bearer $_token',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final http.Response response = await http.get(
      _url,
      headers: headers,
    );
    return response;
  }

  // 5. POST: User interest
  Future<http.Response> postUserInterest(Map<String, dynamic> data) async {
    final Uri _url = Uri.parse('$baseUrl/user/interest');

    final headers = {
      'Authorization': 'Bearer $_token',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final http.Response response = await http.post(
      _url,
      headers: headers,
      body: json.encode(data),
    );
    return response;
  }

  // 6. POST: User interaction
  Future<http.Response> postUserInteraction(Map<String, dynamic> data) async {
    final Uri _url = Uri.parse('$baseUrl/user/interaction');

    final headers = {
      'Authorization': 'Bearer $_token',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final http.Response response = await http.post(
      _url,
      headers: headers,
      body: json.encode(data),
    );
    return response;
  }

  // 7. GET: Recommended feeds
  Future<http.Response> getRecommendedFeeds(
      String userId, int page, int limit) async {
    // print(
    //   "getRecommendedFeeds",
    // );
    final Uri _url = Uri.parse(
        '$baseUrl/user/${userId}/recommended?page=$page&limit=$limit');

    final headers = {
      'Authorization': 'Bearer $_token',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final http.Response response = await http.get(
      _url,
      headers: headers,
    );

    return response;
  }

  // 6 get Comment
  Future<http.Response> getComments(String feedId, int page, int limit) async {
    final Uri _url = Uri.parse(
        '$baseUrl2/comments/getComment?feedId=$feedId&page=$page&limit=$limit');

    final headers = {
      'Authorization': 'Bearer $_token',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final http.Response response = await http.get(
      _url,
      headers: headers,
    );
    return response;
  }
}
