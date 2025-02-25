// api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  final String baseUrl = 'http://localhost:3002/schemes/schemes';
  final String _token = 'your_token';

  Map<String, String> get headers => {
        'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  Future<List<dynamic>> getAllSchemes() async {
    try {
      final Uri _url = Uri.parse(baseUrl);
      final response = await http.get(_url, headers: headers);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load schemes: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> getSchemeById(String id) async {
    try {
      final Uri _url = Uri.parse('$baseUrl/$id');
      final response = await http.get(_url, headers: headers);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Scheme not found: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}
