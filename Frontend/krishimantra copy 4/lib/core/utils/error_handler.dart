import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../data/services/api_service.dart';
import '../../presentation/widgets/error_screen.dart';

enum ErrorType {
  network,
  server,
  unauthorized,
  notFound,
  timeout,
  unknown
}

class ErrorHandler {
  /// Handles API errors globally and returns the appropriate error type
  static ErrorType handleApiError(dynamic error) {
    print('Handling API error: $error (${error.runtimeType})');

    if (error is NoInternetException) {
      return ErrorType.network;
    } else if (error is RequestTimeoutException) {
      return ErrorType.timeout;
    } else if (error is UnauthorizedException) {
      return ErrorType.unauthorized;
    } else if (error is ServerException) {
      return ErrorType.server;
    } else if (error is NotFoundException) {
      return ErrorType.notFound;
    } else if (error is NetworkException) {
      // For network exceptions that aren't specifically internet connection issues
      return ErrorType.server; // Default to server for API errors
    } else if (error.toString().toLowerCase().contains('socket')) {
      return ErrorType.network;
    } else {
      // Default to server error for most unknown errors when communicating with the backend
      return ErrorType.server;
    }
  }

  /// Gets user-friendly error message based on error type
  static String getErrorMessage(ErrorType type) {
    switch (type) {
      case ErrorType.network:
        return 'No internet connection. Please check your connection and try again.';
      case ErrorType.server:
        return 'Unable to connect to server. This could be a temporary issue. Please try again.';
      case ErrorType.unauthorized:
        return 'Session expired. Please login again.';
      case ErrorType.notFound:
        return 'The requested resource was not found.';
      case ErrorType.timeout:
        return 'Request timed out. Please try again.';
      case ErrorType.unknown:
        return 'Something went wrong. Please try again.';
    }
  }

  /// Shows error screen as a fullscreen replacement
  static void showErrorScreen({
    required ErrorType errorType,
    VoidCallback? onRetry,
    bool showRetry = true,
  }) {
    Get.to(() => ErrorScreen(
      errorType: errorType,
      onRetry: onRetry,
      showRetry: showRetry,
    ));
  }

  /// Shows error screen within a specific container
  static Widget getErrorWidget({
    required ErrorType errorType, 
    VoidCallback? onRetry,
    bool showRetry = true,
  }) {
    return ErrorScreen(
      errorType: errorType,
      onRetry: onRetry,
      showRetry: showRetry,
    );
  }
} 