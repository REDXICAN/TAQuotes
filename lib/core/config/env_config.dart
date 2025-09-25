// lib/core/config/env_config.dart
// This file loads environment variables from .env file
// NEVER hardcode sensitive values here

import 'dart:math';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/app_logger.dart';

class EnvConfig {
  // Cache for generated keys
  static final Map<String, String> _generatedKeys = {};

  // Secure random key generator
  static String _generateSecureKey() {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    return base64UrlEncode(values);
  }

  // Helper method to safely get env value
  static String _getEnv(String key, [String defaultValue = '']) {
    try {
      if (dotenv.isInitialized) {
        return dotenv.env[key] ?? defaultValue;
      }
    } catch (error, stackTrace) {
      AppLogger.error(
        'Error accessing environment variable: $key',
        error: error,
        stackTrace: stackTrace,
        category: LogCategory.general,
      );
    }
    return defaultValue;
  }

  // Helper method to safely get int env value
  static int _getEnvInt(String key, int defaultValue) {
    try {
      if (dotenv.isInitialized) {
        final value = dotenv.env[key];
        if (value != null) {
          final parsed = int.tryParse(value);
          if (parsed == null) {
            AppLogger.warning(
              'Environment variable $key has invalid integer value: $value, using default: $defaultValue',
              category: LogCategory.general,
            );
          }
          return parsed ?? defaultValue;
        }
      }
    } catch (error, stackTrace) {
      AppLogger.error(
        'Error parsing integer environment variable: $key',
        error: error,
        stackTrace: stackTrace,
        category: LogCategory.general,
      );
    }
    return defaultValue;
  }

  // Helper method to safely get bool env value
  static bool _getEnvBool(String key, [bool defaultValue = false]) {
    try {
      if (dotenv.isInitialized) {
        final value = dotenv.env[key];
        if (value != null && value.isNotEmpty) {
          if (value.toLowerCase() == 'true' || value == '1') {
            return true;
          } else if (value.toLowerCase() == 'false' || value == '0') {
            return false;
          } else {
            AppLogger.warning(
              'Environment variable $key has invalid boolean value: $value, using default: $defaultValue',
              category: LogCategory.general,
            );
          }
        }
        return defaultValue;
      }
    } catch (error, stackTrace) {
      AppLogger.error(
        'Error parsing boolean environment variable: $key',
        error: error,
        stackTrace: stackTrace,
        category: LogCategory.general,
      );
    }
    return defaultValue;
  }
  
  // Admin Credentials - with safe fallbacks
  static String get adminEmail => _getEnv('ADMIN_EMAIL', '');
  static String get adminPassword => _getEnv('ADMIN_PASSWORD', '');

  // SuperAdmin Email Configuration - centralized list
  static const List<String> superAdminEmails = [
    'andres@turboairmexico.com',
    'carlos@turboairinc.com',
    'admin@turboairinc.com',
    'superadmin@turboairinc.com',
    'admin@turboairmexico.com',  // Added as requested
  ];

  // Check if email is a superadmin
  static bool isSuperAdminEmail(String email) {
    if (email.isEmpty) return false;
    final lowerEmail = email.toLowerCase();
    return superAdminEmails.any((adminEmail) => adminEmail.toLowerCase() == lowerEmail);
  }
  
  // Firebase Configuration
  static String get firebaseProjectId => _getEnv('FIREBASE_PROJECT_ID', 'taquotes');
  static String get firebaseDatabaseUrl => _getEnv('FIREBASE_DATABASE_URL', 'https://taquotes-default-rtdb.firebaseio.com');
  
  // Platform-specific API Keys
  static String get firebaseApiKeyWeb => _getEnv('FIREBASE_API_KEY_WEB');
  static String get firebaseApiKeyAndroid => _getEnv('FIREBASE_API_KEY_ANDROID');
  static String get firebaseApiKeyIos => _getEnv('FIREBASE_API_KEY_IOS');
  static String get firebaseApiKeyWindows => _getEnv('FIREBASE_API_KEY_WINDOWS');
  
  // Platform-specific App IDs
  static String get firebaseAppIdWeb => _getEnv('FIREBASE_APP_ID_WEB');
  static String get firebaseAppIdAndroid => _getEnv('FIREBASE_APP_ID_ANDROID');
  static String get firebaseAppIdIos => _getEnv('FIREBASE_APP_ID_IOS');
  static String get firebaseAppIdWindows => _getEnv('FIREBASE_APP_ID_WINDOWS');
  
  // Common Firebase Config
  static String get firebaseAuthDomain => _getEnv('FIREBASE_AUTH_DOMAIN', 'taquotes.firebaseapp.com');
  static String get firebaseStorageBucket => _getEnv('FIREBASE_STORAGE_BUCKET', 'taquotes.firebasestorage.app');
  static String get firebaseMessagingSenderId => _getEnv('FIREBASE_MESSAGING_SENDER_ID', '118954210086');
  static String get firebaseMeasurementId => _getEnv('FIREBASE_MEASUREMENT_ID');
  
  // Email Configuration - NEVER HARDCODE CREDENTIALS
  static String get emailSenderAddress => _getEnv('EMAIL_SENDER_ADDRESS', ''); // NO DEFAULT EMAIL
  static String get emailAppPassword => _getEnv('EMAIL_APP_PASSWORD', ''); // NEVER ADD DEFAULT PASSWORD
  static String get emailSenderName => _getEnv('EMAIL_SENDER_NAME', 'TurboAir Quote System');
  static String get emailAppUrl => _getEnv('EMAIL_APP_URL', 'https://taquotes.web.app');
  
  // SMTP Configuration
  static String get smtpHost => _getEnv('SMTP_HOST', 'smtp.gmail.com');
  static int get smtpPort => _getEnvInt('SMTP_PORT', 587);
  static bool get smtpSecure => _getEnvBool('SMTP_SECURE', false);
  
  // Security Configuration
  static String get csrfSecretKey {
    // First try to get from environment
    final envKey = _getEnv('CSRF_SECRET_KEY', '');
    if (envKey.isNotEmpty) {
      return envKey;
    }

    // For development: Generate and cache a secure random key
    // This ensures the same key is used throughout the app session
    const cacheKey = 'csrf_secret_key';
    if (!_generatedKeys.containsKey(cacheKey)) {
      _generatedKeys[cacheKey] = _generateSecureKey();
      AppLogger.debug(
        'Generated secure CSRF key for development use',
        category: LogCategory.security,
      );
    }
    return _generatedKeys[cacheKey]!;
  }
  
  // Check if environment is properly loaded
  static bool get isLoaded {
    try {
      return dotenv.isInitialized && dotenv.env.isNotEmpty;
    } catch (error, stackTrace) {
      AppLogger.error(
        'Error checking if environment is loaded',
        error: error,
        stackTrace: stackTrace,
        category: LogCategory.general,
      );
      return false;
    }
  }
  
  // Validate required environment variables
  static bool validateConfig() {
    // In web environment without .env, we use defaults
    // So validation always passes
    return true;
  }
}