import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/colors.dart';
import '../../../data/models/notification_model.dart';
import '../../controllers/notification_controller.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  late final NotificationController _controller;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller = Get.find<NotificationController>();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _controller.loadMoreNotifications();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppColors.green,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.white),
        actions: [
          Obx(() {
            if (_controller.unreadCount.value > 0) {
              return TextButton(
                onPressed: () => _controller.markAllAsRead(),
                child: const Text(
                  'Mark all read',
                  style: TextStyle(color: AppColors.white),
                ),
              );
            }
            return const SizedBox.shrink();
          }),
        ],
      ),
      body: Obx(() {
        if (_controller.isLoading && _controller.notifications.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.green),
          );
        }

        if (_controller.hasError && _controller.notifications.isEmpty) {
          return _buildErrorWidget();
        }

        if (_controller.notifications.isEmpty) {
          return _buildEmptyWidget();
        }

        return RefreshIndicator(
          onRefresh: _controller.refreshNotifications,
          color: AppColors.green,
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _controller.notifications.length +
                (_controller.isLoadingMore.value ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _controller.notifications.length) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(color: AppColors.green),
                  ),
                );
              }

              final notification = _controller.notifications[index];
              return _NotificationItem(
                notification: notification,
                controller: _controller,
              );
            },
          ),
        );
      }),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to load notifications',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _controller.refreshNotifications,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.green,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 80,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 16),
          Text(
            'No notifications yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'When you get notifications, they\'ll appear here',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationItem extends StatelessWidget {
  final NotificationModel notification;
  final NotificationController controller;

  const _NotificationItem({
    required this.notification,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final isUnread = notification.status != 'read';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isUnread ? AppColors.green.withOpacity(0.05) : AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUnread ? AppColors.green.withOpacity(0.2) : AppColors.borderLight,
        ),
      ),
      child: InkWell(
        onTap: () => controller.navigateToNotification(notification),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildIcon(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isUnread ? FontWeight.w600 : FontWeight.w500,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                        if (isUnread)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textLight,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      controller.formatNotificationTime(notification.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    IconData iconData;
    Color iconColor;

    switch (notification.category) {
      case 'new_post':
        iconData = Icons.article_outlined;
        iconColor = AppColors.green;
        break;
      case 'consultant_service':
        iconData = Icons.chat_bubble_outline;
        iconColor = AppColors.info;
        break;
      case 'crop_care_ai':
        iconData = Icons.smart_toy_outlined;
        iconColor = AppColors.orange;
        break;
      case 'new_reel':
        iconData = Icons.video_library_outlined;
        iconColor = Colors.purple;
        break;
      case 'farm_videos':
        iconData = Icons.play_circle_outline;
        iconColor = Colors.red;
        break;
      case 'system':
      default:
        iconData = Icons.notifications_outlined;
        iconColor = AppColors.textLight;
        break;
    }

    // Check for specific notification types from data
    final notificationData = notification.data;
    if (notificationData != null) {
      final type = notificationData['type'] as String?;
      if (type == 'like') {
        iconData = Icons.favorite_outline;
        iconColor = Colors.red;
      } else if (type == 'comment' || type == 'reply') {
        iconData = Icons.comment_outlined;
        iconColor = AppColors.info;
      } else if (type == 'message') {
        iconData = Icons.message_outlined;
        iconColor = AppColors.green;
      }
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        iconData,
        size: 22,
        color: iconColor,
      ),
    );
  }
}
