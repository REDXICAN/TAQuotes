import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '../lib/firebase_options.dart';

Future<void> deleteELineProducts() async {
  print('🔍 Initializing Firebase...');
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  final database = FirebaseDatabase.instance;
  
  try {
    print('📊 Fetching all products from database...');
    
    // Get all products
    final snapshot = await database.ref('products').once();
    
    if (!snapshot.snapshot.exists || snapshot.snapshot.value == null) {
      print('❌ No products found in database');
      return;
    }
    
    final productsData = snapshot.snapshot.value as Map<dynamic, dynamic>;
    print('✅ Found ${productsData.length} total products\n');
    
    // Find E line products
    final eLineProducts = <String, Map<dynamic, dynamic>>{};
    
    productsData.forEach((key, value) {
      if (value is Map) {
        final sku = value['sku']?.toString() ?? '';
        final model = value['model']?.toString() ?? '';
        final name = value['name']?.toString() ?? '';
        final productType = value['productType']?.toString() ?? '';
        
        // Check if it's an E line product
        // E line products typically have SKUs ending with -E or contain E- in the model
        if (sku.endsWith('-E') || 
            sku.contains('E-') ||
            model.endsWith('-E') || 
            model.contains('E-') ||
            productType.toLowerCase().contains('e series') ||
            productType.toLowerCase().contains('e-series') ||
            name.toLowerCase().contains('e series') ||
            name.toLowerCase().contains('e-series')) {
          eLineProducts[key.toString()] = value;
        }
      }
    });
    
    if (eLineProducts.isEmpty) {
      print('✅ No E line products found in database');
      return;
    }
    
    print('🔍 Found ${eLineProducts.length} E line products:\n');
    
    // List E line products
    int index = 1;
    for (final entry in eLineProducts.entries) {
      final product = entry.value;
      print('$index. SKU: ${product['sku']} | Model: ${product['model']} | Name: ${product['name']}');
      index++;
    }
    
    print('\n⚠️  WARNING: This will permanently delete ${eLineProducts.length} E line products!');
    print('Type "DELETE" to confirm deletion, or press Enter to cancel:');
    
    final confirmation = await readInput();
    
    if (confirmation.toUpperCase() != 'DELETE') {
      print('❌ Deletion cancelled');
      return;
    }
    
    print('\n🗑️  Deleting E line products...');
    
    // Delete each E line product
    int deleted = 0;
    int failed = 0;
    
    for (final key in eLineProducts.keys) {
      try {
        await database.ref('products/$key').remove();
        deleted++;
        print('  ✅ Deleted product with key: $key');
      } catch (e) {
        failed++;
        print('  ❌ Failed to delete product with key: $key - Error: $e');
      }
    }
    
    print('\n📊 Deletion Summary:');
    print('  ✅ Successfully deleted: $deleted products');
    if (failed > 0) {
      print('  ❌ Failed to delete: $failed products');
    }
    
    // Verify remaining products
    final verifySnapshot = await database.ref('products').once();
    if (verifySnapshot.snapshot.exists && verifySnapshot.snapshot.value != null) {
      final remainingProducts = verifySnapshot.snapshot.value as Map;
      print('\n📊 Database now contains ${remainingProducts.length} products');
      
      // Double-check no E line products remain
      int remainingELine = 0;
      remainingProducts.forEach((key, value) {
        if (value is Map) {
          final sku = value['sku']?.toString() ?? '';
          final model = value['model']?.toString() ?? '';
          if (sku.endsWith('-E') || sku.contains('E-') || 
              model.endsWith('-E') || model.contains('E-')) {
            remainingELine++;
          }
        }
      });
      
      if (remainingELine > 0) {
        print('  ⚠️  Warning: $remainingELine E line products may still remain');
      } else {
        print('  ✅ All E line products successfully removed');
      }
    }
    
  } catch (e) {
    print('❌ Error: $e');
  }
}

Future<String> readInput() async {
  final input = stdin.readLineSync() ?? '';
  return input.trim();
}

void main() async {
  await deleteELineProducts();
  print('\n✅ Script completed');
  exit(0);
}