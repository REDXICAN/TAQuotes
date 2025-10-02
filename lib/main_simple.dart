import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'app.dart';
import 'core/services/app_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Only initialize Firebase, nothing else
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Log Firebase initialization error
    if (kDebugMode) {
      AppLogger.error('Firebase initialization error', error: e, category: LogCategory.general);
    }
  }

  runApp(
    const ProviderScope(
      child: TurboAirApp(),
    ),
  );
}