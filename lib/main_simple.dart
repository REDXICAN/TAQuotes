import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Only initialize Firebase, nothing else
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Use debugPrint for development only
    if (kDebugMode) {
      debugPrint('Firebase init error: $e');
    }
  }

  runApp(
    const ProviderScope(
      child: TurboAirApp(),
    ),
  );
}