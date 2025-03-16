import 'package:krishimantra/data/models/notification_model.dart';
import 'package:krishimantra/data/models/notification_preferences_model.dart';
import 'package:krishimantra/data/services/api_service.dart';

class NotificationRepository {
  final ApiService _apiService;
  static const String _baseUrl = '/api/notification';

  NotificationRepository(this._apiService);

  // Get user notifications with pagination
  Future<Map<String, dynamic>> getUserNotifications(String userId,
      {int page = 1, int limit = 20}) async {
    try {
      final response = await _apiService.get(
        '$_baseUrl/users/$userId/notifications',
        queryParameters: {'page': page, 'limit': limit},
      );

      final responseData = response.data;

      final notifications = (responseData['data'] as List)
          .map((json) => NotificationModel.fromJson(json))
          .toList();

      return {
        'notifications': notifications,
        'pagination': responseData['pagination'],
      };
    } catch (e) {
      rethrow;
    }
  }

  // Create a notification
  Future<NotificationModel> createNotification(
      NotificationModel notification) async {
    try {
      final response = await _apiService.post(
        '$_baseUrl/notifications',
        data: notification.toJson(),
      );

      return NotificationModel.fromJson(response.data['data']);
    } catch (e) {
      rethrow;
    }
  }

  // Create bulk notifications
  Future<Map<String, dynamic>> createBulkNotifications(
      List<NotificationModel> notifications) async {
    try {
      final response = await _apiService.post(
        '$_baseUrl/notifications/bulk',
        data: {'notifications': notifications.map((n) => n.toJson()).toList()},
      );

      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  // Mark notification as read
  Future<NotificationModel> markAsRead(
      String userId, String notificationId) async {
    try {
      final response = await _apiService.patch(
        '$_baseUrl/users/$userId/notifications/$notificationId/read',
      );

      return NotificationModel.fromJson(response.data['data']);
    } catch (e) {
      rethrow;
    }
  }

  // Get user notification preferences
  Future<NotificationPreferencesModel> getUserPreferences(String userId) async {
    try {
      final response = await _apiService.get(
        '$_baseUrl/users/$userId/preferences',
      );

      return NotificationPreferencesModel.fromJson(response.data['data']);
    } catch (e) {
      rethrow;
    }
  }

  // Update user notification preferences
  Future<NotificationPreferencesModel> updateUserPreferences(
      String userId, Map<String, dynamic> preferencesData) async {
    try {
      final response = await _apiService.put(
        '$_baseUrl/users/$userId/preferences',
        data: preferencesData,
      );

      return NotificationPreferencesModel.fromJson(response.data['data']);
    } catch (e) {
      rethrow;
    }
  }
}
