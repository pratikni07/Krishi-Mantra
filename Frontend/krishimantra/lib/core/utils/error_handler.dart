import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../data/services/api_service.dart';
import '../../data/services/translation_service.dart';
import '../../presentation/widgets/error_screen.dart';
import 'app_logger.dart';

/// Error types for categorizing errors
enum ErrorType {
  network,
  server,
  unauthorized,
  notFound,
  timeout,
  validation,
  circuitBreaker,
  unknown,
}

/// Localized error messages for all supported languages
class LocalizedErrorMessages {
  static const Map<ErrorType, Map<String, String>> _messages = {
    ErrorType.network: {
      'en': 'No internet connection. Please check your connection and try again.',
      'hi': 'इंटरनेट कनेक्शन नहीं है। कृपया अपना कनेक्शन जांचें और पुनः प्रयास करें।',
      'mr': 'इंटरनेट कनेक्शन नाही. कृपया तुमचे कनेक्शन तपासा आणि पुन्हा प्रयत्न करा.',
      'gu': 'ઇન્ટરનેટ કનેક્શન નથી. કૃપા કરીને તમારું કનેક્શન તપાસો અને ફરી પ્રયાસ કરો.',
      'bn': 'ইন্টারনেট সংযোগ নেই। অনুগ্রহ করে আপনার সংযোগ পরীক্ষা করুন এবং আবার চেষ্টা করুন।',
      'ta': 'இணைய இணைப்பு இல்லை. உங்கள் இணைப்பைச் சரிபார்த்து மீண்டும் முயற்சிக்கவும்.',
    },
    ErrorType.server: {
      'en': 'Unable to connect to server. Please try again later.',
      'hi': 'सर्वर से कनेक्ट नहीं हो पा रहा। कृपया बाद में पुनः प्रयास करें।',
      'mr': 'सर्व्हरशी कनेक्ट करता येत नाही. कृपया नंतर पुन्हा प्रयत्न करा.',
      'gu': 'સર્વર સાથે કનેક્ટ થઈ શકતું નથી. કૃપા કરીને પછી ફરી પ્રયાસ કરો.',
      'bn': 'সার্ভারে সংযোগ করতে অক্ষম। অনুগ্রহ করে পরে আবার চেষ্টা করুন।',
      'ta': 'சர்வருடன் இணைக்க முடியவில்லை. பின்னர் மீண்டும் முயற்சிக்கவும்.',
    },
    ErrorType.unauthorized: {
      'en': 'Session expired. Please login again.',
      'hi': 'सत्र समाप्त हो गया। कृपया फिर से लॉगिन करें।',
      'mr': 'सत्र कालबाह्य झाले. कृपया पुन्हा लॉगिन करा.',
      'gu': 'સેશન સમાપ્ત થયું. કૃપા કરીને ફરી લોગિન કરો.',
      'bn': 'সেশন শেষ হয়ে গেছে। অনুগ্রহ করে আবার লগইন করুন।',
      'ta': 'அமர்வு காலாவதியானது. மீண்டும் உள்நுழையவும்.',
    },
    ErrorType.notFound: {
      'en': 'The requested resource was not found.',
      'hi': 'अनुरोधित संसाधन नहीं मिला।',
      'mr': 'विनंती केलेला संसाधन सापडला नाही.',
      'gu': 'વિનંતી કરેલ સંસાધન મળ્યું નથી.',
      'bn': 'অনুরোধিত সম্পদ পাওয়া যায়নি।',
      'ta': 'கோரப்பட்ட ஆதாரம் கிடைக்கவில்லை.',
    },
    ErrorType.timeout: {
      'en': 'Request timed out. Please try again.',
      'hi': 'अनुरोध का समय समाप्त हो गया। कृपया पुनः प्रयास करें।',
      'mr': 'विनंतीची वेळ संपली. कृपया पुन्हा प्रयत्न करा.',
      'gu': 'વિનંતીનો સમય સમાપ્ત થયો. કૃપા કરીને ફરી પ્રયાસ કરો.',
      'bn': 'অনুরোধ সময় শেষ। অনুগ্রহ করে আবার চেষ্টা করুন।',
      'ta': 'கோரிக்கை நேரம் முடிந்தது. மீண்டும் முயற்சிக்கவும்.',
    },
    ErrorType.validation: {
      'en': 'Please check your input and try again.',
      'hi': 'कृपया अपना इनपुट जांचें और पुनः प्रयास करें।',
      'mr': 'कृपया तुमचे इनपुट तपासा आणि पुन्हा प्रयत्न करा.',
      'gu': 'કૃપા કરીને તમારું ઇનપુટ તપાસો અને ફરી પ્રયાસ કરો.',
      'bn': 'অনুগ্রহ করে আপনার ইনপুট পরীক্ষা করুন এবং আবার চেষ্টা করুন।',
      'ta': 'உங்கள் உள்ளீட்டைச் சரிபார்த்து மீண்டும் முயற்சிக்கவும்.',
    },
    ErrorType.circuitBreaker: {
      'en': 'Service temporarily unavailable. Please try again in a few minutes.',
      'hi': 'सेवा अस्थायी रूप से अनुपलब्ध है। कृपया कुछ मिनटों में पुनः प्रयास करें।',
      'mr': 'सेवा तात्पुरती अनुपलब्ध आहे. कृपया काही मिनिटांत पुन्हा प्रयत्न करा.',
      'gu': 'સેવા અસ્થાયી રૂપે અનુપલબ્ધ છે. કૃપા કરીને થોડી મિનિટોમાં ફરી પ્રયાસ કરો.',
      'bn': 'সেবা সাময়িকভাবে অনুপলব্ধ। অনুগ্রহ করে কিছু মিনিটের মধ্যে আবার চেষ্টা করুন।',
      'ta': 'சேவை தற்காலிகமாக கிடைக்கவில்லை. சில நிமிடங்களில் மீண்டும் முயற்சிக்கவும்.',
    },
    ErrorType.unknown: {
      'en': 'Something went wrong. Please try again.',
      'hi': 'कुछ गड़बड़ हो गई। कृपया पुनः प्रयास करें।',
      'mr': 'काहीतरी चूक झाली. कृपया पुन्हा प्रयत्न करा.',
      'gu': 'કંઈક ખોટું થયું. કૃપા કરીને ફરી પ્રયાસ કરો.',
      'bn': 'কিছু ভুল হয়েছে। অনুগ্রহ করে আবার চেষ্টা করুন।',
      'ta': 'ஏதோ தவறு நடந்தது. மீண்டும் முயற்சிக்கவும்.',
    },
  };

