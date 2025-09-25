// lib/core/services/validation_service.dart
// Comprehensive input validation and sanitization service
// Prevents XSS, SQL injection, and other input-based attacks

import 'dart:convert';
import 'app_logger.dart';

class ValidationService {
  // Email validation regex pattern
  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  // Phone validation regex pattern (supports international formats)
  static final RegExp _phoneRegex = RegExp(
    r'^[\+]?[(]?[0-9]{1,3}[)]?[-\s\.]?[(]?[0-9]{1,4}[)]?[-\s\.]?[0-9]{1,4}[-\s\.]?[0-9]{1,9}$',
  );

  // URL validation regex
  static final RegExp _urlRegex = RegExp(
    r'^(https?:\/\/)?([\da-z\.-]+)\.([a-z\.]{2,6})([\/\w \.-]*)*\/?$',
  );

  // SQL injection patterns to detect
  static final List<RegExp> _sqlInjectionPatterns = [
    RegExp(r"(\b(SELECT|INSERT|UPDATE|DELETE|DROP|UNION|CREATE|ALTER)\b)", caseSensitive: false),
    RegExp(r"(--|#|\/\*|\*\/)", caseSensitive: false),
    RegExp(r"(\bOR\b\s*\d+\s*=\s*\d+)", caseSensitive: false),
    RegExp(r"(\bAND\b\s*\d+\s*=\s*\d+)", caseSensitive: false),
    RegExp(r'''('|"|;|\\x00|\\n|\\r|\\x1a)''', caseSensitive: false),
  ];

  // XSS patterns to detect
  static final List<RegExp> _xssPatterns = [
    RegExp(r'<script[^>]*>.*?</script>', caseSensitive: false),
    RegExp(r'javascript:', caseSensitive: false),
    RegExp(r'on\w+\s*=', caseSensitive: false), // onclick, onload, etc.
    RegExp(r'<iframe[^>]*>', caseSensitive: false),
    RegExp(r'<embed[^>]*>', caseSensitive: false),
    RegExp(r'<object[^>]*>', caseSensitive: false),
  ];

  // ============ SANITIZATION METHODS ============

  /// Sanitize string for HTML output (prevent XSS)
  static String sanitizeHtml(String input) {
    if (input.isEmpty) return input;

    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#x27;')
        .replaceAll('/', '&#x2F;')
        .replaceAll('\\', '&#x5C;')
        .replaceAll('\n', '&#10;')
        .replaceAll('\r', '&#13;')
        .replaceAll('\t', '&#9;');
  }

  /// Sanitize string for database storage
  static String sanitizeForDatabase(String input) {
    if (input.isEmpty) return input;

    // Remove any potential SQL injection attempts
    String sanitized = input;
    
    // Replace single quotes with escaped version
    sanitized = sanitized.replaceAll("'", "''");
    
    // Remove dangerous characters
    sanitized = sanitized.replaceAll(RegExp(r'[\\;]'), '');
    
    // Remove SQL keywords if they appear as standalone words
    for (final pattern in _sqlInjectionPatterns) {
      if (pattern.hasMatch(sanitized)) {
        // Log potential attack attempt
        AppLogger.warning('[SECURITY] Potential SQL injection attempt detected', data: {'input_length': input.length, 'pattern': pattern.pattern});
        sanitized = sanitized.replaceAll(pattern, '');
      }
    }

    return sanitized.trim();
  }

  /// Sanitize for JSON encoding
  static String sanitizeJson(String input) {
    if (input.isEmpty) return input;

    // Use Dart's built-in JSON encoder for proper escaping
    try {
      return json.encode(input).replaceAll('"', '');
    } catch (e) {
      // If encoding fails, fall back to basic sanitization
      return sanitizeHtml(input);
    }
  }

  /// Sanitize file names
  static String sanitizeFileName(String fileName) {
    if (fileName.isEmpty) return fileName;

    // Remove directory traversal attempts
    fileName = fileName.replaceAll('../', '');
    fileName = fileName.replaceAll('..\\', '');
    
    // Remove dangerous characters
    fileName = fileName.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_');
    
    // Limit length
    if (fileName.length > 255) {
      fileName = fileName.substring(0, 255);
    }

    return fileName;
  }

