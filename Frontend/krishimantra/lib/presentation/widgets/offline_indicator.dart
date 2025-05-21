import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../controllers/connectivity_controller.dart';

/// Offline indicator banner that shows when app is offline
/// Can be added to the top of screens that need network connectivity
class OfflineIndicator extends StatelessWidget {
  final bool showOfflineOnly;

  const OfflineIndicator({
    Key? key,
    this.showOfflineOnly = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ConnectivityController connectivityController =
        Get.find<ConnectivityController>();

    return Obx(() {
      if (!connectivityController.isConnected.value) {
        return Container(
          width: double.infinity,
          color: Colors.red,
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.wifi_off,
                color: Colors.white,
                size: 16,
              ),
              SizedBox(width: 8),
              Text(
                'You are currently offline',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      } else {
        return const SizedBox.shrink();
      }
    });
  }
}

/// A full screen indicator to show when there's no connectivity
/// and no cached data available
class OfflineFullScreenIndicator extends StatelessWidget {
  final VoidCallback? onRetry;

  const OfflineFullScreenIndicator({
    Key? key,
    this.onRetry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off,
              size: 80,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              'You\'re offline',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'No cached data available. Please check your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            if (onRetry != null)
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
