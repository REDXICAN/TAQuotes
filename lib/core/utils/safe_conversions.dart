// lib/core/utils/safe_conversions.dart

/// Utility class for safe type conversions throughout the app
class SafeConversions {
  /// Safely converts any value to double with null safety
  static double toDouble(dynamic value, {double defaultValue = 0.0}) {
    if (value == null) return defaultValue;

    try {
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        return parsed ?? defaultValue;
      }
      if (value is num) return value.toDouble();

      // Try to convert via toString() as last resort
      final stringValue = value.toString();
      if (stringValue.isNotEmpty && stringValue != 'null') {
        return double.tryParse(stringValue) ?? defaultValue;
      }
    } catch (_) {
      // Return default on any conversion error
    }

    return defaultValue;
  }

  /// Safely converts any value to int with null safety
  static int toInt(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;

    try {
      if (value is int) return value;
      if (value is double) {
        // Handle infinity and NaN
        if (value.isInfinite || value.isNaN) return defaultValue;
        return value.round();
      }
      if (value is String) {
        // Try parsing as double first (handles "1.0" style strings)
        final doubleValue = double.tryParse(value);
        if (doubleValue != null) {
          // Handle infinity and NaN
          if (doubleValue.isInfinite || doubleValue.isNaN) return defaultValue;
          return doubleValue.round();
        }

        // Try direct int parse
        return int.tryParse(value) ?? defaultValue;
      }
      if (value is num) {
        // Handle infinity and NaN
        final doubleVal = value.toDouble();
        if (doubleVal.isInfinite || doubleVal.isNaN) return defaultValue;
        return value.round();
      }

      // Try to convert via toString() as last resort
      final stringValue = value.toString();
      if (stringValue.isNotEmpty && stringValue != 'null') {
        final parsed = double.tryParse(stringValue);
        if (parsed != null) {
          // Handle infinity and NaN
          if (parsed.isInfinite || parsed.isNaN) return defaultValue;
          return parsed.round();
        }
      }
    } catch (_) {
      // Return default on any conversion error
    }

    return defaultValue;
  }

  /// Safely converts price/money values with proper rounding
  static double toPrice(dynamic value, {double defaultValue = 0.0}) {
    final doubleValue = toDouble(value, defaultValue: defaultValue);
    // Handle infinity and NaN
    if (doubleValue.isInfinite || doubleValue.isNaN) return defaultValue;
    // Round to 2 decimal places for money values
    return (doubleValue * 100).round() / 100;
  }

  /// Safely converts percentage values
  static double toPercentage(dynamic value, {double defaultValue = 0.0}) {
    final doubleValue = toDouble(value, defaultValue: defaultValue);
    // Ensure percentage is between 0 and 100
    if (doubleValue < 0) return 0.0;
    if (doubleValue > 100) return 100.0;
    return doubleValue;
  }

  /// Safely converts quantity values (must be positive)
  static int toQuantity(dynamic value, {int defaultValue = 1}) {
    final intValue = toInt(value, defaultValue: defaultValue);
    // Quantity must be at least 1
    return intValue < 1 ? defaultValue : intValue;
  }

  /// Check if a value can be converted to a valid number
  static bool isNumeric(dynamic value) {
    if (value == null) return false;
    if (value is num) return true;
    if (value is String) {
      return double.tryParse(value) != null;
    }
    return false;
  }

  /// Safely get a value with chain null safety
  /// Example: safeGet(map, ['data', 'user', 'name'], 'Unknown')
  static T safeGet<T>(dynamic source, List<dynamic> path, T defaultValue) {
    if (source == null || path.isEmpty) return defaultValue;

    dynamic current = source;
    for (final key in path) {
      if (current == null) return defaultValue;

      if (current is Map) {
        current = current[key];
      } else if (current is List && key is int && key < current.length) {
        current = current[key];
      } else {
        return defaultValue;
      }
    }

    // Try to cast to expected type
    try {
      return current as T;
    } catch (_) {
      return defaultValue;
    }
  }
}