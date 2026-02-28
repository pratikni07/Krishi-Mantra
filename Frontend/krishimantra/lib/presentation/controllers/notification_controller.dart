import 'dart:async';
import 'package:get/get.dart';
import '../../data/models/notification_model.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/services/UserService.dart';
import '../../data/services/SocketService.dart';
import '../../data/services/engagement_service.dart';
import 'base_controller.dart';

class NotificationController extends BaseController {
  final NotificationRepository _notificationRepository;
  final UserService _userService;
  final SocketService _socketService;
  final EngagementService _engagementService = EngagementService();

  final RxList<NotificationModel> notifications = <NotificationModel>[].obs;
  final RxInt unreadCount = 0.obs;
  final RxInt currentPage = 1.obs;
  final RxBool hasMore = true.obs;
  final RxBool isLoadingMore = false.obs;
  final int limit = 20;

  StreamSubscription? _notificationSubscription;

  NotificationController(
    this._notificationRepository,
    this._userService,
    this._socketService,
  );

  @override
  void onInit() {
    super.onInit();
    _setupNotificationListener();
    fetchNotifications();
  }

  @override
  void onClose() {
    _notificationSubscription?.cancel();
    super.onClose();
  }

  /// Setup listener for real-time notifications from WebSocket
  void _setupNotificationListener() {
    // Listen to the socket notification stream
    _notificationSubscription =
        _socketService.notificationStream.listen((data) {
      _handleNewNotification(data);
    });
  }

  /// Handle incoming real-time notification
  void _handleNewNotification(Map<String, dynamic> data) {
    try {
      final notification = NotificationModel.fromJson(data['data'] ?? data);

      // Add to the beginning of the list
      notifications.insert(0, notification);

      // Increment unread count
      unreadCount.value++;

      // Show a local notification or snackbar
      Get.snackbar(
        notification.title,
        notification.body,
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 4),
        onTap: (_) => _onNotificationTap(notification),
      );
    } catch (e) {
      print('Error handling notification: $e');
    }
  }

  /// Fetch notifications from the server
  Future<void> fetchNotifications({bool refresh = false}) async {
    try {
      if (refresh) {
        currentPage.value = 1;
        hasMore.value = true;
        notifications.clear();
      }

      if (!hasMore.value) return;

      if (currentPage.value == 1) {
        setLoading();
      } else {
        isLoadingMore.value = true;
      }

      final userData = await _userService.getUser();
      if (userData == null) {
        throw Exception('User not found');
      }

      final result = await _notificationRepository.getUserNotifications(
        userData.id,
        page: currentPage.value,
        limit: limit,
      );

      final newNotifications =
          result['notifications'] as List<NotificationModel>;
      notifications.addAll(newNotifications);

      final pagination = result['pagination'] as Map<String, dynamic>;
      final totalPages = pagination['pages'] ?? 1;
      hasMore.value = currentPage.value < totalPages;

      if (hasMore.value) {
        currentPage.value++;
      }

      // Count unread notifications
      _updateUnreadCount();

      setLoaded();
    } catch (e) {
      setError(e);
    } finally {
      isLoadingMore.value = false;
    }
  }

  /// Refresh notifications
  Future<void> refreshNotifications() async {
    await fetchNotifications(refresh: true);
  }

  /// Load more notifications
  Future<void> loadMoreNotifications() async {
    if (isLoadingMore.value || !hasMore.value) return;
    await fetchNotifications();
  }

  /// Mark a notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      final userData = await _userService.getUser();
      if (userData == null) return;

      await _notificationRepository.markAsRead(userData.id, notificationId);

      // Update local state
      final index = notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        final notification = notifications[index];
        if (notification.status != 'read') {
          notifications[index] = NotificationModel(
            id: notification.id,
            userId: notification.userId,
            type: notification.type,
            title: notification.title,
            body: notification.body,
            data: notification.data,
            status: 'read',
            priority: notification.priority,
            category: notification.category,
            scheduledFor: notification.scheduledFor,
            createdAt: notification.createdAt,
            updatedAt: DateTime.now().toIso8601String(),
            pushId: notification.pushId,
          );
          _updateUnreadCount();
        }
      }
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    try {
      final userData = await _userService.getUser();
      if (userData == null) return;

      // Get all unread notification IDs
      final unreadIds = notifications
          .where((n) => n.status != 'read')
          .map((n) => n.id)
          .whereType<String>()
          .toList();

      if (unreadIds.isEmpty) return;

      // Mark each as read (could be optimized with bulk endpoint)
      for (final id in unreadIds) {
        await _notificationRepository.markAsRead(userData.id, id);
      }

      // Update local state
      notifications.value = notifications.map((n) {
        if (n.status != 'read') {
          return NotificationModel(
            id: n.id,
            userId: n.userId,
            type: n.type,
            title: n.title,
            body: n.body,
            data: n.data,
            status: 'read',
            priority: n.priority,
            category: n.category,
            scheduledFor: n.scheduledFor,
            createdAt: n.createdAt,
            updatedAt: DateTime.now().toIso8601String(),
            pushId: n.pushId,
          );
        }
        return n;
      }).toList();

      unreadCount.value = 0;
    } catch (e) {
      print('Error marking all as read: $e');
    }
  }

  /// Handle notification tap
  void _onNotificationTap(NotificationModel notification) {
    final notificationId = notification.id;

    // Mark as read first
    if (notificationId != null) {
      markAsRead(notificationId);

      // Track notification click engagement
      _engagementService.trackNotificationClick(
        notificationId,
        notification.type,
      );

      // Track click interaction in notification-service
      _trackInteraction(notificationId, action: 'clicked');
    }

    // Navigate based on notification data
    final data = notification.data;
    if (data != null) {
      final screen = data['screen'] as String?;
      final feedId = data['feedId'] as String?;
      final chatId = data['chatId'] as String?;

      if (screen == 'FeedDetailsScreen' && feedId != null) {
        Get.toNamed('/feed-details', arguments: feedId);
      } else if (screen == 'ChatDetailScreen' && chatId != null) {
        Get.toNamed('/chat-detail', arguments: chatId);
      }
    }
  }

  /// Navigate to the appropriate screen based on notification
  void navigateToNotification(NotificationModel notification) {
    _onNotificationTap(notification);
  }

  Future<void> _trackInteraction(String notificationId,
      {String action = 'clicked'}) async {
    try {
      final userData = await _userService.getUser();
      if (userData == null) return;

      await _notificationRepository.trackInteraction(
        userData.id,
        notificationId,
        action: action,
      );
    } catch (_) {
      // Interaction tracking should never block the user flow.
    }
  }

  /// Update unread count
  void _updateUnreadCount() {
    unreadCount.value = notifications.where((n) => n.status != 'read').length;
  }

  /// Get notification icon based on category
  String getNotificationIcon(String category) {
    switch (category) {
      case 'new_post':
        return 'assets/icons/feed.png';
      case 'consultant_service':
        return 'assets/icons/chat.png';
      case 'crop_care_ai':
        return 'assets/icons/ai.png';
      case 'new_reel':
        return 'assets/icons/reel.png';
      case 'farm_videos':
        return 'assets/icons/video.png';
      case 'system':
      default:
        return 'assets/icons/notification.png';
    }
  }

  /// Format notification time
  String formatNotificationTime(String createdAt) {
    try {
      final dateTime = DateTime.parse(createdAt);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      }
    } catch (e) {
      return '';
    }
  }
}
