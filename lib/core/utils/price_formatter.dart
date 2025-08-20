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
}