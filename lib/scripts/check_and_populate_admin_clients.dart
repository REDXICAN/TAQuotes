// lib/scripts/check_and_populate_admin_clients.dart
// Standalone script to check if admin user has clients and populate demo data if needed

import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/utils/admin_client_checker.dart';
import '../core/services/app_logger.dart';

Future<void> main() async {
  print('🚀 TurboAir Admin Client Checker Starting...\n');

  try {
    // Initialize Firebase (you may need to configure this for your specific setup)
    await Firebase.initializeApp();
    print('✅ Firebase initialized successfully');

    // Check if anyone is logged in
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      print('❌ No user is currently logged in');
      print('💡 Please run this script while the admin user is logged in to the app');
      exit(1);
    }

    print('👤 Current user: ${currentUser.email}');

    // Check admin client status
    print('\n📊 Checking admin client status...');
    final status = await AdminClientChecker.getAdminClientStatus();

    if (!status['success']) {
      print('❌ Error checking status: ${status['message']}');
      exit(1);
    }

    if (!status['isAdmin']) {
      print('⚠️  Current user is not the admin user');
      print('💡 This script is designed for the admin user: ${AdminClientChecker.adminEmail}');
      exit(0);
    }

    final hasClients = status['hasClients'] as bool;
    final clientCount = status['clientCount'] as int;

    print('📈 Admin user status:');
    print('   • Has clients: $hasClients');
    print('   • Client count: $clientCount');

    if (hasClients) {
      print('\n✅ Admin user already has $clientCount clients - no action needed');
      exit(0);
    }

    // Admin has no clients, populate demo data
    print('\n🔄 Admin user has no clients. Populating demo data...');

    final result = await AdminClientChecker.forcePopulateDemoClients();

    if (!result['success']) {
      print('❌ Failed to populate demo clients: ${result['message']}');
      exit(1);
    }

    final newClientCount = result['clientCount'] as int;
    final demoClientCount = result['demoClientCount'] as int;
    final companies = result['companies'] as List<String>;

    print('✅ Demo clients populated successfully!');
    print('📊 Results:');
    print('   • Total clients created: $newClientCount');
    print('   • Demo clients available: $demoClientCount');
    print('\n🏢 Demo companies created:');

    for (int i = 0; i < companies.length; i++) {
      print('   ${i + 1}. ${companies[i]}');
    }

    print('\n🎉 Setup complete! The admin user now has demo client data to work with.');
    print('💡 You can now log into the app and see these clients in the Clients section.');

  } catch (e) {
    print('❌ Error: $e');
    AppLogger.error('Script error', error: e, category: LogCategory.system);
    exit(1);
  }
}