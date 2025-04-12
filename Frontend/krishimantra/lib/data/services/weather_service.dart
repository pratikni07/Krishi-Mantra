import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';

class WeatherService {
  final Dio _dio = Dio();
  // Replace with your actual API key from OpenWeatherMap
  final String _apiKey = '4da43886d7063a5f26ef7d40e00c2dd9';
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
        options: Options(
          validateStatus: (status) => true,
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.statusCode == 200) {
        print('✅ Weather data fetched successfully: ${response.data}');
        // Extract data with null safety
        final main = response.data['main'] ?? {};
        final clouds = response.data['clouds'] ?? {};
        
        return {
          'temperature': main['temp'] ?? 0.0,
          'humidity': main['humidity'] ?? 0,
          'cloudiness': clouds['all'] ?? 0,
        };
      }
      
      print('❌ Weather API error: ${response.statusCode} - ${response.statusMessage}');
      // Return default values if API request fails
      return {
        'temperature': 25.0, // Default fallback temperature
        'humidity': 65,     // Default fallback humidity
        'cloudiness': 30,   // Default fallback cloudiness
      };
    } catch (e) {
      print('❌ Weather service error: $e');
      // Return default values on error
      return {
        'temperature': 25.0,
        'humidity': 65,
        'cloudiness': 30,
      };
    }
  }
} 