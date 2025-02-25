import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiService {
  final String baseUrl = 'http://localhost:3002/crop-calendar';
  final String _token = 'your_token';
  // API endpoint
  final String _GET_ALL_CROPS = '/crops';
  final String _GET_CALENDAR_BY_CROP_ID = '/calendar';

  // GET request
  Future<http.Response> getAllCrops() async {
    final Uri _url = Uri.parse('$baseUrl$_GET_ALL_CROPS');

    final headers = {
      'Authorization': 'Bearer $_token',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final http.Response response = await http.get(
      _url,
      headers: headers,
    );
    // print(response);
    return response;
  }

  // GET CROP CALENDAR
  Future<http.Response> getCropCalendar(id) async {
    final Uri _url = Uri.parse('$baseUrl$_GET_CALENDAR_BY_CROP_ID/$id/6');

    final headers = {
      'Authorization': 'Bearer $_token',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final http.Response response = await http.get(
      _url,
      headers: headers,
    );
    // print(response);
    return response;
  }
}
