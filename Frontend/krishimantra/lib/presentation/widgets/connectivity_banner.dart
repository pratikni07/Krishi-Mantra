import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants/colors.dart';
import '../controllers/connectivity_controller.dart';

/// Persistent thin banner that appears at the top of any screen when the
/// device drops offline (or the user toggled offline mode). Stays put
/// while disconnected so users don't keep tapping retry expecting normal
/// behaviour, and disappears the moment connectivity is restored.
///
/// Usage: wrap a screen body with [ConnectivityBanner.wrap] or place
/// [const ConnectivityBanner()] above your content in a Column.
class ConnectivityBanner extends StatelessWidget {
  const ConnectivityBanner({super.key});

  /// Convenience helper — sticks the banner above [child] without forcing
  /// callers to remember the wrapping pattern.
  static Widget wrap(Widget child) {
    return Column(
      children: [
        const ConnectivityBanner(),
        Expanded(child: child),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<ConnectivityController>()) {
      return const SizedBox.shrink();
    }
    final controller = Get.find<ConnectivityController>();
    return Obx(() {
      final offline = !controller.isConnected.value;
      final manualOffline = controller.isOfflineMode.value;
      if (!offline && !manualOffline) return const SizedBox.shrink();
      return Material(
        color: offline ? Colors.red.shade700 : Colors.amber.shade800,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                Icon(
                  offline ? Icons.wifi_off : Icons.cloud_off,
                  color: AppColors.white,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    offline
                        ? "You're offline — showing cached data."
                        : 'Offline mode is on — tap to go online.',
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (manualOffline && !offline)
                  TextButton(
                    onPressed: () => controller.toggleOfflineMode(false),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.white,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                      minimumSize: const Size(0, 28),
                    ),
                    child: const Text('Go online'),
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
