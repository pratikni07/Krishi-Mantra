import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';

class WeatherService {
  final Dio _dio = Dio();
  final String _apiKey = 'YOUR_API_KEY'; // Get free API key from OpenWeatherMap
  final String _baseUrl = 'https://api.openweathermap.org/data/2.5';

  Future<Map<String, dynamic>> getWeatherData(Position position) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/weather',
        queryParameters: {
          'lat': position.latitude,
          'lon': position.longitude,
          'appid': _apiKey,
          'units': 'metric', // For Celsius
        },
      );

      if (response.statusCode == 200) {
        return {
          'temperature': response.data['main']['temp'],
          'humidity': response.data['main']['humidity'],
          'cloudiness': response.data['clouds']['all'],
        };
      }
      throw Exception('Failed to fetch weather data');
    } catch (e) {
      throw Exception('Error getting weather data: $e');
    }
  }
} 