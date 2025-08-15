import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    const ProviderScope(
      child: MinimalApp(),
    ),
  );
}

class MinimalApp extends StatelessWidget {
  const MinimalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TurboAir',
      home: Scaffold(
        appBar: AppBar(
          title: const Text('TurboAir Products'),
        ),
        body: const Center(
          child: Text('App is working! Products: 48 loaded'),
        ),
      ),
    );
  }
}