import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiService {
  final String baseUrl = 'http://localhost:3002';
  final String _token = 'your_token';
  // API endpoint
  final String _GET_CONSULTANT_ACCORDING_TO_LOCATION = '/user/consultant';

  // GET request
  Future<http.Response> getConsultantByLocation(
      double latitude, double longitude) async {
    final Uri _url =
        Uri.parse('$baseUrl$_GET_CONSULTANT_ACCORDING_TO_LOCATION');

    final headers = {
      'Authorization': 'Bearer $_token',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final http.Response response = await http.post(
      _url,
      headers: headers,
      body: jsonEncode({
        'latitude': latitude,
        'longitude': longitude,
      }),
    );
    // print(response);
    return response;
  }
}
