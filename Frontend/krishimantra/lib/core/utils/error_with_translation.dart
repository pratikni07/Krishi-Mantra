import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../utils/language_helper.dart';
import '../utils/error_handler.dart';

/// A utility class that enhances error handling with translations
/// This ensures error messages are displayed in the user's selected language
class TranslatedErrorHandler {
  /// Shows a translated error message in a snackbar
  static Future<void> showError(dynamic error, {BuildContext? context}) async {
    final errorType = ErrorHandler.handleApiError(error);
    final errorMessage = ErrorHandler.getErrorMessage(errorType);

    // Translate the error message
    final translatedMessage =
        await LanguageHelper.batchTranslate([errorMessage]);

    // Show error message without blocking the UI
    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(translatedMessage.first),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Dismiss',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
    } else {
      // Fallback to Get.snackbar if context is not available
      Get.snackbar(
        await LanguageHelper.batchTranslate(['Error'])
            .then((list) => list.first),
        translatedMessage.first,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
        isDismissible: true,
        borderRadius: 8,
        margin: const EdgeInsets.all(8),
      );
    }
  }

  /// Gets a translated error widget for embedded use
  static Future<Widget> getErrorWidget(
    dynamic error, {
    VoidCallback? onRetry,
    bool showRetry = true,
  }) async {
    final errorType = ErrorHandler.handleApiError(error);

    return FutureBuilder<List<String>>(
      future: LanguageHelper.batchTranslate([
        _getErrorTitle(errorType),
        ErrorHandler.getErrorMessage(errorType),
        'Try Again'
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final translatedTitle = snapshot.data![0];
        final translatedMessage = snapshot.data![1];
        final translatedRetry = snapshot.data![2];

        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildErrorIcon(errorType),
                const SizedBox(height: 24),
                Text(
                  translatedTitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                Text(
                  translatedMessage,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                if (showRetry && onRetry != null) ...[
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: Text(translatedRetry),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// Creates a standard error widget with a retry button
  static Widget buildSimpleErrorWidget({
    required VoidCallback onRetry,
    String message = 'Something went wrong. Please try again.',
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 56, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Creates a widget for empty state
  static Widget buildEmptyStateWidget({
    required String message,
    IconData icon = Icons.search_off,
    VoidCallback? onAction,
    String? actionText,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            if (onAction != null && actionText != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onAction,
                child: Text(actionText),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  /// Builds an error icon based on error type
  static Widget _buildErrorIcon(ErrorType errorType) {
    IconData iconData;
    Color iconColor;

    switch (errorType) {
      case ErrorType.network:
        iconData = Icons.wifi_off;
        iconColor = Colors.orange;
        break;
      case ErrorType.server:
        iconData = Icons.cloud_off;
        iconColor = Colors.orange;
        break;
      case ErrorType.unauthorized:
        iconData = Icons.lock;
        iconColor = Colors.red;
        break;
      case ErrorType.notFound:
        iconData = Icons.search_off;
        iconColor = Colors.orange;
        break;
      case ErrorType.timeout:
        iconData = Icons.timer_off;
        iconColor = Colors.orange;
        break;
      case ErrorType.unknown:
      default:
        iconData = Icons.error_outline;
        iconColor = Colors.red;
    }

    return Icon(
      iconData,
      size: 80,
      color: iconColor,
    );
  }

  /// Gets the error title based on error type
  static String _getErrorTitle(ErrorType errorType) {
    switch (errorType) {
      case ErrorType.network:
        return 'No Internet Connection';
      case ErrorType.server:
        return 'Connection Issue';
      case ErrorType.unauthorized:
        return 'Session Expired';
      case ErrorType.notFound:
        return 'Not Found';
      case ErrorType.timeout:
        return 'Connection Timeout';
      case ErrorType.unknown:
      default:
        return 'Something Went Wrong';
    }
  }
}
