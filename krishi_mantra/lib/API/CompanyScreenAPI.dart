import 'package:http/http.dart' as http;

class ApiService {
  final String baseUrl = 'http://localhost:3002';
  final String _token = 'your_token';
  // API endpoint
  final String _GET_ALL_COMPANY = '/companies';
  final String _GET_COMPANY_BY_ID = '/companies';

  // GET request
  Future<http.Response> getAllCompany() async {
    final Uri _url = Uri.parse('$baseUrl$_GET_ALL_COMPANY');

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

  Future<http.Response> getCompanyById(id) async {
    final Uri _url = Uri.parse('$baseUrl$_GET_COMPANY_BY_ID/$id');

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
