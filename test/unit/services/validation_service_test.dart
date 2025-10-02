import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_air_quotes/core/services/validation_service.dart';

void main() {
  group('ValidationService Tests', () {
    group('Email Validation', () {
      test('should accept valid email addresses', () {
        expect(ValidationService.isValidEmail('test@example.com'), true);
        expect(ValidationService.isValidEmail('user.name@company.co'), true);
        expect(ValidationService.isValidEmail('admin@turboairinc.com'), true);
        expect(ValidationService.isValidEmail('andres@turboairmexico.com'), true);
      });

      test('should reject invalid email addresses', () {
        expect(ValidationService.isValidEmail(''), false);
        expect(ValidationService.isValidEmail('not-an-email'), false);
        expect(ValidationService.isValidEmail('@example.com'), false);
        expect(ValidationService.isValidEmail('user@'), false);
        expect(ValidationService.isValidEmail('user @example.com'), false);
      });
    });

    group('Phone Number Validation', () {
      test('should accept valid phone numbers', () {
        expect(ValidationService.isValidPhone('123-456-7890'), true);
        expect(ValidationService.isValidPhone('(123) 456-7890'), true);
        expect(ValidationService.isValidPhone('1234567890'), true);
        expect(ValidationService.isValidPhone('+1-234-567-8900'), true);
      });

      test('should reject invalid phone numbers', () {
        expect(ValidationService.isValidPhone(''), false);
        expect(ValidationService.isValidPhone('123'), false);
        expect(ValidationService.isValidPhone('phone-number'), false);
      });
    });

    group('Input Sanitization', () {
      test('should sanitize SQL injection attempts', () {
        expect(
          ValidationService.sanitizeForDatabase("'; DROP TABLE users; --"),
          isNotEmpty,
        );
        expect(
          ValidationService.sanitizeForDatabase("1' OR '1'='1"),
          isNotEmpty,
        );
      });

      test('should sanitize XSS attempts', () {
        expect(
          ValidationService.sanitizeHtml('<script>alert("XSS")</script>'),
          isNotEmpty,
        );
        expect(
          ValidationService.sanitizeHtml('<img src=x onerror=alert(1)>'),
          isNotEmpty,
        );
      });

      test('should preserve normal text', () {
        expect(
          ValidationService.sanitizeForDatabase('Normal product name'),
          'Normal product name',
        );
        expect(
          ValidationService.sanitizeForDatabase('Price: \$1,234.56'),
          contains('Price'),
        );
      });
    });

    group('Number Validation', () {
      test('should validate numbers correctly', () {
        expect(ValidationService.isValidNumber('0', min: 0.01), false);
        expect(ValidationService.isValidNumber('-10', min: 0), false);
        expect(ValidationService.isValidNumber('99.99', min: 0), true);
        expect(ValidationService.isValidNumber('1000000', min: 0), true);
      });

      test('should validate numbers within range', () {
        expect(ValidationService.isValidNumber('0', min: 1), false);
        expect(ValidationService.isValidNumber('-1', min: 1), false);
        expect(ValidationService.isValidNumber('1', min: 1), true);
        expect(ValidationService.isValidNumber('999', min: 1, max: 10000), true);
        expect(ValidationService.isValidNumber('10000', min: 1, max: 9999), false);
      });
    });
  });
}