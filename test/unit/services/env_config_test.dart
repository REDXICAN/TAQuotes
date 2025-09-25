import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_air_quotes/core/config/env_config.dart';

void main() {
  group('EnvConfig Tests', () {
    test('should not expose hardcoded passwords', () {
      // Ensure no hardcoded passwords are present
      expect(EnvConfig.adminPassword, isNot(contains('123')));
      expect(EnvConfig.adminPassword, isNot(contains('password')));
      expect(EnvConfig.emailAppPassword, isNot(contains('password')));
    });

    test('should have valid Firebase configuration', () {
      expect(EnvConfig.firebaseProjectId, isNotEmpty);
      expect(EnvConfig.firebaseDatabaseUrl, contains('firebaseio.com'));
    });

    test('should have email configuration', () {
      expect(EnvConfig.emailSenderAddress, isNotEmpty);
      expect(EnvConfig.emailSenderName, isNotEmpty);
    });

    test('CSRF key should be generated securely', () {
      final csrfKey = EnvConfig.csrfSecretKey;
      expect(csrfKey, isNotEmpty);
      expect(csrfKey.length, greaterThanOrEqualTo(32));
      // Should not be a simple timestamp or predictable value
      expect(csrfKey, isNot(matches(RegExp(r'^\d+$'))));
    });
  });
}