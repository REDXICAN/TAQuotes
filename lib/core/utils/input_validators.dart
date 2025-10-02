// lib/core/utils/input_validators.dart

import 'package:flutter/services.dart';

/// Comprehensive input validation utilities for the app
class InputValidators {
  // Regular expressions for validation
  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  static final RegExp _phoneRegex = RegExp(
    r'^[\+]?[(]?[0-9]{3}[)]?[-\s\.]?[0-9]{3}[-\s\.]?[0-9]{4,6}$',
  );

  // Numeric regex patterns kept for potential future validation features
  // ignore: unused_field
  static final RegExp _numericRegex = RegExp(r'^-?[0-9]+\.?[0-9]*$');
  static final RegExp _integerRegex = RegExp(r'^-?[0-9]+$');
  // ignore: unused_field
  static final RegExp _positiveNumberRegex = RegExp(r'^[0-9]+\.?[0-9]*$');

  // Email validation
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }

    final trimmed = value.trim();
    if (!_emailRegex.hasMatch(trimmed)) {
      return 'Please enter a valid email address';
    }

    return null;
  }

  // Phone validation
  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }

    final cleaned = value.replaceAll(RegExp(r'[\s()-]'), '');
    if (cleaned.length < 10) {
      return 'Phone number must be at least 10 digits';
    }

    if (!_phoneRegex.hasMatch(value)) {
      return 'Please enter a valid phone number';
    }

    return null;
  }

  // Required field validation
  static String? validateRequired(String? value, {String fieldName = 'This field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  // Price validation (positive numbers with up to 2 decimal places)
  static String? validatePrice(String? value, {
    String fieldName = 'Price',
    double? min,
    double? max,
  }) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }

    // Remove currency symbols and commas
    final cleaned = value.replaceAll(RegExp(r'[\$,]'), '').trim();

    if (cleaned.isEmpty) {
      return '$fieldName is required';
    }

    final parsed = double.tryParse(cleaned);
    if (parsed == null) {
      return '$fieldName must be a valid number';
    }

    if (parsed < 0) {
      return '$fieldName cannot be negative';
    }

    if (min != null && parsed < min) {
      return '$fieldName must be at least ${_formatCurrency(min)}';
    }

    if (max != null && parsed > max) {
      return '$fieldName cannot exceed ${_formatCurrency(max)}';
    }

    // Check decimal places
    if (cleaned.contains('.')) {
      final parts = cleaned.split('.');
      if (parts.length > 1 && parts[1].length > 2) {
        return '$fieldName can have maximum 2 decimal places';
      }
    }

    return null;
  }

  // Quantity validation (positive integers)
  static String? validateQuantity(String? value, {
    String fieldName = 'Quantity',
    int min = 1,
    int? max,
  }) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }

    final cleaned = value.trim();

    if (!_integerRegex.hasMatch(cleaned)) {
      return '$fieldName must be a whole number';
    }

    final parsed = int.tryParse(cleaned);
    if (parsed == null) {
      return '$fieldName must be a valid number';
    }

    if (parsed < min) {
      return '$fieldName must be at least $min';
    }

    if (max != null && parsed > max) {
      return '$fieldName cannot exceed $max';
    }

    return null;
  }

  // Percentage validation (0-100)
  static String? validatePercentage(String? value, {
    String fieldName = 'Percentage',
    bool allowDecimals = true,
  }) {
    if (value == null || value.isEmpty) {
      return null; // Percentage fields are often optional
    }

    final cleaned = value.replaceAll('%', '').trim();

    if (cleaned.isEmpty) {
      return null;
    }

    if (!allowDecimals && !_integerRegex.hasMatch(cleaned)) {
      return '$fieldName must be a whole number';
    }

    final parsed = double.tryParse(cleaned);
    if (parsed == null) {
      return '$fieldName must be a valid number';
    }

    if (parsed < 0) {
      return '$fieldName cannot be negative';
    }

    if (parsed > 100) {
      return '$fieldName cannot exceed 100%';
    }

    return null;
  }

  // General numeric validation
  static String? validateNumeric(String? value, {
    String fieldName = 'Value',
    double? min,
    double? max,
    bool allowNegative = false,
    bool allowDecimals = true,
    int? maxDecimalPlaces,
  }) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }

    final cleaned = value.trim();

    if (!allowDecimals && !_integerRegex.hasMatch(cleaned)) {
      return '$fieldName must be a whole number';
    }

    if (!allowNegative && cleaned.startsWith('-')) {
      return '$fieldName cannot be negative';
    }

    final parsed = double.tryParse(cleaned);
    if (parsed == null) {
      return '$fieldName must be a valid number';
    }

    if (min != null && parsed < min) {
      return '$fieldName must be at least $min';
    }

    if (max != null && parsed > max) {
      return '$fieldName cannot exceed $max';
    }

    if (maxDecimalPlaces != null && cleaned.contains('.')) {
      final parts = cleaned.split('.');
      if (parts.length > 1 && parts[1].length > maxDecimalPlaces) {
        return '$fieldName can have maximum $maxDecimalPlaces decimal places';
      }
    }

    return null;
  }

  // Validate and parse price with error handling
  static double? parsePrice(String? value, {double defaultValue = 0.0}) {
    if (value == null || value.isEmpty) {
      return defaultValue;
    }

    // Remove currency symbols and commas
    final cleaned = value.replaceAll(RegExp(r'[\$,]'), '').trim();

    if (cleaned.isEmpty) {
      return defaultValue;
    }

    final parsed = double.tryParse(cleaned);
    if (parsed == null) {
      return defaultValue;
    }

    // Round to 2 decimal places for prices
    return (parsed * 100).round() / 100;
  }

  // Validate and parse quantity with error handling
  static int? parseQuantity(String? value, {int defaultValue = 1}) {
    if (value == null || value.isEmpty) {
      return defaultValue;
    }

    final cleaned = value.trim();
    final parsed = int.tryParse(cleaned);

    if (parsed == null || parsed < 1) {
      return defaultValue;
    }

    return parsed;
  }

  // Validate and parse percentage with error handling
  static double parsePercentage(String? value, {double defaultValue = 0.0}) {
    if (value == null || value.isEmpty) {
      return defaultValue;
    }

    // Remove percentage symbol
    final cleaned = value.replaceAll('%', '').trim();

    if (cleaned.isEmpty) {
      return defaultValue;
    }

    final parsed = double.tryParse(cleaned);
    if (parsed == null) {
      return defaultValue;
    }

    // Ensure it's within valid percentage range
    if (parsed < 0) return 0.0;
    if (parsed > 100) return 100.0;

    return parsed;
  }

  // Format currency for display in error messages
  static String _formatCurrency(double value) {
    return '\$${value.toStringAsFixed(2)}';
  }

  // Input formatter for price fields
  static TextInputFormatter priceInputFormatter() {
    return TextInputFormatter.withFunction((oldValue, newValue) {
      final text = newValue.text;

      // Allow empty string
      if (text.isEmpty) {
        return newValue;
      }

      // Remove any non-numeric characters except decimal point
      final cleaned = text.replaceAll(RegExp(r'[^0-9.]'), '');

      // Ensure only one decimal point
      final parts = cleaned.split('.');
      if (parts.length > 2) {
        return oldValue;
      }

      // Limit to 2 decimal places
      if (parts.length == 2 && parts[1].length > 2) {
        return oldValue;
      }

      return TextEditingValue(
        text: cleaned,
        selection: TextSelection.collapsed(offset: cleaned.length),
      );
    });
  }

  // Input formatter for quantity fields
  static TextInputFormatter quantityInputFormatter() {
    return TextInputFormatter.withFunction((oldValue, newValue) {
      final text = newValue.text;

      // Allow empty string
      if (text.isEmpty) {
        return newValue;
      }

      // Only allow digits
      if (!_integerRegex.hasMatch(text)) {
        return oldValue;
      }

      // Don't allow leading zeros (except for just "0")
      if (text.length > 1 && text.startsWith('0')) {
        return oldValue;
      }

      return newValue;
    });
  }

  // Input formatter for percentage fields
  static TextInputFormatter percentageInputFormatter() {
    return TextInputFormatter.withFunction((oldValue, newValue) {
      final text = newValue.text;

      // Allow empty string
      if (text.isEmpty) {
        return newValue;
      }

      // Remove any non-numeric characters except decimal point
      final cleaned = text.replaceAll(RegExp(r'[^0-9.]'), '');

      // Ensure only one decimal point
      final parts = cleaned.split('.');
      if (parts.length > 2) {
        return oldValue;
      }

      // Parse to check if it's within 0-100
      final parsed = double.tryParse(cleaned);
      if (parsed != null && parsed > 100) {
        return oldValue;
      }

      return TextEditingValue(
        text: cleaned,
        selection: TextSelection.collapsed(offset: cleaned.length),
      );
    });
  }
}