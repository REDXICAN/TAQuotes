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
          ValidationService.sanitizeInput("'; DROP TABLE users; --"),
          " DROP TABLE users ",
        );
        expect(
          ValidationService.sanitizeInput("1' OR '1'='1"),
          "1 OR 11",
        );
      });

      test('should sanitize XSS attempts', () {
        expect(
          ValidationService.sanitizeInput('<script>alert("XSS")</script>'),
          'alert("XSS")',
        );
        expect(
          ValidationService.sanitizeInput('<img src=x onerror=alert(1)>'),
          '',
        );
      });

      test('should preserve normal text', () {
        expect(
          ValidationService.sanitizeInput('Normal product name'),
          'Normal product name',
        );
        expect(
          ValidationService.sanitizeInput('Price: \$1,234.56'),
          'Price: \$1,234.56',
        );
      });
    });

    group('Price Validation', () {
      test('should validate price correctly', () {
        expect(ValidationService.isValidPrice(0), false);
        expect(ValidationService.isValidPrice(-10), false);
        expect(ValidationService.isValidPrice(99.99), true);
        expect(ValidationService.isValidPrice(1000000), true);
        expect(ValidationService.isValidPrice(double.infinity), false);
        expect(ValidationService.isValidPrice(double.nan), false);
      });
    });

    group('Quantity Validation', () {
      test('should validate quantity correctly', () {
        expect(ValidationService.isValidQuantity(0), false);
        expect(ValidationService.isValidQuantity(-1), false);
        expect(ValidationService.isValidQuantity(1), true);
        expect(ValidationService.isValidQuantity(999), true);
        expect(ValidationService.isValidQuantity(10000), false); // Max quantity limit
      });
    });
  });
}