  /// Get localized error message
  static Future<String> getMessage(ErrorType type) async {
    try {
      final service = await TranslationService.getInstance();
      final langCode = service.languageCode;

      final typeMessages = _messages[type];
      if (typeMessages != null && typeMessages.containsKey(langCode)) {
        return typeMessages[langCode]!;
      }

      // Fall back to English
      return typeMessages?['en'] ?? _messages[ErrorType.unknown]!['en']!;
    } catch (e) {
      // Return English message if translation service fails
      return _messages[type]?['en'] ?? _messages[ErrorType.unknown]!['en']!;
    }
  }

  /// Get error message synchronously (uses cached language)
  static String getMessageSync(ErrorType type, String langCode) {
    final typeMessages = _messages[type];
    if (typeMessages != null && typeMessages.containsKey(langCode)) {
      return typeMessages[langCode]!;
    }
    return typeMessages?['en'] ?? _messages[ErrorType.unknown]!['en']!;
  }
}

/// Main error handler class
class ErrorHandler {
  /// Handles API errors globally and returns the appropriate error type
  static ErrorType handleApiError(dynamic error) {
    logger.d('Handling API error: $error (${error.runtimeType})', tag: 'ErrorHandler');

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
    } else if (error is BadRequestException) {
      return ErrorType.validation;
    } else if (error is NetworkException) {
      return ErrorType.server;
    } else if (error.toString().toLowerCase().contains('circuit breaker')) {
      return ErrorType.circuitBreaker;
    } else if (error.toString().toLowerCase().contains('socket')) {
      return ErrorType.network;
    } else {
      return ErrorType.server;
    }
  }

  /// Gets user-friendly error message based on error type (async, localized)
  static Future<String> getLocalizedErrorMessage(ErrorType type) async {
    return LocalizedErrorMessages.getMessage(type);
  }

  /// Gets user-friendly error message based on error type (sync, English)
  static String getErrorMessage(ErrorType type) {
    switch (type) {
      case ErrorType.network:
        return 'No internet connection. Please check your connection and try again.';
      case ErrorType.server:
        return 'Unable to connect to server. Please try again later.';
      case ErrorType.unauthorized:
        return 'Session expired. Please login again.';
      case ErrorType.notFound:
        return 'The requested resource was not found.';
      case ErrorType.timeout:
        return 'Request timed out. Please try again.';
      case ErrorType.validation:
        return 'Please check your input and try again.';
      case ErrorType.circuitBreaker:
        return 'Service temporarily unavailable. Please try again in a few minutes.';
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

  /// Shows a localized snackbar error
  static Future<void> showErrorSnackbar(ErrorType type, {String? customMessage}) async {
    final message = customMessage ?? await getLocalizedErrorMessage(type);

    Get.snackbar(
      'Error',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.red[700],
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.all(16),
      borderRadius: 8,
      icon: const Icon(Icons.error_outline, color: Colors.white),
    );
  }

  /// Shows a localized success snackbar
  static void showSuccessSnackbar(String message) {
    Get.snackbar(
      'Success',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.green[700],
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
      margin: const EdgeInsets.all(16),
      borderRadius: 8,
      icon: const Icon(Icons.check_circle_outline, color: Colors.white),
    );
  }

  /// Handle error and show appropriate UI
  static void handleError(dynamic error, {VoidCallback? onRetry}) {
    final errorType = handleApiError(error);
    logger.e('Error occurred', tag: 'ErrorHandler', error: error);
    showErrorSnackbar(errorType);
  }
}

/// Extension for easy error handling in controllers
extension ErrorHandlerExtension on Object {
  ErrorType classifyError(dynamic error) => ErrorHandler.handleApiError(error);
  Future<String> getLocalizedError(ErrorType type) => ErrorHandler.getLocalizedErrorMessage(type);
}
