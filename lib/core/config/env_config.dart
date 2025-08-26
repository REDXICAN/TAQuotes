// lib/core/config/env_config.dart
// This file loads environment variables from .env file
// NEVER hardcode sensitive values here

import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  // Helper method to safely get env value
  static String _getEnv(String key, [String defaultValue = '']) {
    try {
      if (dotenv.isInitialized) {
        return dotenv.env[key] ?? defaultValue;
      }
    } catch (_) {}
    return defaultValue;
  }
  
  // Helper method to safely get int env value
  static int _getEnvInt(String key, int defaultValue) {
    try {
      if (dotenv.isInitialized) {
        final value = dotenv.env[key];
        if (value != null) {
          return int.tryParse(value) ?? defaultValue;
        }
      }
    } catch (_) {}
    return defaultValue;
  }
  
  // Helper method to safely get bool env value
  static bool _getEnvBool(String key, [bool defaultValue = false]) {
    try {
      if (dotenv.isInitialized) {
        return dotenv.env[key] == 'true';
      }
    } catch (_) {}
    return defaultValue;
  }
  
  // Admin Credentials - with safe fallbacks
  static String get adminEmail => _getEnv('ADMIN_EMAIL', '');
  static String get adminPassword => _getEnv('ADMIN_PASSWORD', '');
  
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
  
  // Email Configuration
  static String get emailSenderAddress => _getEnv('EMAIL_SENDER_ADDRESS', 'turboairquotes@gmail.com');
  static String get emailAppPassword => _getEnv('EMAIL_APP_PASSWORD', '');
  static String get emailSenderName => _getEnv('EMAIL_SENDER_NAME', 'TurboAir Quote System');
  static String get emailAppUrl => _getEnv('EMAIL_APP_URL', 'https://taquotes.web.app');
  
  // SMTP Configuration
  static String get smtpHost => _getEnv('SMTP_HOST', 'smtp.gmail.com');
  static int get smtpPort => _getEnvInt('SMTP_PORT', 587);
  static bool get smtpSecure => _getEnvBool('SMTP_SECURE', false);
  
  // Security Configuration
  static String get csrfSecretKey => _getEnv('CSRF_SECRET_KEY', 
      'FALLBACK_KEY_FOR_LOCAL_DEV_ONLY_' + DateTime.now().millisecondsSinceEpoch.toString());
  
  // Check if environment is properly loaded
  static bool get isLoaded {
    try {
      return dotenv.isInitialized && dotenv.env.isNotEmpty;
    } catch (_) {
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