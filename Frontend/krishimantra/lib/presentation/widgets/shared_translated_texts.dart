import '../../data/services/language_service.dart';

/// A utility class that provides shared translations for texts used across multiple screens
/// This helps maintain consistency and reduces duplication of translation keys
class SharedTranslatedTexts {
  // Common button texts
  static const String KEY_SAVE = 'common_save';
  static const String KEY_CANCEL = 'common_cancel';
  static const String KEY_CONFIRM = 'common_confirm';
  static const String KEY_SUBMIT = 'common_submit';
  static const String KEY_CONTINUE = 'common_continue';
  static const String KEY_BACK = 'common_back';
  static const String KEY_SEARCH = 'common_search';
  static const String KEY_RETRY = 'common_retry';
  static const String KEY_CLOSE = 'common_close';
  static const String KEY_UPDATE = 'common_update';
  static const String KEY_DELETE = 'common_delete';
  static const String KEY_DONE = 'common_done';

  // Common error messages
  static const String KEY_ERROR = 'common_error';
  static const String KEY_NETWORK_ERROR = 'common_network_error';
  static const String KEY_SERVER_ERROR = 'common_server_error';
  static const String KEY_TIMEOUT_ERROR = 'common_timeout_error';
  static const String KEY_UNKNOWN_ERROR = 'common_unknown_error';
  static const String KEY_NO_DATA = 'common_no_data';

  // Common validation messages
  static const String KEY_REQUIRED_FIELD = 'common_required_field';
  static const String KEY_INVALID_EMAIL = 'common_invalid_email';
  static const String KEY_INVALID_PHONE = 'common_invalid_phone';
  static const String KEY_PASSWORD_TOO_SHORT = 'common_password_too_short';

  // Common screen titles
  static const String KEY_HOME = 'common_home';
  static const String KEY_PROFILE = 'common_profile';
  static const String KEY_SETTINGS = 'common_settings';
  static const String KEY_NOTIFICATIONS = 'common_notifications';
  static const String KEY_ABOUT = 'common_about';
  static const String KEY_HELP = 'common_help';
  static const String KEY_CONTACT = 'common_contact';

  // Common action texts
  static const String KEY_UPLOADING = 'common_uploading';
  static const String KEY_LOADING = 'common_loading';
  static const String KEY_PROCESSING = 'common_processing';
  static const String KEY_SENDING = 'common_sending';

  // Common status texts
  static const String KEY_SUCCESS = 'common_success';
  static const String KEY_FAILED = 'common_failed';
  static const String KEY_PENDING = 'common_pending';
  static const String KEY_COMPLETED = 'common_completed';
  static const String KEY_CANCELLED = 'common_cancelled';

  // Initialize shared translations
  static Map<String, String> getDefaultTranslations() {
    return {
      // Button texts
      KEY_SAVE: 'Save',
      KEY_CANCEL: 'Cancel',
      KEY_CONFIRM: 'Confirm',
      KEY_SUBMIT: 'Submit',
      KEY_CONTINUE: 'Continue',
      KEY_BACK: 'Back',
      KEY_SEARCH: 'Search',
      KEY_RETRY: 'Retry',
      KEY_CLOSE: 'Close',
      KEY_UPDATE: 'Update',
      KEY_DELETE: 'Delete',
      KEY_DONE: 'Done',

      // Error messages
      KEY_ERROR: 'Error',
      KEY_NETWORK_ERROR:
          'Network error. Please check your internet connection.',
      KEY_SERVER_ERROR: 'Server error. Please try again later.',
      KEY_TIMEOUT_ERROR: 'Request timed out. Please try again.',
      KEY_UNKNOWN_ERROR: 'An unknown error occurred.',
      KEY_NO_DATA: 'No data available.',

      // Validation messages
      KEY_REQUIRED_FIELD: 'This field is required.',
      KEY_INVALID_EMAIL: 'Please enter a valid email address.',
      KEY_INVALID_PHONE: 'Please enter a valid phone number.',
      KEY_PASSWORD_TOO_SHORT: 'Password must be at least 6 characters long.',

      // Screen titles
      KEY_HOME: 'Home',
      KEY_PROFILE: 'Profile',
      KEY_SETTINGS: 'Settings',
      KEY_NOTIFICATIONS: 'Notifications',
      KEY_ABOUT: 'About',
      KEY_HELP: 'Help',
      KEY_CONTACT: 'Contact Us',

      // Action texts
      KEY_UPLOADING: 'Uploading...',
      KEY_LOADING: 'Loading...',
      KEY_PROCESSING: 'Processing...',
      KEY_SENDING: 'Sending...',

      // Status texts
      KEY_SUCCESS: 'Success',
      KEY_FAILED: 'Failed',
      KEY_PENDING: 'Pending',
      KEY_COMPLETED: 'Completed',
      KEY_CANCELLED: 'Cancelled',
    };
  }

  /// Register all shared translations in a mixin
  static void registerAll(Map<String, String> translationsMap) {
    final defaultTranslations = getDefaultTranslations();
    defaultTranslations.forEach((key, value) {
      translationsMap[key] = value;
    });
  }

  /// Get a translated text directly (for use outside mixins)
  static Future<String> getTranslatedText(String key) async {
    final defaultTranslations = getDefaultTranslations();
    final defaultText = defaultTranslations[key] ?? key;

    final languageService = await LanguageService.getInstance();
    return await languageService.translate(defaultText);
  }
}
