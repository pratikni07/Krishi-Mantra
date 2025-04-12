import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class LocationService {
  static const String LOCATION_CACHE_KEY = 'user_location_cache';
  static const int LOCATION_CACHE_HOURS = 12;

  Future<Position?> getCurrentPosition({bool useCachedLocation = true}) async {
    if (useCachedLocation) {
      final cachedLocation = await _getCachedLocation();
      if (cachedLocation != null) {
        return cachedLocation;
      }
    }
    
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return null;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return null;
    }

    try {
      final position = await Geolocator.getCurrentPosition();
      // Cache the location
      _cacheLocation(position);
      return position;
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }
  
  // Cache current location
  Future<void> _cacheLocation(Position position) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final locationData = {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': DateTime.now().toIso8601String(),
      };
      await prefs.setString(LOCATION_CACHE_KEY, jsonEncode(locationData));
    } catch (e) {
      print('Error caching location: $e');
    }
  }
  
  // Get cached location if valid
  Future<Position?> _getCachedLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final locationJson = prefs.getString(LOCATION_CACHE_KEY);
      
      if (locationJson == null) return null;
      
      final locationData = jsonDecode(locationJson) as Map<String, dynamic>;
      final timestamp = DateTime.parse(locationData['timestamp']);
      final now = DateTime.now();
      
      // Check if cached location is still valid
      if (now.difference(timestamp).inHours <= LOCATION_CACHE_HOURS) {
        return Position.fromMap({
          'latitude': locationData['latitude'],
          'longitude': locationData['longitude'],
          'timestamp': timestamp.millisecondsSinceEpoch,
          'accuracy': 0.0,
          'altitude': 0.0,
          'heading': 0.0,
          'speed': 0.0,
          'speedAccuracy': 0.0,
        });
      }
    } catch (e) {
      print('Error retrieving cached location: $e');
    }
    return null;
  }
} 