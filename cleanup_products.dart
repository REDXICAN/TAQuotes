// cleanup_products.dart
// Script to delete unwanted product models from Firebase
// NOTE: This is a utility script, not part of the production app

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: String.fromEnvironment('FIREBASE_API_KEY'),
      appId: String.fromEnvironment('FIREBASE_APP_ID'),
      messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
      projectId: 'taquotes',
      authDomain: 'taquotes.firebaseapp.com',
      databaseURL: 'https://taquotes-default-rtdb.firebaseio.com',
      storageBucket: 'taquotes.appspot.com',
    ),
  );

  await cleanupProducts();
}

Future<void> cleanupProducts() async {
  final database = FirebaseDatabase.instance;

  // Starting product cleanup...
  // Fetching products from database...

  try {
    // Get all products
    final snapshot = await database.ref('products').get();

    if (!snapshot.exists || snapshot.value == null) {
      // No products found in database
      return;
    }

    final products = Map<String, dynamic>.from(snapshot.value as Map);
    // Found products in database

    // Track products to delete
    final productsToDelete = <String>[];
    final modelsToDelete = ['EST', 'EUR', 'EUF', 'MST'];
    final prefixesToDelete = ['E.', 'E-'];

    // Check each product
    for (final entry in products.entries) {
      final productId = entry.key;
      final productData = Map<String, dynamic>.from(entry.value);
      final model = productData['model']?.toString() ?? '';
      final sku = productData['sku']?.toString() ?? '';
      // final displayName = productData['displayName']?.toString() ?? '';

      bool shouldDelete = false;
      // String reason = '';

      // Check if model starts with any unwanted prefix
      for (final prefix in modelsToDelete) {
        if (model.startsWith(prefix)) {
          shouldDelete = true;
          // reason = 'Model starts with $prefix';
          break;
        }
      }

      // Check for E. series (with dot or dash)
      if (!shouldDelete) {
        for (final prefix in prefixesToDelete) {
          if (model.startsWith(prefix)) {
            shouldDelete = true;
            // reason = 'E. series model';
            break;
          }
        }
      }

      // Check SKU as well
      if (!shouldDelete) {
        for (final prefix in modelsToDelete) {
          if (sku.startsWith(prefix)) {
            shouldDelete = true;
            // reason = 'SKU starts with $prefix';
            break;
          }
        }
      }

      if (shouldDelete) {
        productsToDelete.add(productId);
        // Product marked for deletion
      }
    }

    if (productsToDelete.isEmpty) {
      // No products found matching deletion criteria
      return;
    }

    // Found products to delete
    // Proceeding with deletion...

    // Delete products
    for (final productId in productsToDelete) {
      try {
        await database.ref('products/$productId').remove();
        // Deleted product
      } catch (e) {
        // Error deleting product: $e
        debugPrint('Error deleting product $productId: $e');
      }
    }

    // Cleanup completed!
    // Deleted products from database

    // Alphabetize remaining products by updating their timestamps
    // Alphabetizing remaining products...

    // Get updated list of products
    final updatedSnapshot = await database.ref('products').get();
    if (updatedSnapshot.exists && updatedSnapshot.value != null) {
      final remainingProducts = Map<String, dynamic>.from(updatedSnapshot.value as Map);

      // Sort by model name
      final sortedEntries = remainingProducts.entries.toList()
        ..sort((a, b) {
          final modelA = (a.value['model'] ?? '').toString();
          final modelB = (b.value['model'] ?? '').toString();
          return modelA.compareTo(modelB);
        });

      // Update timestamps to reflect alphabetical order
      int index = 0;
      for (final entry in sortedEntries) {
        final productId = entry.key;
        final timestamp = DateTime.now().millisecondsSinceEpoch + index;

        await database.ref('products/$productId').update({
          'sortOrder': index,
          'updatedAt': timestamp,
        });

        index++;
        if (index % 50 == 0) {
          // Alphabetized products...
        }
      }

      // Alphabetization complete!
    }

  } catch (e) {
    debugPrint('Error during cleanup: $e');
  }
}