  /// Sanitize URLs
  static String? sanitizeUrl(String url) {
    if (url.isEmpty) return null;

    // Remove javascript: and data: protocols
    if (url.toLowerCase().startsWith('javascript:') ||
        url.toLowerCase().startsWith('data:') ||
        url.toLowerCase().startsWith('vbscript:')) {
      return null;
    }

    // Ensure URL starts with http:// or https://
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }

    return Uri.tryParse(url)?.toString();
  }

  // ============ VALIDATION METHODS ============

  /// Validate email address
  static bool isValidEmail(String email) {
    if (email.isEmpty || email.length > 254) return false;
    return _emailRegex.hasMatch(email.toLowerCase());
  }

  /// Validate phone number
  static bool isValidPhone(String phone) {
    if (phone.isEmpty || phone.length < 7 || phone.length > 20) return false;
    return _phoneRegex.hasMatch(phone);
  }

  /// Validate URL
  static bool isValidUrl(String url) {
    if (url.isEmpty || url.length > 2048) return false;
    return _urlRegex.hasMatch(url) || Uri.tryParse(url) != null;
  }

  /// Validate password strength
  static PasswordStrength validatePassword(String password) {
    if (password.length < 8) {
      return PasswordStrength(
        isValid: false,
        message: 'Password must be at least 8 characters long',
        strength: 0,
      );
    }

    int strength = 0;
    String message = '';

    // Check length
    if (password.length >= 12) strength++;
    if (password.length >= 16) strength++;

    // Check for lowercase
    if (RegExp(r'[a-z]').hasMatch(password)) {
      strength++;
    } else {
      message += 'Add lowercase letters. ';
    }

    // Check for uppercase
    if (RegExp(r'[A-Z]').hasMatch(password)) {
      strength++;
    } else {
      message += 'Add uppercase letters. ';
    }

    // Check for numbers
    if (RegExp(r'[0-9]').hasMatch(password)) {
      strength++;
    } else {
      message += 'Add numbers. ';
    }

    // Check for special characters
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) {
      strength++;
    } else {
      message += 'Add special characters. ';
    }

    // Check for common patterns
    if (_containsCommonPatterns(password)) {
      strength = strength > 2 ? strength - 2 : 0;
      message += 'Avoid common patterns. ';
    }

    return PasswordStrength(
      isValid: strength >= 4,
      message: message.isEmpty ? 'Strong password' : message.trim(),
      strength: strength,
    );
  }

  /// Check for common weak password patterns
  static bool _containsCommonPatterns(String password) {
    final lowercased = password.toLowerCase();
    final commonPatterns = [
      'password', '12345678', 'qwerty', 'abc123', 'letmein',
      'welcome', 'monkey', 'dragon', 'master', 'admin'
    ];

    for (final pattern in commonPatterns) {
      if (lowercased.contains(pattern)) return true;
    }

    // Check for sequential characters
    if (RegExp(r'(012|123|234|345|456|567|678|789|890|abc|bcd|cde|def)').hasMatch(lowercased)) {
      return true;
    }

    return false;
  }

  /// Validate numeric input
  static bool isValidNumber(String input, {double? min, double? max}) {
    final number = double.tryParse(input);
    if (number == null) return false;
    if (min != null && number < min) return false;
    if (max != null && number > max) return false;
    return true;
  }

  /// Validate alphanumeric input (letters and numbers only)
  static bool isAlphanumeric(String input) {
    return RegExp(r'^[a-zA-Z0-9]+$').hasMatch(input);
  }

  /// Validate company/person name
  static bool isValidName(String name) {
    if (name.isEmpty || name.length > 100) return false;
    // Allow letters, spaces, hyphens, apostrophes, and periods
    return RegExp(r"^[a-zA-Z\s\-'.]+$").hasMatch(name);
  }

  /// Validate address
  static bool isValidAddress(String address) {
    if (address.isEmpty || address.length > 500) return false;
    // Basic check - no script tags or SQL injection attempts
    return !_containsMaliciousContent(address);
  }

  /// Check for malicious content
  static bool _containsMaliciousContent(String input) {
    // Check for XSS patterns
    for (final pattern in _xssPatterns) {
      if (pattern.hasMatch(input)) return true;
    }

    // Check for SQL injection patterns
    for (final pattern in _sqlInjectionPatterns) {
      if (pattern.hasMatch(input)) return true;
    }

    return false;
  }

  /// Detect potential XSS attempts
  static bool containsXss(String input) {
    for (final pattern in _xssPatterns) {
      if (pattern.hasMatch(input)) return true;
    }
    return false;
  }

  /// Detect potential SQL injection attempts
  static bool containsSqlInjection(String input) {
    for (final pattern in _sqlInjectionPatterns) {
      if (pattern.hasMatch(input)) return true;
    }
    return false;
  }

  /// Validate and sanitize user input based on field type
  static ValidationResult validateField({
    required String value,
    required FieldType fieldType,
    String? fieldName,
    bool allowEmpty = false,
  }) {
    // Check if empty
    if (value.isEmpty) {
      if (allowEmpty) {
        return ValidationResult(isValid: true, sanitizedValue: value);
      }
      return ValidationResult(
        isValid: false,
        error: '${fieldName ?? 'Field'} is required',
      );
    }

    // Check for malicious content first
    if (_containsMaliciousContent(value)) {
      return ValidationResult(
        isValid: false,
        error: 'Invalid characters detected in ${fieldName ?? 'field'}',
      );
    }

    // Validate based on field type
    switch (fieldType) {
      case FieldType.email:
        if (!isValidEmail(value)) {
          return ValidationResult(
            isValid: false,
            error: 'Please enter a valid email address',
          );
        }
        return ValidationResult(
          isValid: true,
          sanitizedValue: sanitizeForDatabase(value.toLowerCase()),
        );

      case FieldType.phone:
        if (!isValidPhone(value)) {
          return ValidationResult(
            isValid: false,
            error: 'Please enter a valid phone number',
          );
        }
        return ValidationResult(
          isValid: true,
          sanitizedValue: sanitizeForDatabase(value.replaceAll(RegExp(r'[^\d+]'), '')),
        );

      case FieldType.name:
        if (!isValidName(value)) {
          return ValidationResult(
            isValid: false,
            error: 'Please enter a valid name (letters only)',
          );
        }
        return ValidationResult(
          isValid: true,
          sanitizedValue: sanitizeForDatabase(value.trim()),
        );

      case FieldType.address:
        if (!isValidAddress(value)) {
          return ValidationResult(
            isValid: false,
            error: 'Please enter a valid address',
          );
        }
        return ValidationResult(
          isValid: true,
          sanitizedValue: sanitizeForDatabase(value.trim()),
        );

      case FieldType.number:
        if (!isValidNumber(value)) {
          return ValidationResult(
            isValid: false,
            error: 'Please enter a valid number',
          );
        }
        return ValidationResult(
          isValid: true,
          sanitizedValue: value.trim(),
        );

      case FieldType.text:
        return ValidationResult(
          isValid: true,
          sanitizedValue: sanitizeForDatabase(value.trim()),
        );

      case FieldType.url:
        final sanitizedUrl = sanitizeUrl(value);
        if (sanitizedUrl == null || !isValidUrl(sanitizedUrl)) {
          return ValidationResult(
            isValid: false,
            error: 'Please enter a valid URL',
          );
        }
        return ValidationResult(
          isValid: true,
          sanitizedValue: sanitizedUrl,
        );

      case FieldType.password:
        final strength = validatePassword(value);
        return ValidationResult(
          isValid: strength.isValid,
          error: strength.isValid ? null : strength.message,
          sanitizedValue: value, // Don't sanitize passwords
        );
    }
  }
}

// ============ SUPPORTING CLASSES ============

enum FieldType {
  email,
  phone,
  name,
  address,
  number,
  text,
  url,
  password,
}

class ValidationResult {
  final bool isValid;
  final String? error;
  final String? sanitizedValue;

  ValidationResult({
    required this.isValid,
    this.error,
    this.sanitizedValue,
  });
}

class PasswordStrength {
  final bool isValid;
  final String message;
  final int strength; // 0-6 scale

  PasswordStrength({
    required this.isValid,
    required this.message,
    required this.strength,
  });

  String get strengthText {
    if (strength <= 1) return 'Very Weak';
    if (strength <= 2) return 'Weak';
    if (strength <= 3) return 'Fair';
    if (strength <= 4) return 'Good';
    if (strength <= 5) return 'Strong';
    return 'Very Strong';
  }

  double get strengthPercentage => (strength / 6.0).clamp(0.0, 1.0);
}