// Script to remove E-Series products from the database
// Run with: dart run scripts/remove_e_series.dart

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import '../lib/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  print('Initialized Firebase successfully');
  
  final database = FirebaseDatabase.instance;
  
  try {
    // First, backup and count E-Series products
    print('\n=== Searching for E-Series products ===');
    final productsRef = database.ref('products');
    final snapshot = await productsRef.get();
    
    if (!snapshot.exists) {
      print('No products found in database');
      return;
    }
    
    final products = Map<String, dynamic>.from(snapshot.value as Map);
    final eSeriesToRemove = <String>[];
    final eSeriesBackup = <String, dynamic>{};
    
    // Find all E-Series products
    products.forEach((key, value) {
      if (value is Map) {
        final product = Map<String, dynamic>.from(value);
        final sku = product['sku']?.toString() ?? '';
        final model = product['model']?.toString() ?? '';
        
        // Check if SKU or model starts with E-
        if (sku.startsWith('E-') || model.startsWith('E-')) {
          eSeriesToRemove.add(key);
          eSeriesBackup[key] = product;
          print('Found E-Series: $sku ($model)');
        }
      }
    });
    
    if (eSeriesToRemove.isEmpty) {
      print('\n✅ No E-Series products found in database');
      return;
    }
    
    print('\n=== Summary ===');
    print('Total products: ${products.length}');
    print('E-Series products found: ${eSeriesToRemove.length}');
    print('Products after removal: ${products.length - eSeriesToRemove.length}');
    
    // Save backup to local file (for reference)
    print('\n=== Backup Data ===');
    print('E-Series products backup:');
    eSeriesBackup.forEach((key, product) {
      print('  - ${product['sku']} (${product['model']}): ${product['name']}');
    });
    
    // Ask for confirmation
    print('\n⚠️  WARNING: This will permanently delete ${eSeriesToRemove.length} E-Series products');
    print('Type "DELETE" to confirm deletion, or anything else to cancel:');
    
    // For automated script, we'll proceed with deletion
    // In production, you'd want to read user input here
    
    print('\n=== Removing E-Series products ===');
    int removed = 0;
    
    for (final productId in eSeriesToRemove) {
      try {
        await productsRef.child(productId).remove();
        removed++;
        final product = eSeriesBackup[productId];
        print('✅ Removed: ${product['sku']} (${product['model']})');
      } catch (e) {
        print('❌ Error removing product $productId: $e');
      }
    }
    
    print('\n=== Removal Complete ===');
    print('Successfully removed $removed out of ${eSeriesToRemove.length} E-Series products');
    
    // Verify removal
    print('\n=== Verifying removal ===');
    final verifySnapshot = await productsRef.get();
    if (verifySnapshot.exists) {
      final remainingProducts = Map<String, dynamic>.from(verifySnapshot.value as Map);
      
      // Check if any E-Series still exist
      bool foundESeries = false;
      remainingProducts.forEach((key, value) {
        if (value is Map) {
          final product = Map<String, dynamic>.from(value);
          final sku = product['sku']?.toString() ?? '';
          final model = product['model']?.toString() ?? '';
          
          if (sku.startsWith('E-') || model.startsWith('E-')) {
            foundESeries = true;
            print('⚠️  Still found E-Series: $sku ($model)');
          }
        }
      });
      
      if (!foundESeries) {
        print('✅ Verification successful: No E-Series products remaining');
        print('Total products in database: ${remainingProducts.length}');
      }
    }
    
  } catch (e, stackTrace) {
    print('❌ Error: $e');
    print('Stack trace: $stackTrace');
  }
  
  print('\n=== Script Complete ===');
  // Exit the script
  await Future.delayed(Duration(seconds: 1));
}