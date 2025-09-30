// lib/core/validators/input_validators.dart

import '../utils/safe_type_converter.dart';
import '../services/app_logger.dart';

/// Comprehensive input validation for all forms in the application
class InputValidators {
  // Email validation
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }

    final sanitized = SafeTypeConverter.sanitizeEmail(value);
    if (sanitized == null) {
      return 'Please enter a valid email address';
    }

    // Additional checks
    if (sanitized.length > 255) {
      return 'Email is too long (max 255 characters)';
    }

    // Check for common typos
    final commonDomains = ['gmail.com', 'yahoo.com', 'hotmail.com', 'outlook.com'];
    final parts = sanitized.split('@');
    if (parts.length == 2) {
      final domain = parts[1];
      for (final common in commonDomains) {
        if (domain.length == common.length &&
            domain != common &&
            _levenshteinDistance(domain, common) <= 2) {
          return 'Did you mean @$common?';
        }
      }
    }

    return null;
  }

  // Password validation
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }

    if (value.length < 8) {
      return 'Password must be at least 8 characters long';
    }

    if (value.length > 128) {
      return 'Password is too long (max 128 characters)';
    }

    // Check password strength
    bool hasUppercase = value.contains(RegExp(r'[A-Z]'));
    bool hasLowercase = value.contains(RegExp(r'[a-z]'));
    bool hasDigits = value.contains(RegExp(r'[0-9]'));
    bool hasSpecialCharacters = value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

    if (!hasUppercase || !hasLowercase || !hasDigits || !hasSpecialCharacters) {
      return 'Password must contain uppercase, lowercase, numbers, and special characters';
    }

    // Check for common weak passwords
    final weakPasswords = [
      'password', 'Password123!', '12345678', 'qwerty123',
      'admin123', 'letmein123', 'welcome123'
    ];

    for (final weak in weakPasswords) {
      if (value.toLowerCase().contains(weak.toLowerCase())) {
        return 'Password is too common. Please choose a stronger password';
      }
    }

    return null;
  }

  // Phone validation
  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }

    final sanitized = SafeTypeConverter.sanitizePhone(value);
    if (sanitized == null) {
      return 'Please enter a valid phone number';
    }

    if (sanitized.length < 10) {
      return 'Phone number must be at least 10 digits';
    }

    if (sanitized.length > 20) {
      return 'Phone number is too long (max 20 digits)';
    }

    return null;
  }

  // Name validation
  static String? validateName(String? value, {String fieldName = 'Name'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }

    final trimmed = value.trim();

    if (trimmed.length < 2) {
      return '$fieldName must be at least 2 characters';
    }

    if (trimmed.length > 100) {
      return '$fieldName is too long (max 100 characters)';
    }

    // Check for invalid characters
    if (trimmed.contains(RegExp(r'[0-9!@#$%^&*(),.?":{}|<>]'))) {
      return '$fieldName contains invalid characters';
    }

    // Check for SQL injection attempts
    final sanitized = SafeTypeConverter.sanitizeForDatabase(trimmed);
    if (sanitized != trimmed) {
      return '$fieldName contains invalid characters';
    }

    return null;
  }

  // Company name validation
  static String? validateCompanyName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Company name is required';
    }

    final trimmed = value.trim();

    if (trimmed.length < 2) {
      return 'Company name must be at least 2 characters';
    }

    if (trimmed.length > 200) {
      return 'Company name is too long (max 200 characters)';
    }

    // Check for SQL injection attempts
    final sanitized = SafeTypeConverter.sanitizeForDatabase(trimmed);
    if (sanitized.length < trimmed.length * 0.9) {
      return 'Company name contains too many special characters';
    }

    return null;
  }

  // Address validation
  static String? validateAddress(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Address is often optional
    }

    final trimmed = value.trim();

    if (trimmed.length > 500) {
      return 'Address is too long (max 500 characters)';
    }

    // Check for potential injection
    final sanitized = SafeTypeConverter.sanitizeForDatabase(trimmed);
    if (sanitized.length < trimmed.length * 0.8) {
      return 'Address contains invalid characters';
    }

    return null;
  }

  // SKU validation
  static String? validateSKU(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'SKU is required';
    }

    final trimmed = value.trim().toUpperCase();

    if (trimmed.length < 3) {
      return 'SKU must be at least 3 characters';
    }

    if (trimmed.length > 50) {
      return 'SKU is too long (max 50 characters)';
    }

    // SKU pattern: alphanumeric with dashes and underscores
    if (!RegExp(r'^[A-Z0-9_-]+$').hasMatch(trimmed)) {
      return 'SKU can only contain letters, numbers, dashes, and underscores';
    }

    return null;
  }

  // Price validation
  static String? validatePrice(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Price is required';
    }

    final price = SafeTypeConverter.toDoubleOrNull(value);
    if (price == null) {
      return 'Please enter a valid price';
    }

    if (price < 0) {
      return 'Price cannot be negative';
    }

    if (price > 999999999.99) {
      return 'Price is too high (max 999,999,999.99)';
    }

    return null;
  }

  // Quantity validation
  static String? validateQuantity(String? value, {int min = 1, int max = 999999}) {
    if (value == null || value.trim().isEmpty) {
      return 'Quantity is required';
    }

    final quantity = SafeTypeConverter.toIntOrNull(value);
    if (quantity == null) {
      return 'Please enter a valid quantity';
    }

    if (quantity < min) {
      return 'Quantity must be at least $min';
    }

    if (quantity > max) {
      return 'Quantity cannot exceed $max';
    }

    return null;
  }

  // Percentage validation
  static String? validatePercentage(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Often optional
    }

    final percentage = SafeTypeConverter.toDoubleOrNull(value);
    if (percentage == null) {
      return 'Please enter a valid percentage';
    }

    if (percentage < 0) {
      return 'Percentage cannot be negative';
    }

    if (percentage > 100) {
      return 'Percentage cannot exceed 100';
    }

    return null;
  }

  // URL validation
  static String? validateUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Often optional
    }

    final sanitized = SafeTypeConverter.sanitizeUrl(value);
    if (sanitized == null) {
      return 'Please enter a valid URL';
    }

    if (sanitized.length > 2048) {
      return 'URL is too long (max 2048 characters)';
    }

    return null;
  }

  // Date validation
  static String? validateDate(String? value, {DateTime? minDate, DateTime? maxDate}) {
    if (value == null || value.trim().isEmpty) {
      return 'Date is required';
    }

    final date = SafeTypeConverter.toDateTimeOrNull(value);
    if (date == null) {
      return 'Please enter a valid date';
    }

    if (minDate != null && date.isBefore(minDate)) {
      return 'Date must be after ${minDate.toLocal()}';
    }

    if (maxDate != null && date.isAfter(maxDate)) {
      return 'Date must be before ${maxDate.toLocal()}';
    }

    return null;
  }

  // Description/Comments validation
  static String? validateDescription(String? value, {int maxLength = 5000}) {
    if (value == null || value.trim().isEmpty) {
      return null; // Usually optional
    }

    final trimmed = value.trim();

    if (trimmed.length > maxLength) {
      return 'Text is too long (max $maxLength characters)';
    }

    // Check for potential injection
    final sanitized = SafeTypeConverter.sanitizeForDatabase(trimmed);
    if (sanitized.isEmpty && trimmed.isNotEmpty) {
      return 'Text contains invalid characters';
    }

    return null;
  }

  // Excel file validation
  static String? validateExcelFile(String? filename, int? fileSize) {
    if (filename == null || filename.isEmpty) {
      return 'Please select a file';
    }

    // Check extension
    if (!filename.toLowerCase().endsWith('.xlsx') &&
        !filename.toLowerCase().endsWith('.xls')) {
      return 'Please select an Excel file (.xlsx or .xls)';
    }

    // Check file size (max 10MB)
    if (fileSize != null && fileSize > 10 * 1024 * 1024) {
      return 'File is too large (max 10MB)';
    }

    return null;
  }

  // Quote number validation
  static String? validateQuoteNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Quote number is required';
    }

    final trimmed = value.trim();

    // Quote number pattern: QYYYY-NNNN
    if (!RegExp(r'^Q\d{4}-\d{4}$').hasMatch(trimmed)) {
      return 'Invalid quote number format (expected: Q2025-0001)';
    }

    return null;
  }

  // Batch validation for multiple fields
  static Map<String, String?> validateClientForm({
    required String? company,
    required String? contactName,
    required String? email,
    required String? phone,
    String? address,
  }) {
    return {
      'company': validateCompanyName(company),
      'contactName': validateName(contactName, fieldName: 'Contact name'),
      'email': validateEmail(email),
      'phone': validatePhone(phone),
      'address': validateAddress(address),
    };
  }

  // Batch validation for product form
  static Map<String, String?> validateProductForm({
    required String? sku,
    required String? name,
    required String? price,
    String? description,
    String? quantity,
  }) {
    return {
      'sku': validateSKU(sku),
      'name': validateName(name, fieldName: 'Product name'),
      'price': validatePrice(price),
      'description': validateDescription(description, maxLength: 1000),
      'quantity': quantity != null ? validateQuantity(quantity) : null,
    };
  }

  // Batch validation for quote form
  static Map<String, String?> validateQuoteForm({
    required String? clientId,
    required List<dynamic>? items,
    String? discount,
    String? notes,
  }) {
    final errors = <String, String?>{};

    if (clientId == null || clientId.isEmpty) {
      errors['client'] = 'Please select a client';
    }

    if (items == null || items.isEmpty) {
      errors['items'] = 'Please add at least one item';
    }

    if (discount != null && discount.isNotEmpty) {
      errors['discount'] = validatePercentage(discount);
    }

    if (notes != null) {
      errors['notes'] = validateDescription(notes, maxLength: 2000);
    }

    return errors;
  }

  // Helper: Calculate Levenshtein distance for typo detection
  static int _levenshteinDistance(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    List<int> previousRow = List<int>.generate(s2.length + 1, (i) => i);
    List<int> currentRow = List<int>.filled(s2.length + 1, 0);

    for (int i = 0; i < s1.length; i++) {
      currentRow[0] = i + 1;

      for (int j = 0; j < s2.length; j++) {
        int cost = s1[i] == s2[j] ? 0 : 1;
        currentRow[j + 1] = [
          previousRow[j + 1] + 1,     // deletion
          currentRow[j] + 1,           // insertion
          previousRow[j] + cost,       // substitution
        ].reduce((a, b) => a < b ? a : b);
      }

      List<int> temp = previousRow;
      previousRow = currentRow;
      currentRow = temp;
    }

    return previousRow[s2.length];
  }
}