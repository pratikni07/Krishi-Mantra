import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:krishimantra/core/constants/colors.dart';
import 'package:krishimantra/data/services/api_service.dart';
import '../../core/utils/error_with_translation.dart';

/// Widget to display network errors with appropriate visuals and retry option
class NetworkErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final bool showRetry;
  final double? height;

  const NetworkErrorWidget({
    Key? key,
    required this.message,
    required this.onRetry,
    this.showRetry = true,
    this.height,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(
              Icons.signal_wifi_statusbar_connected_no_internet_4,
              size: 64,
              color: AppColors.orange,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textGrey,
              ),
            ),
            if (showRetry) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.green,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Widget specifically for connection reset errors that may be temporary
class ConnectionResetErrorWidget extends StatelessWidget {
  final VoidCallback onRetry;
  final double? height;

  const ConnectionResetErrorWidget({
    Key? key,
    required this.onRetry,
    this.height,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return NetworkErrorWidget(
      message:
          'Connection to the server was interrupted. This is often temporary. Please try again in a moment.',
      onRetry: onRetry,
      height: height,
    );
  }
}

/// Widget for when the service is temporarily unavailable (circuit breaker open)
class ServiceUnavailableWidget extends StatelessWidget {
  final VoidCallback onRetry;
  final double? height;

  const ServiceUnavailableWidget({
    Key? key,
    required this.onRetry,
    this.height,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_off,
              size: 64,
              color: AppColors.orange,
            ),
            const SizedBox(height: 16),
            const Text(
              'Our service is temporarily unavailable due to high traffic or maintenance.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textGrey,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please try again in 1-2 minutes.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textGrey,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Extension to handle different error types and return appropriate error widgets
extension ErrorWidgetHelper on BuildContext {
  Widget getErrorWidget(dynamic error, VoidCallback onRetry, {double? height}) {
    if (error is ConnectionResetException) {
      return ConnectionResetErrorWidget(onRetry: onRetry, height: height);
    } else if (error is ServiceUnavailableException) {
      return ServiceUnavailableWidget(onRetry: onRetry, height: height);
    } else if (error is NoInternetException) {
      return NetworkErrorWidget(
        message:
            'No internet connection. Please check your network settings and try again.',
        onRetry: onRetry,
        height: height,
      );
    } else if (error is RequestTimeoutException) {
      return NetworkErrorWidget(
        message:
            'The request timed out. The server might be overloaded, please try again later.',
        onRetry: onRetry,
        height: height,
      );
    } else {
      // Generic error widget for other types of errors
      return NetworkErrorWidget(
        message: error.toString(),
        onRetry: onRetry,
        height: height,
      );
    }
  }
}

/// Snackbar helper for network errors
void showNetworkErrorSnackbar(dynamic error) {
  String message;
  IconData icon;
  bool showRetryButton = false;

  if (error is ConnectionResetException) {
    message = 'Connection reset. Please try again.';
    icon = Icons.sync_problem;
    showRetryButton = true;
  } else if (error is ServiceUnavailableException) {
    message = 'Service temporarily unavailable. Please try again in a minute.';
    icon = Icons.cloud_off;
  } else if (error is NoInternetException) {
    message = 'No internet connection';
    icon = Icons.signal_wifi_off;
  } else if (error is RequestTimeoutException) {
    message = 'Request timed out';
    icon = Icons.timer_off;
    showRetryButton = true;
  } else {
    message = error.toString();
    icon = Icons.error_outline;
  }

  final snackBar = GetSnackBar(
    message: message,
    icon: Icon(icon, color: Colors.white),
    duration: const Duration(seconds: 3),
    backgroundColor: AppColors.textGrey,
    borderRadius: 8,
    margin: const EdgeInsets.all(16),
    padding: const EdgeInsets.all(16),
    mainButton: showRetryButton
        ? TextButton(
            onPressed: () => Get.back(), // Close the snackbar
            child: const Text("RETRY", style: TextStyle(color: Colors.white)),
          )
        : null,
  );

  Get.showSnackbar(snackBar);
}

/// A collection of reusable error widgets for consistent error display
class ErrorWidgets {
  /// Widget for network connection errors
  static Widget networkError({
    required VoidCallback onRetry,
    String? message,
  }) {
    return TranslatedErrorHandler.buildSimpleErrorWidget(
      onRetry: onRetry,
      message: message ??
          'No internet connection. Please check your network and try again.',
    );
  }

  /// Widget for empty states (no data found)
  static Widget emptyState({
    required String message,
    IconData icon = Icons.search_off,
    VoidCallback? onAction,
    String? actionText,
  }) {
    return TranslatedErrorHandler.buildEmptyStateWidget(
      message: message,
      icon: icon,
      onAction: onAction,
      actionText: actionText,
    );
  }

  /// Widget for generic errors
  static Widget genericError({
    required VoidCallback onRetry,
    String? message,
  }) {
    return TranslatedErrorHandler.buildSimpleErrorWidget(
      onRetry: onRetry,
      message: message ?? 'Something went wrong. Please try again.',
    );
  }

  /// Widget for permission denied errors
  static Widget permissionError({
    required VoidCallback onAction,
    String? message,
    String actionText = 'Open Settings',
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.no_encryption_gmailerrorred,
                size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              message ??
                  'Permission denied. Please grant the required permissions to use this feature.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.settings),
              label: Text(actionText),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Widget for loading state with custom message
  static Widget loading({String? message}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Widget for maintenance mode
  static Widget maintenanceMode({
    VoidCallback? onRetry,
    String? message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.construction, size: 64, color: Colors.amber.shade700),
            const SizedBox(height: 16),
            Text(
              message ??
                  'We\'re currently undergoing maintenance. Please try again later.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.green,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Widget for unauthorized access (login required)
  static Widget unauthorized({
    required VoidCallback onLogin,
    String? message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 64, color: Colors.blue.shade700),
            const SizedBox(height: 16),
            Text(
              message ?? 'You need to log in to access this feature.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onLogin,
              icon: const Icon(Icons.login),
              label: const Text('Log In'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
