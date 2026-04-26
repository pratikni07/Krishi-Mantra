import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';

import '../../core/constants/api_constants.dart';
import '../../core/utils/app_logger.dart';
import 'api_service.dart';
import 'feature_flag_service.dart';

/// Mobile weather facade. v2 calls the backend's `/api/weather/7day` endpoint
/// which centralizes the OpenWeather/Open-Meteo key on the server, shares a
/// cache with the AI context tree, and removes the API key from the APK.
///
/// Falls back to the legacy direct-OpenWeatherMap path only if the backend
/// call fails AND `OPENWEATHER_API_KEY` was provided at build time. New
/// builds should not set the legacy key.
class WeatherService {
  final Dio _legacyDio = Dio();

  // Build-time legacy fallback. Empty in v2 builds — when set, the service
  // tries the backend first and falls back here on transport failure.
  static const String _legacyApiKey =
      String.fromEnvironment('OPENWEATHER_API_KEY', defaultValue: '');
  final String _legacyBaseUrl = 'https://api.openweathermap.org/data/2.5';

  ApiService? get _api {
    if (Get.isRegistered<ApiService>()) return Get.find<ApiService>();
    return null;
  }

  /// Whether the legacy OWM fallback is available.
  bool get _hasLegacyFallback => _legacyApiKey.isNotEmpty;

  // ---------------------------------------------------------------------------
  // v2 API — backend-backed
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>?> _fetchBackendSnapshot(Position position) async {
    final api = _api;
    if (api == null) return null;
    // Allow ops to instantly route mobile back to the legacy OWM path via
    // the feature-flag endpoint.
    if (Get.isRegistered<FeatureFlagService>() &&
        !Get.find<FeatureFlagService>().weatherViaBackend) {
      return null;
    }
    try {
      final response = await api.get(
        ApiConstants.WEATHER_7DAY,
        queryParameters: {'lat': position.latitude, 'lon': position.longitude},
        cacheDuration: const Duration(minutes: 10),
      );
      if (response.statusCode != 200 || response.data is! Map) return null;
      final data = Map<String, dynamic>.from(response.data as Map);
      if (data['success'] != true) return null;
      return data;
    } catch (e) {
      logger.w('Backend weather call failed: $e', tag: 'WeatherService');
      return null;
    }
  }

  /// Today's weather (the index-3 day in the D-3..D+3 window).
  Future<Map<String, dynamic>> getWeatherData(Position position) async {
    final snap = await _fetchBackendSnapshot(position);
    if (snap != null) {
      final days = (snap['days'] as List?) ?? const [];
      if (days.length >= 4) {
        final today = Map<String, dynamic>.from(days[3] as Map);
        final tempAvg = ((today['tempMin'] ?? 25.0) + (today['tempMax'] ?? 25.0)) / 2;
        final condition = _normalizeCondition(today['condition']?.toString());
        return {
          'temperature': tempAvg.round(),
          'feels_like': tempAvg.round(),
          'humidity': (today['humidityMean'] ?? 65).round(),
          'wind_speed': ((today['windSpeedKmh'] ?? 12) as num).round(),
          'condition': condition,
          'cloudiness': _cloudinessForCondition(condition),
          'rain_chance': _rainChanceForRainfall(
            (today['rainfallMm'] ?? 0).toDouble(),
          ),
          'icon': _iconFor(condition),
          'asOf': snap['asOf'],
        };
      }
    }

    if (_hasLegacyFallback) {
      return _legacyGetWeatherData(position);
    }
    return _getDefaultWeatherData();
  }

  /// 24-hour hourly forecast. Backend doesn't expose hourly — synthesize a
  /// rough hourly curve from today/tomorrow's min/max for now. The AI-related
  /// tree only consumes daily data, so this is purely UI candy on the home
  /// screen and a smooth interpolation is good enough.
  Future<List<Map<String, dynamic>>> getHourlyForecast(Position position) async {
    final snap = await _fetchBackendSnapshot(position);
    if (snap != null) {
      final days = (snap['days'] as List?) ?? const [];
      if (days.length >= 4) {
        final today = Map<String, dynamic>.from(days[3] as Map);
        final tomorrow = days.length > 4
            ? Map<String, dynamic>.from(days[4] as Map)
            : today;
        final out = <Map<String, dynamic>>[];
        final start = DateTime.now();
        final tMin = (today['tempMin'] ?? 22).toDouble();
        final tMax = (today['tempMax'] ?? 32).toDouble();
        final tomMin = (tomorrow['tempMin'] ?? tMin).toDouble();
        final tomMax = (tomorrow['tempMax'] ?? tMax).toDouble();
        final cond = _normalizeCondition(today['condition']?.toString());
        for (int h = 0; h < 24; h++) {
          final phase = h <= 14 ? (h - 5).abs() / 9.0 : (24 - h) / 9.0;
          final base = h < 12 ? tMin + (tMax - tMin) * phase.clamp(0.0, 1.0)
                              : tomMin + (tomMax - tomMin) * phase.clamp(0.0, 1.0);
          out.add({
            'time': start.add(Duration(hours: h)),
            'temperature': base.round(),
            'condition': cond,
            'icon': _iconFor(cond),
          });
        }
        return out;
      }
    }

    if (_hasLegacyFallback) {
      return _legacyGetHourlyForecast(position);
    }
    return _getDefaultHourlyForecast();
  }

