import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/utils/app_logger.dart';

class WeatherService {
  final Dio _dio = Dio();
  // Inject at build time: --dart-define=OPENWEATHER_API_KEY=...
  // Long-term: move this call behind a backend proxy so the key never
  // ships in the APK.
  static const String _apiKey =
      String.fromEnvironment('OPENWEATHER_API_KEY', defaultValue: '');
  final String _baseUrl = 'https://api.openweathermap.org/data/2.5';

  /// Get current weather data
  Future<Map<String, dynamic>> getWeatherData(Position position) async {
    try {
      logger.d('Fetching weather for: ${position.latitude}, ${position.longitude}', tag: 'WeatherService');

      final response = await _dio.get(
        '$_baseUrl/weather',
        queryParameters: {
          'lat': position.latitude,
          'lon': position.longitude,
          'appid': _apiKey,
          'units': 'metric',
        },
        options: Options(
          validateStatus: (status) => true,
          receiveTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 15),
        ),
      );

      logger.d('Weather API response status: ${response.statusCode}', tag: 'WeatherService');

      if (response.statusCode == 200) {
        final main = response.data['main'] ?? {};
        final clouds = response.data['clouds'] ?? {};
        final wind = response.data['wind'] ?? {};
        final weather = (response.data['weather'] as List?)?.isNotEmpty == true
            ? response.data['weather'][0]
            : {};

        final result = {
          'temperature': (main['temp'] ?? 25.0).toDouble().round(),
          'feels_like': (main['feels_like'] ?? 25.0).toDouble().round(),
          'humidity': main['humidity'] ?? 65,
          'wind_speed': ((wind['speed'] ?? 0.0) * 3.6).round(),
          'condition': _capitalizeCondition(weather['description'] ?? 'Clear'),
          'cloudiness': clouds['all'] ?? 0,
          'rain_chance': _calculateRainChance(clouds['all'] ?? 0, main['humidity'] ?? 50),
          'icon': weather['icon'] ?? '01d',
        };

        logger.d('Weather data: temp=${result['temperature']}, humidity=${result['humidity']}, clouds=${result['cloudiness']}', tag: 'WeatherService');
        return result;
      }

      logger.w('Weather API returned status: ${response.statusCode}', tag: 'WeatherService');
      return _getDefaultWeatherData();
    } catch (e) {
      logger.e('Error fetching weather data', tag: 'WeatherService', error: e);
      return _getDefaultWeatherData();
    }
  }

  /// Get hourly forecast for next 24 hours
  Future<List<Map<String, dynamic>>> getHourlyForecast(Position position) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/forecast',
        queryParameters: {
          'lat': position.latitude,
          'lon': position.longitude,
          'appid': _apiKey,
          'units': 'metric',
          'cnt': 8, // 8 * 3 hours = 24 hours
        },
        options: Options(
          validateStatus: (status) => true,
          receiveTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 15),
        ),
      );

      if (response.statusCode == 200) {
        final List forecastList = response.data['list'] ?? [];
        return forecastList.map<Map<String, dynamic>>((item) {
          final main = item['main'] ?? {};
          final weather = (item['weather'] as List?)?.isNotEmpty == true
              ? item['weather'][0]
              : {};
          return {
            'time': DateTime.fromMillisecondsSinceEpoch((item['dt'] ?? 0) * 1000),
            'temperature': (main['temp'] ?? 25.0).toDouble().round(),
            'condition': _mapConditionToSimple(weather['main'] ?? 'Clear'),
            'icon': weather['icon'] ?? '01d',
          };
        }).toList();
      }

      return _getDefaultHourlyForecast();
    } catch (e) {
      logger.e('Error fetching hourly forecast', tag: 'WeatherService', error: e);
      return _getDefaultHourlyForecast();
    }
  }

  /// Get 7-day forecast
  Future<List<Map<String, dynamic>>> getWeeklyForecast(Position position) async {
    try {
      // OpenWeatherMap free tier doesn't have daily forecast, so we use 5-day/3-hour forecast
      final response = await _dio.get(
        '$_baseUrl/forecast',
        queryParameters: {
          'lat': position.latitude,
          'lon': position.longitude,
          'appid': _apiKey,
          'units': 'metric',
          'cnt': 40, // 40 * 3 hours = 5 days (max for free tier)
        },
        options: Options(
          validateStatus: (status) => true,
          receiveTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 15),
        ),
      );

      if (response.statusCode == 200) {
        final List forecastList = response.data['list'] ?? [];

        // Group by day and extract min/max temps
        Map<String, Map<String, dynamic>> dailyData = {};

        for (var item in forecastList) {
          final dt = DateTime.fromMillisecondsSinceEpoch((item['dt'] ?? 0) * 1000);
          final dayKey = '${dt.year}-${dt.month}-${dt.day}';
          final main = item['main'] ?? {};
          final weather = (item['weather'] as List?)?.isNotEmpty == true
              ? item['weather'][0]
              : {};
          final temp = (main['temp'] ?? 25.0).toDouble();

          if (!dailyData.containsKey(dayKey)) {
            dailyData[dayKey] = {
              'date': dt,
              'max_temp': temp,
              'min_temp': temp,
              'condition': _mapConditionToSimple(weather['main'] ?? 'Clear'),
            };
          } else {
            if (temp > dailyData[dayKey]!['max_temp']) {
              dailyData[dayKey]!['max_temp'] = temp;
            }
            if (temp < dailyData[dayKey]!['min_temp']) {
              dailyData[dayKey]!['min_temp'] = temp;
            }
          }
        }

        // Convert to list and round temperatures
        List<Map<String, dynamic>> result = dailyData.values.map((day) {
          return {
            'date': day['date'],
            'max_temp': (day['max_temp'] as double).round(),
            'min_temp': (day['min_temp'] as double).round(),
            'condition': day['condition'],
          };
        }).toList();

        // Add remaining days with default data to make 7 days
        while (result.length < 7) {
          final lastDate = result.isNotEmpty
              ? result.last['date'] as DateTime
              : DateTime.now();
          result.add({
            'date': lastDate.add(const Duration(days: 1)),
            'max_temp': 30,
            'min_temp': 22,
            'condition': 'Sunny',
          });
        }

        return result.take(7).toList();
      }

      return _getDefaultWeeklyForecast();
    } catch (e) {
      logger.e('Error fetching weekly forecast', tag: 'WeatherService', error: e);
      return _getDefaultWeeklyForecast();
    }
  }

  String _capitalizeCondition(String condition) {
    if (condition.isEmpty) return 'Clear';
    return condition.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }

  String _mapConditionToSimple(String condition) {
    switch (condition.toLowerCase()) {
      case 'clear':
        return 'Sunny';
      case 'clouds':
        return 'Cloudy';
      case 'rain':
      case 'drizzle':
        return 'Rainy';
      case 'thunderstorm':
        return 'Stormy';
      case 'snow':
        return 'Snowy';
      case 'mist':
      case 'fog':
      case 'haze':
        return 'Foggy';
      default:
        return 'Cloudy';
    }
  }

  int _calculateRainChance(int cloudiness, int humidity) {
    // Simple estimation based on cloudiness and humidity
    return ((cloudiness * 0.4) + (humidity * 0.3)).round().clamp(0, 100);
  }

  Map<String, dynamic> _getDefaultWeatherData() {
    return {
      'temperature': 28,
      'feels_like': 30,
      'humidity': 65,
      'wind_speed': 12,
      'condition': 'Partly Cloudy',
      'cloudiness': 30,
      'rain_chance': 30,
      'icon': '02d',
    };
  }

  List<Map<String, dynamic>> _getDefaultHourlyForecast() {
    return List.generate(24, (index) {
      return {
        'time': DateTime.now().add(Duration(hours: index)),
        'temperature': 25 + (index % 5),
        'condition': index % 2 == 0 ? 'Sunny' : 'Cloudy',
        'icon': index % 2 == 0 ? '01d' : '02d',
      };
    });
  }

  List<Map<String, dynamic>> _getDefaultWeeklyForecast() {
    return List.generate(7, (index) {
      return {
        'date': DateTime.now().add(Duration(days: index)),
        'max_temp': 30 + (index % 3),
        'min_temp': 22 + (index % 3),
        'condition': index % 2 == 0 ? 'Sunny' : 'Cloudy',
      };
    });
  }
} 