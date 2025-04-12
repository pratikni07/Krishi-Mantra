import 'package:flutter/material.dart';
import '../../core/utils/error_handler.dart';

class ErrorScreen extends StatelessWidget {
  final ErrorType errorType;
  final VoidCallback? onRetry;
  final bool showRetry;

  const ErrorScreen({
    Key? key,
    required this.errorType,
    this.onRetry,
    this.showRetry = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildErrorIcon(),
            const SizedBox(height: 24),
            Text(
              _getErrorTitle(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              ErrorHandler.getErrorMessage(errorType),
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
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
  }

  Widget _buildErrorIcon() {
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

  String _getErrorTitle() {
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