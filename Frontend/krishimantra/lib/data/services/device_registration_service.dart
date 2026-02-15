import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;
import '../../core/utils/app_logger.dart';
import 'api_service.dart';

/// Service for IoT Device Registration
class DeviceRegistrationService extends GetxService {
  final ApiService _apiService = Get.find<ApiService>();

  /// Submit device registration
  /// Returns registration ID if successful
  Future<Map<String, dynamic>> registerDevice({
    required String name,
    required String phone,
    String? email,
    required String address,
    required String deviceType, // 'auto_pump' or 'krishi_doctor'
  }) async {
    try {
      logger.i('Submitting device registration for $deviceType', tag: 'DeviceRegistration');

      final data = {
        'name': name,
        'phone': phone,
        'address': address,
        'deviceType': deviceType,
      };

      if (email != null && email.isNotEmpty) {
        data['email'] = email;
      }

      final response = await _apiService.post(
        '/api/main/api/device-registration',
        data: data,
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        logger.i('Device registration successful', tag: 'DeviceRegistration');
        return response.data['data'] ?? response.data;
      } else {
        throw Exception(
            response.data['message'] ?? 'Failed to submit registration');
      }
    } on DioException catch (e) {
      logger.e('Device registration failed: ${e.message}', tag: 'DeviceRegistration');
      if (e.response != null) {
        throw Exception(
            e.response?.data['message'] ?? 'Failed to submit registration');
      }
      throw Exception('Network error. Please check your connection.');
    } catch (e) {
      logger.e('Unexpected error during registration: $e', tag: 'DeviceRegistration');
      throw Exception('An unexpected error occurred. Please try again.');
    }
  }

  /// Get device types with their details
  Map<String, Map<String, dynamic>> getDeviceTypes() {
    return {
      'auto_pump': {
        'name': 'Auto Pump Starter',
        'subtitle': 'Smart Water Management System',
        'description':
            'Transform your irrigation with our intelligent auto pump system. Automatically control water pumps based on soil moisture levels, scheduled timings, and weather conditions.',
        'icon': '💧',
        'features': [
          'Remote pump on/off control from your mobile phone',
          'Schedule automatic watering times (morning, evening, or custom)',
          'Real-time water usage and electricity consumption tracking',
          'Automatic shut-off when soil moisture threshold is reached',
          'SMS/push alerts for pump status and errors',
          'Integration with soil moisture sensors',
          'Power surge and overload protection',
          'Compatible with single and three-phase pumps',
          'Weather-based irrigation recommendations',
          'Historical usage analytics and reports',
        ],
        'testimonials': [
          {
            'text':
                'The auto pump has saved me ₹3000 per month in electricity costs. It waters my fields exactly when needed, no more, no less.',
            'author': 'Ramesh Kumar, Maharashtra',
            'rating': 5,
          },
          {
            'text':
                "I can now control my pump from anywhere. Even when I'm in the city, my farm gets watered on schedule.",
            'author': 'Suresh Patil, Karnataka',
            'rating': 5,
          },
        ],
      },
      'krishi_doctor': {
        'name': 'Krishi Doctor',
        'subtitle': 'Complete Crop Health Monitoring System',
        'description':
            'Your 24/7 crop health expert. Monitor soil nutrients, weather conditions, and get AI-powered insights to maximize your crop yield and prevent diseases before they spread.',
        'icon': '🌾',
        'features': [
          'Soil NPK, pH, moisture & temperature sensors',
          'Weather station (humidity, rainfall, wind, pressure)',
          'AI-powered crop health analysis',
          'Disease & pest early warning alerts',
          'Historical data & trend analytics',
          'Light intensity measurement for optimal growth',
          'Fertilizer application suggestions based on NPK levels',
          'Irrigation recommendations based on soil moisture',
          'Integration with Krishi Mantra app for expert consultations',
          'Crop-specific recommendations',
        ],
        'testimonials': [
          {
            'text':
                'Krishi Doctor detected low nitrogen in my wheat field before visible symptoms appeared. Early fertilizer application saved my entire crop.',
            'author': 'Vijay Singh, Punjab',
            'rating': 5,
          },
          {
            'text':
                'The weather alerts helped me protect my tomatoes from an unexpected frost. Worth every rupee!',
            'author': 'Lakshmi Devi, Tamil Nadu',
            'rating': 5,
          },
        ],
      },
    };
  }
}