  /// Map the 7-day backend window directly into the existing UI shape.
  Future<List<Map<String, dynamic>>> getWeeklyForecast(Position position) async {
    final snap = await _fetchBackendSnapshot(position);
    if (snap != null) {
      final days = (snap['days'] as List?) ?? const [];
      return days.map((raw) {
        final m = Map<String, dynamic>.from(raw as Map);
        final dateStr = m['date']?.toString();
        return {
          'date': dateStr != null
              ? DateTime.parse(dateStr).toLocal()
              : DateTime.now(),
          'max_temp': (m['tempMax'] ?? 30).round(),
          'min_temp': (m['tempMin'] ?? 22).round(),
          'condition': _normalizeCondition(m['condition']?.toString()),
          'rainfallMm': (m['rainfallMm'] ?? 0).toDouble(),
        };
      }).toList();
    }

    if (_hasLegacyFallback) {
      return _legacyGetWeeklyForecast(position);
    }
    return _getDefaultWeeklyForecast();
  }

  // ---------------------------------------------------------------------------
  // Backend label normalization
  // ---------------------------------------------------------------------------

  String _normalizeCondition(String? raw) {
    final s = (raw ?? '').toLowerCase();
    if (s.contains('thunder')) return 'Stormy';
    if (s.contains('rain') || s.contains('shower') || s.contains('drizzle')) {
      return 'Rainy';
    }
    if (s.contains('snow')) return 'Snowy';
    if (s.contains('fog')) return 'Foggy';
    if (s.contains('cloud')) return 'Cloudy';
    if (s.contains('sun') || s.contains('clear')) return 'Sunny';
    return 'Cloudy';
  }

  int _cloudinessForCondition(String condition) {
    switch (condition) {
      case 'Sunny':
        return 10;
      case 'Cloudy':
        return 70;
      case 'Rainy':
        return 90;
      case 'Stormy':
        return 95;
      case 'Foggy':
        return 80;
      default:
        return 30;
    }
  }

  int _rainChanceForRainfall(double mm) {
    if (mm >= 10) return 95;
    if (mm >= 5) return 80;
    if (mm >= 1) return 60;
    if (mm > 0) return 30;
    return 5;
  }

  String _iconFor(String condition) {
    switch (condition) {
      case 'Sunny':
        return '01d';
      case 'Cloudy':
        return '03d';
      case 'Rainy':
        return '10d';
      case 'Stormy':
        return '11d';
      case 'Snowy':
        return '13d';
      case 'Foggy':
        return '50d';
      default:
        return '02d';
    }
  }

  // ---------------------------------------------------------------------------
  // Legacy direct-OpenWeather path — only reachable when OPENWEATHER_API_KEY
  // was injected at build time.
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> _legacyGetWeatherData(Position position) async {
    try {
      final response = await _legacyDio.get(
        '$_legacyBaseUrl/weather',
        queryParameters: {
          'lat': position.latitude,
          'lon': position.longitude,
          'appid': _legacyApiKey,
          'units': 'metric',
        },
        options: Options(
          validateStatus: (status) => true,
          receiveTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 15),
        ),
      );
      if (response.statusCode == 200) {
        final main = response.data['main'] ?? {};
        final clouds = response.data['clouds'] ?? {};
        final wind = response.data['wind'] ?? {};
        final weather = (response.data['weather'] as List?)?.isNotEmpty == true
            ? response.data['weather'][0]
            : {};
        return {
          'temperature': (main['temp'] ?? 25.0).toDouble().round(),
          'feels_like': (main['feels_like'] ?? 25.0).toDouble().round(),
          'humidity': main['humidity'] ?? 65,
          'wind_speed': ((wind['speed'] ?? 0.0) * 3.6).round(),
          'condition': _capitalize(weather['description'] ?? 'Clear'),
          'cloudiness': clouds['all'] ?? 0,
          'rain_chance':
              (((clouds['all'] ?? 0) * 0.4) + ((main['humidity'] ?? 50) * 0.3))
                  .round()
                  .clamp(0, 100),
          'icon': weather['icon'] ?? '01d',
        };
      }
      return _getDefaultWeatherData();
    } catch (e) {
      logger.e('Legacy weather call failed', tag: 'WeatherService', error: e);
      return _getDefaultWeatherData();
    }
  }

  Future<List<Map<String, dynamic>>> _legacyGetHourlyForecast(
      Position position) async {
    try {
      final response = await _legacyDio.get(
        '$_legacyBaseUrl/forecast',
        queryParameters: {
          'lat': position.latitude,
          'lon': position.longitude,
          'appid': _legacyApiKey,
          'units': 'metric',
          'cnt': 8,
        },
        options: Options(
          validateStatus: (status) => true,
          receiveTimeout: const Duration(seconds: 15),
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
            'time': DateTime.fromMillisecondsSinceEpoch(
                (item['dt'] ?? 0) * 1000),
            'temperature': (main['temp'] ?? 25.0).toDouble().round(),
            'condition': _normalizeCondition(weather['main']?.toString()),
            'icon': weather['icon'] ?? '01d',
          };
        }).toList();
      }
      return _getDefaultHourlyForecast();
    } catch (e) {
      return _getDefaultHourlyForecast();
    }
  }

  Future<List<Map<String, dynamic>>> _legacyGetWeeklyForecast(
      Position position) async {
    return _getDefaultWeeklyForecast();
  }

  String _capitalize(String s) {
    if (s.isEmpty) return 'Clear';
    return s
        .split(' ')
        .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  // ---------------------------------------------------------------------------
  // Defaults (used when both backend + legacy fail)
  // ---------------------------------------------------------------------------

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
