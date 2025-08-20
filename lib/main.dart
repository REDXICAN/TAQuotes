import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'firebase_options.dart';
import 'app.dart';
import 'core/services/product_cache_service.dart';
import 'core/services/realtime_database_service.dart';

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
  
  // Enable Firebase offline persistence
  final dbService = RealtimeDatabaseService();
  await dbService.enableOfflinePersistence();
  
  // Initialize product cache service
  await ProductCacheService.instance.initialize();

  runApp(
    const ProviderScope(
      child: TurboAirApp(),
    ),
  );
}