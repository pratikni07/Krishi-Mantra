import 'package:http/http.dart' as http;

class ApiService {
  final String baseUrl = 'http://localhost:3002';
  final String _token = 'your_token';
  // API endpoint
  final String _GET_HOME_SCREEN = '/ads/home-screen-ads';

  // GET request for home screen ads
  Future<http.Response> getHomeScreenAds() async {
    final Uri _url = Uri.parse('$baseUrl$_GET_HOME_SCREEN');

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

  // GET Request
  // Future<List<dynamic>> fetchPosts() async {
  //   final url = Uri.parse('$baseUrl/posts');
  //   try {
  //     final response = await http.get(url);

  //     if (response.statusCode == 200) {
  //       return json.decode(response.body);
  //     } else {
  //       throw Exception('Failed to load posts');
  //     }
  //   } catch (e) {
  //     throw Exception('Error: $e');
  //   }
  // }

  // // POST Request
  // Future<Map<String, dynamic>> createPost(Map<String, dynamic> postData) async {
  //   final url = Uri.parse('$baseUrl/posts');
  //   try {
  //     final response = await http.post(
  //       url,
  //       headers: {'Content-Type': 'application/json'},
  //       body: json.encode(postData),
  //     );

  //     if (response.statusCode == 201) {
  //       return json.decode(response.body);
  //     } else {
  //       throw Exception('Failed to create post');
  //     }
  //   } catch (e) {
  //     throw Exception('Error: $e');
  //   }
  // }
}
