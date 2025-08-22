import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:convert';
import 'dart:io';
// Import Firebase options from the main app
import '../lib/firebase_options.dart';

Future<void> removeESeriesProducts() async {
  print('Initializing Firebase...');
  
  // Initialize Firebase using the app's firebase_options.dart
  // This file should be properly secured and gitignored
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  final database = FirebaseDatabase.instance;
  
  print('Fetching all products...');
  final productsSnapshot = await database.ref('products').get();
  
  if (!productsSnapshot.exists) {
    print('No products found in database');
    return;
  }
  
  final productsData = Map<String, dynamic>.from(productsSnapshot.value as Map);
  print('Total products in database: ${productsData.length}');
  
  // Find E-Series products
  final eSeriesProducts = <String, Map<String, dynamic>>{};
  for (var entry in productsData.entries) {
    final product = Map<String, dynamic>.from(entry.value);
    final sku = (product['sku'] ?? '').toString().toUpperCase();
    
    // Check if SKU starts with 'E-' or is in E-Series pattern
    if (sku.startsWith('E-') || sku.startsWith('E ') || 
        (sku.length > 0 && sku[0] == 'E' && sku.length > 1 && RegExp(r'^\d').hasMatch(sku.substring(1)))) {
      eSeriesProducts[entry.key] = product;
    }
  }
  
  if (eSeriesProducts.isEmpty) {
    print('No E-Series products found');
    return;
  }
  
  print('\nFound ${eSeriesProducts.length} E-Series products:');
  for (var entry in eSeriesProducts.entries) {
    final product = entry.value;
    print('  - ${product['sku']} (${product['model'] ?? 'No model'}): ${product['description'] ?? 'No description'}');
  }
  
  // Create backup
  final backupFile = File('e_series_backup_${DateTime.now().millisecondsSinceEpoch}.json');
  await backupFile.writeAsString(jsonEncode(eSeriesProducts));
  print('\nBackup saved to: ${backupFile.path}');
  
  // Ask for confirmation
  print('\nDo you want to remove these ${eSeriesProducts.length} E-Series products? (yes/no)');
  final input = stdin.readLineSync();
  
  if (input?.toLowerCase() != 'yes') {
    print('Operation cancelled');
    return;
  }
  
  print('\nRemoving E-Series products...');
  int removed = 0;
  for (var key in eSeriesProducts.keys) {
    try {
      await database.ref('products/$key').remove();
      removed++;
      print('  Removed: ${eSeriesProducts[key]!['sku']}');
    } catch (e) {
      print('  Error removing ${eSeriesProducts[key]!['sku']}: $e');
    }
  }
  
  print('\nOperation complete!');
  print('Removed $removed out of ${eSeriesProducts.length} E-Series products');
  print('Backup saved to: ${backupFile.path}');
}

void main() async {
  try {
    await removeESeriesProducts();
  } catch (e) {
    print('Error: $e');
  }
  exit(0);
}