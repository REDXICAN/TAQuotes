import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'firebase_options.dart';
import 'app.dart';
import 'core/services/product_cache_service.dart';
import 'core/services/realtime_database_service.dart';
import 'core/services/error_monitoring_service.dart';
import 'core/services/offline_service.dart';
import 'core/services/rbac_service.dart';
import 'core/services/app_logger.dart';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    // .env file is optional, continue without it
  }

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Hive for offline caching
  await Hive.initFlutter();

  // Initialize OfflineService for non-web platforms
  try {
    await OfflineService.staticInitialize();
    AppLogger.info('OfflineService initialized successfully');
  } catch (e) {
    AppLogger.error('OfflineService initialization failed', error: e);
    // App continues without offline functionality
  }

  // Enable Firebase offline persistence
  final dbService = RealtimeDatabaseService();
  await dbService.enableOfflinePersistence();

  // Give Firebase a moment to connect
  await Future.delayed(const Duration(seconds: 1));

  // Initialize product cache service
  await ProductCacheService.instance.initialize();

  // Initialize error monitoring
  await ErrorMonitoringService().initialize();

  // Initialize RBAC and ensure SuperAdmin role is set
  await RBACService.ensureSuperAdminRole();

  // Run app with error boundary
  runZonedGuarded(() {
    runApp(
      const ProviderScope(
        child: TurboAirApp(),
      ),
    );
  }, (error, stack) {
    ErrorMonitoringService().captureError(
      error: error,
      stackTrace: stack,
    );
  });
}