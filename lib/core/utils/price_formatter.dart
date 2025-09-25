// lib/core/utils/price_formatter.dart
import 'package:intl/intl.dart';

/// Utility class for consistent price formatting across the app
class PriceFormatter {
  static final _currencyFormat = NumberFormat.currency(
    symbol: '\$',
    decimalDigits: 2,
    locale: 'en_US',
  );
  
  static final _numberFormat = NumberFormat('#,##0.00', 'en_US');
  
  /// Format a price with dollar sign and commas
  /// Example: 1234.5 -> $1,234.50
  static String formatPrice(dynamic value) {
    if (value == null) return '\$0.00';
    
    final double numValue = value is double ? value : 
                           value is int ? value.toDouble() : 
                           double.tryParse(value.toString()) ?? 0.0;
    
    return _currencyFormat.format(numValue);
  }
  
  /// Format a number with commas but no dollar sign
  /// Example: 1234.5 -> 1,234.50
  static String formatNumber(dynamic value) {
    if (value == null) return '0.00';
    
    final double numValue = value is double ? value : 
                           value is int ? value.toDouble() : 
                           double.tryParse(value.toString()) ?? 0.0;
    
    return _numberFormat.format(numValue);
  }
  
  /// Format for display in forms/inputs (no currency symbol)
  static String formatForInput(dynamic value) {
    return formatNumber(value);
  }

  /// Safely convert any value to double with fallback
  static double safeToDouble(dynamic value, [double fallback = 0.0]) {
    if (value == null) return fallback;

    try {
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        return parsed ?? fallback;
      }
      // Try converting to string first, then parse
      final parsed = double.tryParse(value.toString());
      return parsed ?? fallback;
    } catch (e) {
      return fallback;
    }
  }

  /// Safely convert any value to int with fallback
  static int safeToInt(dynamic value, [int fallback = 0]) {
    if (value == null) return fallback;

    try {
      if (value is int) return value;
      if (value is double) return value.round();
      if (value is String) {
        final parsed = int.tryParse(value);
        return parsed ?? fallback;
      }
      // Try converting to string first, then parse
      final parsed = int.tryParse(value.toString());
      return parsed ?? fallback;
    } catch (e) {
      return fallback;
    }
  }
}