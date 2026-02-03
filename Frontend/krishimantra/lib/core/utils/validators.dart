import 'package:krishimantra/core/constants/app_constants.dart';

/// Comprehensive input validation utilities for the app
/// Ensures data integrity and security before sending to API
class Validators {
  Validators._();

  // Validation patterns
  static final RegExp _emailPattern = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );
  static final RegExp _phonePattern = RegExp(r'^[6-9]\d{9}$');
  static final RegExp _otpPattern = RegExp(r'^\d{6}$');
  static final RegExp _usernamePattern = RegExp(r'^[a-zA-Z0-9_]{3,30}$');
  static final RegExp _urlPattern = RegExp(
    r'^https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)$',
  );

  // XSS prevention pattern
  static final RegExp _xssPattern = RegExp(
    r'<script|javascript:|on\w+\s*=|<\s*iframe|<\s*object|<\s*embed',
    caseSensitive: false,
  );

  // SQL injection prevention pattern
  static final RegExp _sqlInjectionPattern = RegExp(
    r"(\b(SELECT|INSERT|UPDATE|DELETE|DROP|UNION|ALTER|CREATE|TRUNCATE)\b)|(-{2})|(/\*)|(\*/)|;",
    caseSensitive: false,
  );

  /// Legacy method for form validation - Email
  static String? validateEmail(String? value) {
    final result = _validateEmail(value);
    return result.isValid ? null : result.errorMessage;
  }

  /// Legacy method for form validation - Password
  static String? validatePassword(String? value) {
    final result = _validatePassword(value);
    return result.isValid ? null : result.errorMessage;
  }

  /// Legacy method for form validation - Name
  static String? validateName(String? value) {
    final result = _validateName(value);
    return result.isValid ? null : result.errorMessage;
  }

  /// Legacy method for form validation - Phone
  static String? validatePhone(String? value) {
    final result = _validatePhone(value);
    return result.isValid ? null : result.errorMessage;
  }

  /// Legacy method for form validation - OTP
  static String? validateOTP(String? value) {
    final result = _validateOtp(value);
    return result.isValid ? null : result.errorMessage;
  }

  /// Validate email address - returns ValidationResult
  static ValidationResult _validateEmail(String? email) {
    if (email == null || email.isEmpty) {
      return ValidationResult.invalid('Email is required');
    }
    if (!_emailPattern.hasMatch(email.trim())) {
      return ValidationResult.invalid('Please enter a valid email address');
    }
    return ValidationResult.valid();
  }

  /// Validate Indian phone number - returns ValidationResult
  static ValidationResult _validatePhone(String? phone) {
    if (phone == null || phone.isEmpty) {
      return ValidationResult.invalid('Phone number is required');
    }
    final cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
    // Remove country code if present
    final phoneOnly = cleaned.startsWith('91') && cleaned.length == 12
        ? cleaned.substring(2)
        : cleaned;

    if (!_phonePattern.hasMatch(phoneOnly)) {
      return ValidationResult.invalid('Please enter a valid 10-digit mobile number');
    }
    return ValidationResult.valid();
  }

  /// Validate OTP - returns ValidationResult
  static ValidationResult _validateOtp(String? otp) {
    if (otp == null || otp.isEmpty) {
      return ValidationResult.invalid('OTP is required');
    }
    if (otp.length != AppConstants.OTP_LENGTH) {
      return ValidationResult.invalid('OTP must be ${AppConstants.OTP_LENGTH} digits');
    }
    if (!_otpPattern.hasMatch(otp.trim())) {
      return ValidationResult.invalid('OTP must be 6 digits');
    }
    return ValidationResult.valid();
  }

  /// Validate password - returns ValidationResult
  static ValidationResult _validatePassword(String? password) {
    if (password == null || password.isEmpty) {
      return ValidationResult.invalid('Password is required');
    }
    if (password.length < AppConstants.MIN_PASSWORD_LENGTH) {
      return ValidationResult.invalid(
        'Password must be at least ${AppConstants.MIN_PASSWORD_LENGTH} characters',
      );
    }
    if (!password.contains(RegExp(r'[A-Z]'))) {
      return ValidationResult.invalid('Password must contain at least one uppercase letter');
    }
    if (!password.contains(RegExp(r'[a-z]'))) {
      return ValidationResult.invalid('Password must contain at least one lowercase letter');
    }
    if (!password.contains(RegExp(r'[0-9]'))) {
      return ValidationResult.invalid('Password must contain at least one number');
    }
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return ValidationResult.invalid('Password must contain at least one special character');
    }
    return ValidationResult.valid();
  }

  /// Validate name - returns ValidationResult
  static ValidationResult _validateName(String? name) {
    if (name == null || name.isEmpty) {
      return ValidationResult.invalid('Name is required');
    }
    if (name.trim().length < 2) {
      return ValidationResult.invalid('Name must be at least 2 characters');
    }
    if (name.length > AppConstants.MAX_NAME_LENGTH) {
      return ValidationResult.invalid('Name must be less than ${AppConstants.MAX_NAME_LENGTH} characters');
    }
    if (_containsXss(name)) {
      return ValidationResult.invalid('Name contains invalid characters');
    }
    return ValidationResult.valid();
  }

  /// Validate username
  static ValidationResult validateUsername(String? username) {
    if (username == null || username.isEmpty) {
      return ValidationResult.invalid('Username is required');
    }
    if (!_usernamePattern.hasMatch(username.trim())) {
      return ValidationResult.invalid(
        'Username must be 3-30 characters, containing only letters, numbers, and underscores',
      );
    }
    return ValidationResult.valid();
  }

  /// Validate content (comments, posts, etc.)
  static ValidationResult validateContent(String? content, {int maxLength = 5000}) {
    if (content == null || content.isEmpty) {
      return ValidationResult.invalid('Content is required');
    }
    if (content.trim().length > maxLength) {
      return ValidationResult.invalid('Content must be less than $maxLength characters');
    }
    if (_containsXss(content)) {
      return ValidationResult.invalid('Content contains invalid characters');
    }
    return ValidationResult.valid();
  }

  /// Validate URL
  static ValidationResult validateUrl(String? url) {
    if (url == null || url.isEmpty) {
      return ValidationResult.invalid('URL is required');
    }
    if (!_urlPattern.hasMatch(url.trim())) {
      return ValidationResult.invalid('Please enter a valid URL');
    }
    return ValidationResult.valid();
  }

  /// Validate price
  static ValidationResult validatePrice(String? price) {
    if (price == null || price.isEmpty) {
      return ValidationResult.invalid('Price is required');
    }
    final parsed = double.tryParse(price.replaceAll(',', ''));
    if (parsed == null) {
      return ValidationResult.invalid('Please enter a valid price');
    }
    if (parsed < 0) {
      return ValidationResult.invalid('Price cannot be negative');
    }
    if (parsed > 10000000) {
      return ValidationResult.invalid('Price is too high');
    }
    return ValidationResult.valid();
  }

  /// Validate quantity
  static ValidationResult validateQuantity(String? quantity) {
    if (quantity == null || quantity.isEmpty) {
      return ValidationResult.invalid('Quantity is required');
    }
    final parsed = int.tryParse(quantity);
    if (parsed == null) {
      return ValidationResult.invalid('Please enter a valid quantity');
    }
    if (parsed < 1) {
      return ValidationResult.invalid('Quantity must be at least 1');
    }
    if (parsed > 10000) {
      return ValidationResult.invalid('Quantity is too high');
    }
    return ValidationResult.valid();
  }

  /// Check for XSS patterns
  static bool _containsXss(String input) {
    return _xssPattern.hasMatch(input);
  }

  /// Check for SQL injection patterns
  static bool containsSqlInjection(String input) {
    return _sqlInjectionPattern.hasMatch(input);
  }

  /// Sanitize input by removing potentially dangerous characters
  static String sanitize(String input) {
    return input
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#x27;')
        .replaceAll('/', '&#x2F;');
  }

  /// Validate map data for API calls
  static ValidationResult validateApiData(
    Map<String, dynamic> data,
    List<String> requiredFields,
  ) {
    for (final field in requiredFields) {
      if (!data.containsKey(field) || data[field] == null) {
        return ValidationResult.invalid('$field is required');
      }
      if (data[field] is String && (data[field] as String).isEmpty) {
        return ValidationResult.invalid('$field cannot be empty');
      }
    }
    return ValidationResult.valid();
  }

  /// Validate comment data
  static ValidationResult validateCommentData(Map<String, dynamic> data) {
    final required = ['userId', 'userName', 'content'];
    final requiredResult = validateApiData(data, required);
    if (!requiredResult.isValid) return requiredResult;

    final contentResult = validateContent(data['content'] as String?, maxLength: 2000);
    if (!contentResult.isValid) return contentResult;

    return ValidationResult.valid();
  }

  /// Validate feed/post data
  static ValidationResult validateFeedData(Map<String, dynamic> data) {
    final required = ['userId', 'userName'];
    final requiredResult = validateApiData(data, required);
    if (!requiredResult.isValid) return requiredResult;

    if (data['content'] != null) {
      final contentResult = validateContent(data['content'] as String?, maxLength: 5000);
      if (!contentResult.isValid) return contentResult;
    }

    if (data['description'] != null) {
      final descResult = validateContent(data['description'] as String?, maxLength: 500);
      if (!descResult.isValid) return descResult;
    }

    return ValidationResult.valid();
  }

  /// Validate message data
  static ValidationResult validateMessageData(Map<String, dynamic> data) {
    final required = ['senderId', 'chatId', 'content'];
    final requiredResult = validateApiData(data, required);
    if (!requiredResult.isValid) return requiredResult;

    final contentResult = validateContent(data['content'] as String?, maxLength: 2000);
    if (!contentResult.isValid) return contentResult;

    return ValidationResult.valid();
  }

  /// Validate product data
  static ValidationResult validateProductData(Map<String, dynamic> data) {
    final required = ['name', 'price', 'userId'];
    final requiredResult = validateApiData(data, required);
    if (!requiredResult.isValid) return requiredResult;

    final nameResult = _validateName(data['name'] as String?);
    if (!nameResult.isValid) return nameResult;

    if (data['price'] != null) {
      final priceResult = validatePrice(data['price'].toString());
      if (!priceResult.isValid) return priceResult;
    }

    if (data['description'] != null) {
      final descResult = validateContent(data['description'] as String?, maxLength: 2000);
      if (!descResult.isValid) return descResult;
    }

    return ValidationResult.valid();
  }

  /// Check if string is empty or whitespace only
  static bool isNullOrEmpty(String? value) {
    return value == null || value.trim().isEmpty;
  }

  /// Check if object ID is valid (MongoDB ObjectId format)
  static bool isValidObjectId(String? id) {
    if (id == null || id.isEmpty) return false;
    return RegExp(r'^[a-f0-9]{24}$').hasMatch(id);
  }
}

/// Validation result class
class ValidationResult {
  final bool isValid;
  final String? errorMessage;

  ValidationResult._(this.isValid, this.errorMessage);

  factory ValidationResult.valid() => ValidationResult._(true, null);
  factory ValidationResult.invalid(String message) => ValidationResult._(false, message);
}

/// Extension for easier validation in forms
extension StringValidation on String? {
  bool get isValidEmail => Validators.validateEmail(this) == null;
  bool get isValidPhone => Validators.validatePhone(this) == null;
  bool get isValidPassword => Validators.validatePassword(this) == null;
  bool get isValidName => Validators.validateName(this) == null;
  bool get isValidUrl => Validators.validateUrl(this).isValid;
  bool get isNullOrEmpty => Validators.isNullOrEmpty(this);
  bool get isValidObjectId => Validators.isValidObjectId(this);

  String get sanitized => this == null ? '' : Validators.sanitize(this!);
}
