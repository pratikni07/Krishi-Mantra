import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  final String baseUrl = 'http://localhost:3002/auth';

  Future<Map<String, dynamic>> login(String email, String password) async {
    final Uri url = Uri.parse('$baseUrl/login');
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: json.encode({
          "email": email,
          "password": password,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to login: ${response.statusCode}');
      }

      return json.decode(response.body);
    } catch (e) {
      throw Exception('Failed to login: $e');
    }
  }
}
