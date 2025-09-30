// lib/core/utils/safe_type_converter.dart

import '../services/app_logger.dart';

/// Utility class for safe type conversions with proper error handling
/// Prevents runtime type errors and provides fallback values
class SafeTypeConverter {
  /// Safely convert dynamic value to String
  static String? toStringOrNull(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    try {
      return value.toString();
    } catch (e) {
      AppLogger.warning(
        'Failed to convert value to String: $value',
        error: e,
      );
      return null;
    }
  }

  /// Safely convert dynamic value to String with default
  static String toString(dynamic value, {String defaultValue = ''}) {
    return toStringOrNull(value) ?? defaultValue;
  }

  /// Safely convert dynamic value to int
  static int? toIntOrNull(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;

      // Try parsing as double first then convert
      final doubleValue = double.tryParse(value);
      if (doubleValue != null) return doubleValue.toInt();
    }

    AppLogger.debug('Could not convert value to int: $value');
    return null;
  }

  /// Safely convert dynamic value to int with default
  static int toInt(dynamic value, {int defaultValue = 0}) {
    return toIntOrNull(value) ?? defaultValue;
  }

  /// Safely convert dynamic value to double
  static double? toDoubleOrNull(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      // Handle currency formatting
      final cleaned = value.replaceAll(RegExp(r'[^\d.-]'), '');
      return double.tryParse(cleaned);
    }

    AppLogger.debug('Could not convert value to double: $value');
    return null;
  }

  /// Safely convert dynamic value to double with default
  static double toDouble(dynamic value, {double defaultValue = 0.0}) {
    return toDoubleOrNull(value) ?? defaultValue;
  }

  /// Safely convert dynamic value to bool
  static bool? toBoolOrNull(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is String) {
      final lower = value.toLowerCase();
      if (lower == 'true' || lower == '1' || lower == 'yes') return true;
      if (lower == 'false' || lower == '0' || lower == 'no') return false;
    }
    if (value is int) return value != 0;
    if (value is double) return value != 0.0;

    AppLogger.debug('Could not convert value to bool: $value');
    return null;
  }

  /// Safely convert dynamic value to bool with default
  static bool toBool(dynamic value, {bool defaultValue = false}) {
    return toBoolOrNull(value) ?? defaultValue;
  }

  /// Safely convert dynamic value to DateTime
  static DateTime? toDateTimeOrNull(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        // Try alternate formats
        final formats = [
          RegExp(r'^(\d{4})-(\d{2})-(\d{2})$'), // YYYY-MM-DD
          RegExp(r'^(\d{2})/(\d{2})/(\d{4})$'), // MM/DD/YYYY
          RegExp(r'^(\d{2})-(\d{2})-(\d{4})$'), // DD-MM-YYYY
        ];

        for (final format in formats) {
          final match = format.firstMatch(value);
          if (match != null) {
            try {
              if (format == formats[1]) {
                // MM/DD/YYYY
                return DateTime(
                  int.parse(match.group(3)!),
                  int.parse(match.group(1)!),
                  int.parse(match.group(2)!),
                );
              } else if (format == formats[2]) {
                // DD-MM-YYYY
                return DateTime(
                  int.parse(match.group(3)!),
                  int.parse(match.group(2)!),
                  int.parse(match.group(1)!),
                );
              }
            } catch (_) {
              continue;
            }
          }
        }
      }
    }
    if (value is int) {
      // Assume milliseconds since epoch
      return DateTime.fromMillisecondsSinceEpoch(value);
    }

    AppLogger.debug('Could not convert value to DateTime: $value');
    return null;
  }

  /// Safely convert dynamic value to DateTime with default
  static DateTime toDateTime(dynamic value, {DateTime? defaultValue}) {
    return toDateTimeOrNull(value) ?? defaultValue ?? DateTime.now();
  }

  /// Safely convert dynamic value to List<T>
  static List<T> toList<T>(
    dynamic value, {
    required T Function(dynamic) itemConverter,
    List<T>? defaultValue,
  }) {
    if (value == null) return defaultValue ?? [];
    if (value is List) {
      final result = <T>[];
      for (final item in value) {
        try {
          result.add(itemConverter(item));
        } catch (e) {
          AppLogger.debug('Skipping invalid list item: $item', error: e);
        }
      }
      return result;
    }
    return defaultValue ?? [];
  }

  /// Safely convert dynamic value to Map<String, dynamic>
  static Map<String, dynamic>? toMapOrNull(dynamic value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      try {
        return Map<String, dynamic>.from(value);
      } catch (e) {
        AppLogger.debug('Could not convert Map to Map<String, dynamic>: $value', error: e);

        // Try manual conversion
        final result = <String, dynamic>{};
        value.forEach((key, val) {
          result[key.toString()] = val;
        });
        return result;
      }
    }

    AppLogger.debug('Could not convert value to Map: $value');
    return null;
  }

  /// Safely convert dynamic value to Map<String, dynamic> with default
  static Map<String, dynamic> toMap(dynamic value, {Map<String, dynamic>? defaultValue}) {
    return toMapOrNull(value) ?? defaultValue ?? {};
  }

  /// Safely get nested value from a Map
  static T? getNestedValue<T>(
    Map<String, dynamic>? map,
    String path, {
    T Function(dynamic)? converter,
  }) {
    if (map == null) return null;

    final keys = path.split('.');
    dynamic current = map;

    for (final key in keys) {
      if (current is Map) {
        current = current[key];
      } else {
        return null;
      }
    }

    if (converter != null && current != null) {
      try {
        return converter(current);
      } catch (e) {
        AppLogger.debug('Failed to convert nested value at $path', error: e);
        return null;
      }
    }

    return current as T?;
  }

  /// Safely cast dynamic value to specific type
  static T? safeCast<T>(dynamic value) {
    if (value == null) return null;
    if (value is T) return value;

    // Special handling for common types
    if (T == String) return toStringOrNull(value) as T?;
    if (T == int) return toIntOrNull(value) as T?;
    if (T == double) return toDoubleOrNull(value) as T?;
    if (T == bool) return toBoolOrNull(value) as T?;
    if (T == DateTime) return toDateTimeOrNull(value) as T?;

    AppLogger.debug('Could not cast value to type $T: $value');
    return null;
  }

  /// Validate and sanitize email
  static String? sanitizeEmail(String? email) {
    if (email == null || email.isEmpty) return null;

    // Trim and lowercase
    final sanitized = email.trim().toLowerCase();

    // Basic email validation
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    );

    if (!emailRegex.hasMatch(sanitized)) {
      AppLogger.warning('Invalid email format: $email');
      return null;
    }

    return sanitized;
  }

  /// Validate and sanitize phone number
  static String? sanitizePhone(String? phone) {
    if (phone == null || phone.isEmpty) return null;

    // Remove all non-numeric characters except + and -
    final sanitized = phone.replaceAll(RegExp(r'[^\d+-]'), '');

    // Check minimum length
    if (sanitized.length < 10) {
      AppLogger.warning('Phone number too short: $phone');
      return null;
    }

    return sanitized;
  }

  /// Validate and sanitize URL
  static String? sanitizeUrl(String? url) {
    if (url == null || url.isEmpty) return null;

    // Add protocol if missing
    var sanitized = url.trim();
    if (!sanitized.startsWith('http://') && !sanitized.startsWith('https://')) {
      sanitized = 'https://$sanitized';
    }

    // Validate URL format
    try {
      final uri = Uri.parse(sanitized);
      if (!uri.hasScheme || !uri.hasAuthority) {
        AppLogger.warning('Invalid URL format: $url');
        return null;
      }
      return sanitized;
    } catch (e) {
      AppLogger.warning('Invalid URL: $url', error: e);
      return null;
    }
  }

  /// Sanitize string for database storage (prevent injection)
  static String sanitizeForDatabase(String? value) {
    if (value == null || value.isEmpty) return '';

    // Remove potential SQL injection characters
    return value
        .replaceAll("'", "''")
        .replaceAll('"', '""')
        .replaceAll(';', '')
        .replaceAll('--', '')
        .replaceAll('/*', '')
        .replaceAll('*/', '')
        .replaceAll('\x00', '') // Null byte
        .replaceAll('\n', ' ')
        .replaceAll('\r', ' ')
        .replaceAll('\t', ' ')
        .trim();
  }

  /// Sanitize string for HTML display (prevent XSS)
  static String sanitizeForHtml(String? value) {
    if (value == null || value.isEmpty) return '';

    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#x27;')
        .replaceAll('/', '&#x2F;');
  }

  /// Clamp numeric value within range
  static T clampValue<T extends num>(T value, T min, T max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }
}