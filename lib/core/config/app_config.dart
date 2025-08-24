// Location: lib/core/config/app_config.dart
import 'package:flutter/foundation.dart';

class AppConfig {
  // Firebase configuration is handled by firebase_options.dart (auto-generated)
  //   // No need for manual URLs or keys like with Supabase  // REMOVED: Supabase reference

  // Cloud Functions URLs (Firebase equivalent)
  // These will be set up after deploying Firebase Functions
  static const String cloudFunctionsRegion = 'us-central1';
  static const String projectId = 'taquotes';
  
  // Cloud Functions URLs
  static String get emailFunctionUrl =>
      'https://$cloudFunctionsRegion-$projectId.cloudfunctions.net/sendQuoteEmail';
  static String get testEmailFunctionUrl =>
      'https://$cloudFunctionsRegion-$projectId.cloudfunctions.net/testEmail';
  static String get initSuperAdminFunctionUrl =>
      'https://$cloudFunctionsRegion-$projectId.cloudfunctions.net/initializeSuperAdmin';
  
  // Note: syncData function doesn't exist yet, keeping placeholder for future use
  static String get syncFunctionUrl =>
      'https://$cloudFunctionsRegion-$projectId.cloudfunctions.net/syncData';

  // App Settings (keeping your existing settings)
  static const int itemsPerPage = 20;
  static const int maxSearchHistory = 10;
  static const Duration syncInterval = Duration(minutes: 5);
  static const Duration cacheExpiration = Duration(hours: 24);

  // Tax Settings
  static const double defaultTaxRate = 8.0;

  // File Size Limits
  static const int maxFileSize = 200 * 1024 * 1024; // 200MB

  // Firebase-specific settings
  static const bool enableOfflineMode = true;
  static const bool enableAnalytics = true;
  static const bool enableCrashlytics = !kDebugMode;

  // Firestore settings
  static const bool persistenceEnabled = true;
  static const int cacheSizeBytes = 100 * 1024 * 1024; // 100MB cache

  // Development settings
  static const bool showDebugInfo = kDebugMode;
  static const bool enableLogging = kDebugMode;

  // Categories (keeping your existing categories exactly as they are)
  static const Map<String, CategoryInfo> categories = {
    'REACH-IN REFRIGERATION': CategoryInfo(
      icon: '❄️',
      series: ['PRO', 'TSF', 'M3R', 'M3F', 'M3H'],
      types: ['Refrigerators', 'Freezers', 'Dual Temperature'],
    ),
    'FOOD PREP TABLES': CategoryInfo(
      icon: '🥗',
      series: ['PST', 'TST', 'MST', 'TPR'],
      types: ['Sandwich/Salad Prep', 'Pizza Prep'],
    ),
    'UNDERCOUNTER REFRIGERATION': CategoryInfo(
      icon: '📦',
      series: ['MUR', 'PUR', 'EUR'],
      types: ['Refrigerators', 'Freezers'],
    ),
    'WORKTOP REFRIGERATION': CategoryInfo(
      icon: '🔧',
      series: ['TWR', 'PWR'],
      types: ['Refrigerators', 'Freezers'],
    ),
    'GLASS DOOR MERCHANDISERS': CategoryInfo(
      icon: '🥤',
      series: ['TGM', 'TGF'],
      types: ['Refrigerators', 'Freezers'],
    ),
    'DISPLAY CASES': CategoryInfo(
      icon: '🍰',
      series: ['Various'],
      types: ['Open Display', 'Deli Cases', 'Bakery Cases'],
    ),
    'UNDERBAR EQUIPMENT': CategoryInfo(
      icon: '🍺',
      series: ['Various'],
      types: ['Bottle Coolers', 'Beer Dispensers', 'Back Bars'],
    ),
    'MILK COOLERS': CategoryInfo(
      icon: '🥛',
      series: ['TMC', 'TMW'],
      types: ['Milk Coolers'],
    ),
  };
}

class CategoryInfo {
  final String icon;
  final List<String> series;
  final List<String> types;

  const CategoryInfo({
    required this.icon,
    required this.series,
    required this.types,
  });
}
