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
      final data =
          responseData is Map<String, dynamic> ? responseData['data'] : null;

      // Handle response shapes:
      // 1) { data: [..], pagination: {...} }  (current backend)
      // 2) { data: { notifications: [..], pagination: {...} } }
      // 3) { notifications: [..], pagination: {...} }
      List<dynamic> notificationsList = [];
      if (data is List) {
        notificationsList = data;
      } else if (data is Map<String, dynamic> &&
          data['notifications'] is List) {
        notificationsList = data['notifications'] as List<dynamic>;
      } else if (responseData is Map<String, dynamic> &&
          responseData['notifications'] is List) {
        notificationsList = responseData['notifications'] as List<dynamic>;
      }

      final notifications = notificationsList
          .whereType<Map>()
          .map(
            (json) => NotificationModel.fromJson(
              Map<String, dynamic>.from(json),
            ),
          )
          .toList();

      final pagination = (responseData is Map<String, dynamic> &&
              responseData['pagination'] is Map)
          ? Map<String, dynamic>.from(responseData['pagination'] as Map)
          : (data is Map<String, dynamic> && data['pagination'] is Map)
              ? Map<String, dynamic>.from(data['pagination'] as Map)
              : {
                  'page': page,
                  'limit': limit,
                  'total': notifications.length,
                  'pages': 1,
                };

      return {
        'notifications': notifications,
        'pagination': pagination,
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

  // Track user interaction (click, dismiss, etc.)
  Future<Map<String, dynamic>> trackInteraction(
    String userId,
    String notificationId, {
    String action = 'clicked',
  }) async {
    try {
      final response = await _apiService.patch(
        '$_baseUrl/users/$userId/notifications/$notificationId/interaction',
        data: {'action': action},
      );
      return Map<String, dynamic>.from(response.data as Map);
    } catch (e) {
      rethrow;
    }
  }

  // Mute notification sources for a user
  Future<Map<String, dynamic>> muteSources(
    String userId, {
    List<String> entityIds = const [],
    List<String> categories = const [],
  }) async {
    try {
      final response = await _apiService.patch(
        '$_baseUrl/users/$userId/preferences/mute',
        data: {
          if (entityIds.isNotEmpty) 'entityIds': entityIds,
          if (categories.isNotEmpty) 'categories': categories,
        },
      );
      return Map<String, dynamic>.from(response.data as Map);
    } catch (e) {
      rethrow;
    }
  }

  // Unmute notification sources for a user
  Future<Map<String, dynamic>> unmuteSources(
    String userId, {
    List<String> entityIds = const [],
    List<String> categories = const [],
  }) async {
    try {
      final response = await _apiService.patch(
        '$_baseUrl/users/$userId/preferences/unmute',
        data: {
          if (entityIds.isNotEmpty) 'entityIds': entityIds,
          if (categories.isNotEmpty) 'categories': categories,
        },
      );
      return Map<String, dynamic>.from(response.data as Map);
    } catch (e) {
      rethrow;
    }
  }

  // Trigger a test notification for current user
  Future<NotificationModel> sendTestNotification(
    String userId, {
    Map<String, dynamic> payload = const {},
  }) async {
    try {
      final response = await _apiService.post(
        '$_baseUrl/users/$userId/notifications/test',
        data: payload,
      );
      return NotificationModel.fromJson(
        Map<String, dynamic>.from(response.data['data'] as Map),
      );
    } catch (e) {
      rethrow;
    }
  }
}
